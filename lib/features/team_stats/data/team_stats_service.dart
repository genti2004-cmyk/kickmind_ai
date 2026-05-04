import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/pro_prediction_input.dart';
import 'package:kickmind_ai/features/team_stats/domain/head_to_head_stats.dart';
import 'package:kickmind_ai/features/team_stats/domain/league_standing.dart';
import 'package:kickmind_ai/features/team_stats/domain/team_stats.dart';

/// Sichere Statistik-Schicht für Phase 4.
///
/// Ziel:
/// - versucht echte Team-Form über TheSportsDB zu holen
/// - fällt automatisch auf stabile Schätzung zurück, wenn die API nichts liefert
/// - verändert keine UI-Screens direkt
/// - gibt ProPredictionInput zurück, den die bestehende PredictionEngine versteht
class TeamStatsService {
  TeamStatsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _baseUrl = 'https://www.thesportsdb.com/api/v1/json/123';
  static final Map<String, String?> _teamIdCache = <String, String?>{};
  static final Map<String, List<Map<String, dynamic>>> _lastEventsCache = <String, List<Map<String, dynamic>>>{};

  Future<ProPredictionInput> buildInput(FootballMatch match) async {
    final homeStats = await buildTeamStats(
      teamName: match.homeTeam,
      isHomeContext: true,
    );

    final awayStats = await buildTeamStats(
      teamName: match.awayTeam,
      isHomeContext: false,
    );

    final h2h = await buildHeadToHead(
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
    );

    final homeStanding = buildEstimatedStanding(
      teamName: match.homeTeam,
      stats: homeStats,
    );

    final awayStanding = buildEstimatedStanding(
      teamName: match.awayTeam,
      stats: awayStats,
    );

    return ProPredictionInput(
      match: match,
      homeStats: homeStats,
      awayStats: awayStats,
      headToHead: h2h,
      homeStanding: homeStanding,
      awayStanding: awayStanding,
    );
  }

  Future<TeamStats> buildTeamStats({
    required String teamName,
    required bool isHomeContext,
  }) async {
    final lastEvents = await _lastEventsForTeam(teamName);

    if (lastEvents.isEmpty) {
      return _fallbackTeamStats(
        teamName: teamName,
        isHomeContext: isHomeContext,
      );
    }

    var played = 0;
    var wins = 0;
    var draws = 0;
    var losses = 0;
    var goalsFor = 0;
    var goalsAgainst = 0;
    final lastResults = <String>[];

    for (final event in lastEvents.take(10)) {
      final home = event['strHomeTeam']?.toString() ?? '';
      final away = event['strAwayTeam']?.toString() ?? '';
      final homeScore = int.tryParse(event['intHomeScore']?.toString() ?? '');
      final awayScore = int.tryParse(event['intAwayScore']?.toString() ?? '');

      if (homeScore == null || awayScore == null) continue;

      final isHome = _sameTeam(home, teamName);
      final isAway = _sameTeam(away, teamName);
      if (!isHome && !isAway) continue;

      final gf = isHome ? homeScore : awayScore;
      final ga = isHome ? awayScore : homeScore;

      played++;
      goalsFor += gf;
      goalsAgainst += ga;

      if (gf > ga) {
        wins++;
        lastResults.add('W');
      } else if (gf == ga) {
        draws++;
        lastResults.add('D');
      } else {
        losses++;
        lastResults.add('L');
      }
    }

    if (played == 0) {
      return _fallbackTeamStats(
        teamName: teamName,
        isHomeContext: isHomeContext,
      );
    }

    final points = wins * 3 + draws;
    final formScore = ((points / (played * 3)) * 100).round().clamp(1, 99);
    final goalBalanceScore = (50 + ((goalsFor - goalsAgainst) * 5)).clamp(1, 99);
    final overall = ((formScore * 0.70) + (goalBalanceScore * 0.30)).round().clamp(1, 99);

    final homeForm = (overall + (isHomeContext ? 6 : 1)).clamp(1, 99);
    final awayForm = (overall - (isHomeContext ? 1 : 4)).clamp(1, 99);

    return TeamStats(
      teamName: teamName,
      played: played,
      wins: wins,
      draws: draws,
      losses: losses,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      homeFormScore: homeForm,
      awayFormScore: awayForm,
      overallFormScore: overall,
      lastResults: lastResults.take(5).toList(),
    );
  }

