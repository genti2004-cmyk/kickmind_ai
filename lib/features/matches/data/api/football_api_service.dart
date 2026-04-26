import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../predictions/domain/prediction_engine.dart';
import '../../domain/football_match.dart';

class FootballApiService {
  const FootballApiService();

  Future<List<FootballMatch>> fetchTodayFixtures() async {
    if (!ApiConfig.hasFootballApiKey) {
      throw Exception('API-Key fehlt. Bitte in api_config.dart eintragen.');
    }

    final now = DateTime.now();
    final season = now.year;

    final allFixtures = <FootballMatch>[];

    for (int i = 0; i < 3; i++) {
      final dateTime = now.add(Duration(days: i));
      final date = _formatDate(dateTime);

      final uri = Uri.parse(
        '${ApiConfig.footballBaseUrl}/fixtures?date=$date&timezone=Europe/Berlin',
      );

      final response = await http.get(uri, headers: _headers);

      print('API STATUS: ${response.statusCode}');
      print('API BODY: ${response.body}');

      if (response.statusCode != 200) {
        continue;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (json['response'] as List<dynamic>? ?? []);

      for (final raw in items.take(15)) {
        final match = await _mapFixtureWithAnalysis(
          raw as Map<String, dynamic>,
          season: season,
        );
        allFixtures.add(match);
      }

      if (allFixtures.length >= 20) break;
    }

    if (allFixtures.isEmpty) {
      print('⚠️ API leer → fallback aktiv');
      return _fallbackMatches();
    }

    return allFixtures
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
  }

  Map<String, String> get _headers => {
    'x-apisports-key': ApiConfig.footballApiKey,
  };

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<FootballMatch> _mapFixtureWithAnalysis(
      Map<String, dynamic> map, {
        required int season,
      }) async {
    final league = map['league'] as Map<String, dynamic>? ?? {};
    final teams = map['teams'] as Map<String, dynamic>? ?? {};
    final fixture = map['fixture'] as Map<String, dynamic>? ?? {};

    final home = teams['home'] as Map<String, dynamic>? ?? {};
    final away = teams['away'] as Map<String, dynamic>? ?? {};

    final fixtureId = _asInt(fixture['id']);
    final leagueId = _asInt(league['id']);
    final homeTeamId = _asInt(home['id']);
    final awayTeamId = _asInt(away['id']);

    final kickoffRaw = fixture['date']?.toString();
    final kickoff =
        DateTime.tryParse(kickoffRaw ?? '')?.toLocal() ?? DateTime.now();

    final homeName = home['name']?.toString() ?? 'Heimteam';
    final awayName = away['name']?.toString() ?? 'Auswärtsteam';

    TeamAnalysis? homeAnalysis;
    TeamAnalysis? awayAnalysis;

    if (leagueId != null && homeTeamId != null) {
      homeAnalysis = await fetchTeamAnalysis(
        leagueId: leagueId,
        teamId: homeTeamId,
        season: season,
      );
    }

    if (leagueId != null && awayTeamId != null) {
      awayAnalysis = await fetchTeamAnalysis(
        leagueId: leagueId,
        teamId: awayTeamId,
        season: season,
      );
    }

    final homeFormScore = homeAnalysis?.formScore ?? _fallbackScore(homeName, 70);
    final awayFormScore = awayAnalysis?.formScore ?? _fallbackScore(awayName, 65);

    final goalsScore = _calculateGoalsScore(
      homeAnalysis: homeAnalysis,
      awayAnalysis: awayAnalysis,
      homeName: homeName,
      awayName: awayName,
    );

    final tip = _selectTip(
      homeFormScore: homeFormScore,
      awayFormScore: awayFormScore,
      goalsScore: goalsScore,
    );

    final odds = fixtureId == null
        ? 1.75
        : await fetchBestOddForFixture(
      fixtureId: fixtureId,
      tipType: tip.type,
    );

    const engine = PredictionEngine();

    final aiScore = engine.calculateAiScore(
      homeFormScore: homeFormScore,
      awayFormScore: awayFormScore,
      goalsScore: goalsScore,
      odds: odds,
      tipType: tip.type,
    );

    final riskLevel = engine.calculateRisk(
      aiScore: aiScore,
      odds: odds,
    );

    final reason = engine.buildReason(
      tipType: tip.type,
      homeFormScore: homeFormScore,
      awayFormScore: awayFormScore,
      goalsScore: goalsScore,
      aiScore: aiScore,
    );

    return FootballMatch(
      id: fixtureId?.toString() ?? '${homeName}_$awayName',
      fixtureId: fixtureId,
      leagueId: leagueId,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
      season: season,
      league: league['name']?.toString() ?? 'Liga',
      homeTeam: homeName,
      awayTeam: awayName,
      kickoff: kickoff,
      tipType: tip.type,
      tipLabel: tip.label,
      aiScore: aiScore,
      riskLevel: riskLevel,
      odds: odds,
      homeFormScore: homeFormScore,
      awayFormScore: awayFormScore,
      goalsScore: goalsScore,
      shortReason: reason,
    );
  }

  Future<TeamAnalysis?> fetchTeamAnalysis({
    required int leagueId,
    required int teamId,
    required int season,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.footballBaseUrl}/teams/statistics'
          '?league=$leagueId&team=$teamId&season=$season',
    );

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['response'];

    if (data is! Map<String, dynamic>) {
      return null;
    }

    return TeamAnalysis.fromJson(data);
  }