  Future<HeadToHeadStats> buildHeadToHead({
    required String homeTeam,
    required String awayTeam,
  }) async {
    // TheSportsDB H2H ist je nach Liga nicht immer verfügbar.
    // Deshalb sicher: API versuchen, sonst stabiler Fallback.
    try {
      final uri = Uri.parse(
        '$_baseUrl/eventsh2h.php?first=${Uri.encodeComponent(homeTeam)}&second=${Uri.encodeComponent(awayTeam)}',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return _fallbackHeadToHead(homeTeam: homeTeam, awayTeam: awayTeam);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _fallbackHeadToHead(homeTeam: homeTeam, awayTeam: awayTeam);
      }

      final rawEvents = decoded['event'] ?? decoded['events'] ?? decoded['results'];
      if (rawEvents is! List || rawEvents.isEmpty) {
        return _fallbackHeadToHead(homeTeam: homeTeam, awayTeam: awayTeam);
      }

      var matches = 0;
      var homeWins = 0;
      var awayWins = 0;
      var draws = 0;
      var goalsForHome = 0;
      var goalsForAway = 0;

      for (final raw in rawEvents.take(10)) {
        if (raw is! Map<String, dynamic>) continue;
        final hs = int.tryParse(raw['intHomeScore']?.toString() ?? '');
        final as = int.tryParse(raw['intAwayScore']?.toString() ?? '');
        if (hs == null || as == null) continue;

        final apiHome = raw['strHomeTeam']?.toString() ?? '';
        final homeTeamIsApiHome = _sameTeam(apiHome, homeTeam);

        final homeGoals = homeTeamIsApiHome ? hs : as;
        final awayGoals = homeTeamIsApiHome ? as : hs;

        matches++;
        goalsForHome += homeGoals;
        goalsForAway += awayGoals;

        if (homeGoals > awayGoals) {
          homeWins++;
        } else if (homeGoals < awayGoals) {
          awayWins++;
        } else {
          draws++;
        }
      }

      if (matches == 0) {
        return _fallbackHeadToHead(homeTeam: homeTeam, awayTeam: awayTeam);
      }

      return HeadToHeadStats(
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        matches: matches,
        homeWins: homeWins,
        draws: draws,
        awayWins: awayWins,
        goalsForHome: goalsForHome,
        goalsForAway: goalsForAway,
      );
    } catch (_) {
      return _fallbackHeadToHead(homeTeam: homeTeam, awayTeam: awayTeam);
    }
  }

  LeagueStanding buildEstimatedStanding({
    required String teamName,
    required TeamStats stats,
  }) {
    // Ohne verlässliche League-ID pro Match bleibt Tabelle bewusst konservativ.
    // Der Wert wird aber stabil aus echten Form-/Tordaten abgeleitet.
    final power = ((stats.overallFormScore * 0.65) +
        ((50 + stats.goalDifference * 4).clamp(1, 99) * 0.35))
        .round()
        .clamp(1, 99);

    final position = (20 - (power / 5).round()).clamp(1, 20);
    final points = (stats.wins * 3) + stats.draws;

    return LeagueStanding(
      teamName: teamName,
      position: position,
      points: points,
      played: stats.played,
      goalDifference: stats.goalDifference,
    );
  }

  Future<List<Map<String, dynamic>>> _lastEventsForTeam(String teamName) async {
    final cacheKey = teamName.toLowerCase().trim();
    final cached = _lastEventsCache[cacheKey];
    if (cached != null) return cached;

    final teamId = await _resolveTeamId(teamName);
    if (teamId == null || teamId.isEmpty) {
      _lastEventsCache[cacheKey] = <Map<String, dynamic>>[];
      return _lastEventsCache[cacheKey]!;
    }

    try {
      final uri = Uri.parse('$_baseUrl/eventslast.php?id=$teamId');
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _lastEventsCache[cacheKey] = <Map<String, dynamic>>[];
        return _lastEventsCache[cacheKey]!;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _lastEventsCache[cacheKey] = <Map<String, dynamic>>[];
        return _lastEventsCache[cacheKey]!;
      }

      final rawEvents = decoded['results'];
      if (rawEvents is! List) {
        _lastEventsCache[cacheKey] = <Map<String, dynamic>>[];
        return _lastEventsCache[cacheKey]!;
      }

      final events = rawEvents.whereType<Map<String, dynamic>>().toList();
      _lastEventsCache[cacheKey] = events;
      return events;
    } catch (_) {
      _lastEventsCache[cacheKey] = <Map<String, dynamic>>[];
      return _lastEventsCache[cacheKey]!;
    }
  }

  Future<String?> _resolveTeamId(String teamName) async {
    final cacheKey = teamName.toLowerCase().trim();
    if (_teamIdCache.containsKey(cacheKey)) return _teamIdCache[cacheKey];

    try {
      final uri = Uri.parse('$_baseUrl/searchteams.php?t=${Uri.encodeComponent(teamName)}');
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _teamIdCache[cacheKey] = null;
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _teamIdCache[cacheKey] = null;
        return null;
      }

      final teams = decoded['teams'];
      if (teams is! List || teams.isEmpty) {
        _teamIdCache[cacheKey] = null;
        return null;
      }

      final first = teams.first;
      if (first is! Map<String, dynamic>) {
        _teamIdCache[cacheKey] = null;
        return null;
      }

      final id = first['idTeam']?.toString();
      _teamIdCache[cacheKey] = id;
      return id;
    } catch (_) {
      _teamIdCache[cacheKey] = null;
      return null;
    }
  }

  TeamStats _fallbackTeamStats({
    required String teamName,
    required bool isHomeContext,
  }) {
    final base = _stableScore(teamName, min: 44, max: 86);
    final played = 10;
    final wins = (base / 18).round().clamp(1, 8);
    final draws = ((100 - base) / 25).round().clamp(0, 5);
    final losses = (played - wins - draws).clamp(0, played);
    final goalsFor = (base / 6).round().clamp(7, 24);
    final goalsAgainst = ((100 - base) / 7).round().clamp(4, 20);

    final homeForm = (base + (isHomeContext ? 6 : 1)).clamp(1, 99);
    final awayForm = (base - (isHomeContext ? 1 : 4)).clamp(1, 99);

    return TeamStats(
      teamName: teamName,
      played: played,
      wins: wins,
      draws: draws,
      losses: losses,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      homeFormScore: homeForm,
      awayFormScore: awayForm,
      overallFormScore: base,
      lastResults: _lastResultsFromScore(base),
    );
  }

  HeadToHeadStats _fallbackHeadToHead({
    required String homeTeam,
    required String awayTeam,
  }) {
    final seed = _stableScore('$homeTeam-$awayTeam-h2h', min: 35, max: 85);
    const matches = 5;
    final homeWins = (seed / 28).round().clamp(0, 4);
    final draws = ((100 - seed) / 35).round().clamp(0, 3);
    final awayWins = (matches - homeWins - draws).clamp(0, matches);

    return HeadToHeadStats(
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      matches: matches,
      homeWins: homeWins,
      draws: draws,
      awayWins: awayWins,
      goalsForHome: (seed / 12).round().clamp(2, 12),
      goalsForAway: ((100 - seed) / 13).round().clamp(1, 10),
    );
  }

  List<String> _lastResultsFromScore(int score) {
    if (score >= 78) return const <String>['W', 'W', 'D', 'W', 'W'];
    if (score >= 65) return const <String>['W', 'D', 'W', 'L', 'W'];
    if (score >= 52) return const <String>['D', 'W', 'L', 'D', 'W'];
    return const <String>['L', 'D', 'L', 'W', 'L'];
  }

  bool _sameTeam(String a, String b) {
    final aa = a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final bb = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return aa == bb || aa.contains(bb) || bb.contains(aa);
  }

  int _stableScore(String seed, {required int min, required int max}) {
    final hash = seed.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return min + (hash % (max - min + 1));
  }
}