  Future<double> fetchBestOddForFixture({
    required int fixtureId,
    required TipType tipType,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.footballBaseUrl}/odds?fixture=$fixtureId',
    );

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      return 1.75;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final responseItems = json['response'];

    if (responseItems is! List || responseItems.isEmpty) {
      return 1.75;
    }

    final odds = <double>[];

    for (final fixtureOdds in responseItems) {
      if (fixtureOdds is! Map<String, dynamic>) continue;

      final bookmakers = fixtureOdds['bookmakers'];
      if (bookmakers is! List) continue;

      for (final bookmaker in bookmakers) {
        if (bookmaker is! Map<String, dynamic>) continue;

        final bets = bookmaker['bets'];
        if (bets is! List) continue;

        for (final bet in bets) {
          if (bet is! Map<String, dynamic>) continue;

          final betName = bet['name']?.toString().toLowerCase() ?? '';
          final values = bet['values'];

          if (values is! List) continue;

          for (final value in values) {
            if (value is! Map<String, dynamic>) continue;

            final label = value['value']?.toString().toLowerCase() ?? '';
            final odd = double.tryParse(value['odd']?.toString() ?? '');

            if (odd == null || odd <= 1.01) continue;

            if (_matchesOddMarket(
              tipType: tipType,
              betName: betName,
              label: label,
            )) {
              odds.add(odd);
            }
          }
        }
      }
    }

    final safeOdds = odds.where((odd) => odd >= 1.20 && odd <= 3.50).toList();

    if (safeOdds.isEmpty) {
      return 1.75;
    }

    safeOdds.sort();

    return safeOdds[safeOdds.length ~/ 2];
  }

  bool _matchesOddMarket({
    required TipType tipType,
    required String betName,
    required String label,
  }) {
    switch (tipType) {
      case TipType.homeWin:
        return betName.contains('match winner') &&
            (label == 'home' || label == '1');

      case TipType.draw:
        return betName.contains('match winner') &&
            (label == 'draw' || label == 'x');

      case TipType.awayWin:
        return betName.contains('match winner') &&
            (label == 'away' || label == '2');

      case TipType.doubleChance:
        return betName.contains('double chance') &&
            (label.contains('home/draw') ||
                label.contains('1x') ||
                label.contains('home or draw'));

      case TipType.over25:
        return (betName.contains('over/under') ||
            betName.contains('goals over/under')) &&
            label.contains('over 2.5');

      case TipType.under25:
        return (betName.contains('over/under') ||
            betName.contains('goals over/under')) &&
            label.contains('under 2.5');

      case TipType.bothTeamsScore:
        return (betName.contains('both teams score') ||
            betName.contains('both teams to score')) &&
            (label == 'yes' || label == 'ja');
    }
  }

  int _calculateGoalsScore({
    required TeamAnalysis? homeAnalysis,
    required TeamAnalysis? awayAnalysis,
    required String homeName,
    required String awayName,
  }) {
    if (homeAnalysis == null || awayAnalysis == null) {
      return 68 + ((homeName.length + awayName.length) % 22);
    }

    final avgGoals =
        (homeAnalysis.goalsForAverage + awayAnalysis.goalsForAverage) / 2;

    if (avgGoals >= 2.2) return 88;
    if (avgGoals >= 1.8) return 80;
    if (avgGoals >= 1.4) return 72;
    if (avgGoals >= 1.0) return 64;

    return 55;
  }

  _TipPick _selectTip({
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
  }) {
    final edge = homeFormScore - awayFormScore;

    if (goalsScore >= 82) {
      return const _TipPick(TipType.over25, 'Über 2.5 Tore');
    }

    if (edge >= 14) {
      return const _TipPick(TipType.homeWin, 'Heimsieg');
    }

    if (edge <= -14) {
      return const _TipPick(TipType.awayWin, 'Auswärtssieg');
    }

    if (edge >= 6) {
      return const _TipPick(TipType.doubleChance, '1X');
    }

    return const _TipPick(TipType.bothTeamsScore, 'Beide treffen');
  }

  int _fallbackScore(String seed, int base) {
    return (base + seed.length % 18).clamp(1, 99);
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  List<FootballMatch> _fallbackMatches() {
    final now = DateTime.now();

    return [
      FootballMatch(
        id: 'fallback1',
        season: now.year,
        league: 'Demo League',
        homeTeam: 'Team Alpha',
        awayTeam: 'Team Beta',
        kickoff: now,
        tipType: TipType.homeWin,
        tipLabel: 'Heimsieg',
        aiScore: 82,
        riskLevel: RiskLevel.low,
        odds: 1.75,
        homeFormScore: 80,
        awayFormScore: 60,
        goalsScore: 75,
        shortReason: 'Fallback Daten – API hat keine Spiele geliefert.',
      ),
      FootballMatch(
        id: 'fallback2',
        season: now.year,
        league: 'Demo League',
        homeTeam: 'Team Gamma',
        awayTeam: 'Team Delta',
        kickoff: now.add(const Duration(hours: 2)),
        tipType: TipType.over25,
        tipLabel: 'Über 2.5 Tore',
        aiScore: 79,
        riskLevel: RiskLevel.medium,
        odds: 1.88,
        homeFormScore: 74,
        awayFormScore: 70,
        goalsScore: 86,
        shortReason: 'Fallback Daten – Tortrend als Beispielanalyse.',
      ),
    ];
  }
}

class TeamAnalysis {
  final int formScore;
  final double goalsForAverage;
  final double goalsAgainstAverage;

  const TeamAnalysis({
    required this.formScore,
    required this.goalsForAverage,
    required this.goalsAgainstAverage,
  });

  factory TeamAnalysis.fromJson(Map<String, dynamic> json) {
    final form = json['form']?.toString() ?? '';
    final goals = json['goals'] as Map<String, dynamic>? ?? {};
    final fixtures = json['fixtures'] as Map<String, dynamic>? ?? {};

    final played = _readInt(fixtures, ['played', 'total']);
    final wins = _readInt(fixtures, ['wins', 'total']);
    final draws = _readInt(fixtures, ['draws', 'total']);

    final goalsForAverage = _readDouble(goals, ['for', 'average', 'total']);
    final goalsAgainstAverage =
    _readDouble(goals, ['against', 'average', 'total']);

    final formScore = _calculateFormScore(
      form: form,
      played: played,
      wins: wins,
      draws: draws,
      goalsForAverage: goalsForAverage,
      goalsAgainstAverage: goalsAgainstAverage,
    );

    return TeamAnalysis(
      formScore: formScore,
      goalsForAverage: goalsForAverage,
      goalsAgainstAverage: goalsAgainstAverage,
    );
  }

  static int _calculateFormScore({
    required String form,
    required int played,
    required int wins,
    required int draws,
    required double goalsForAverage,
    required double goalsAgainstAverage,
  }) {
    int score = 55;

    if (played > 0) {
      final points = (wins * 3) + draws;
      final maxPoints = played * 3;
      score = ((points / maxPoints) * 100).round();
    }

    if (form.isNotEmpty) {
      final lastFive = form.length > 5 ? form.substring(form.length - 5) : form;
      int formPoints = 0;

      for (final char in lastFive.split('')) {
        if (char == 'W') formPoints += 3;
        if (char == 'D') formPoints += 1;
      }

      final formPercent = ((formPoints / (lastFive.length * 3)) * 100).round();
      score = ((score * 0.55) + (formPercent * 0.45)).round();
    }

    if (goalsForAverage >= 2.0) score += 6;
    if (goalsAgainstAverage >= 1.8) score -= 6;

    return score.clamp(1, 99);
  }

  static int _readInt(Map<String, dynamic> root, List<String> path) {
    dynamic current = root;

    for (final key in path) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return 0;
      }
    }

    if (current is int) return current;
    return int.tryParse(current?.toString() ?? '') ?? 0;
  }

  static double _readDouble(Map<String, dynamic> root, List<String> path) {
    dynamic current = root;

    for (final key in path) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return 0;
      }
    }

    if (current is num) return current.toDouble();
    return double.tryParse(current?.toString() ?? '') ?? 0;
  }
}

class _TipPick {
  final TipType type;
  final String label;

  const _TipPick(this.type, this.label);
}