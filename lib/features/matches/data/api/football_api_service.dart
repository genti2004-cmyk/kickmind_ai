import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/football_match.dart';

class FootballApiService {
  const FootballApiService();

  static List<FootballMatch>? _cache;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<List<FootballMatch>> fetchTodayFixtures() async {
    final now = DateTime.now();

    if (_cache != null && _cacheTime != null) {
      final age = now.difference(_cacheTime!);
      if (age < _cacheDuration) {
        print('✅ CACHE genutzt');
        return _cache!;
      }
    }

    final matches = await _fetchFromSportsDb(now);

    if (matches.isNotEmpty) {
      _saveCache(matches);
      return matches;
    }

    final fallback = _fallback();
    _saveCache(fallback);
    return fallback;
  }

  Future<List<FootballMatch>> _fetchFromSportsDb(DateTime now) async {
    try {
      final date = _formatDate(now);

      final uri = Uri.parse(
        'https://www.thesportsdb.com/api/v1/json/123/eventsday.php'
            '?d=$date'
            '&s=Soccer',
      );

      final response = await http.get(uri);

      print('TheSportsDB STATUS: ${response.statusCode}');
      print('TheSportsDB BODY: ${response.body}');

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final events = json['events'];

      if (events is! List || events.isEmpty) return [];

      final result = <FootballMatch>[];

      for (final raw in events) {
        if (raw is! Map<String, dynamic>) continue;

        final home = raw['strHomeTeam']?.toString() ?? 'Heimteam';
        final away = raw['strAwayTeam']?.toString() ?? 'Auswärtsteam';
        final league = raw['strLeague']?.toString() ?? 'Soccer';

        final rawDate = raw['dateEventLocal']?.toString() ??
            raw['dateEvent']?.toString() ??
            date;

        final rawTime = raw['strTimeLocal']?.toString() ??
            raw['strTime']?.toString() ??
            '12:00:00';

        final kickoff = DateTime.tryParse(
          '$rawDate ${rawTime.replaceAll('Z', '')}',
        ) ??
            now;

        final localKickoff = kickoff.toLocal();

        if (!_isInTimeWindow(localKickoff, hours: 36)) continue;

        result.add(
          _buildMatch(
            id: raw['idEvent']?.toString() ?? '${home}_$away',
            league: league,
            home: home,
            away: away,
            kickoff: localKickoff,
          ),
        );
      }

      result.sort((a, b) => a.kickoff.compareTo(b.kickoff));

      return result.take(15).toList();
    } catch (e) {
      print('⚠️ TheSportsDB Fehler: $e');
      return [];
    }
  }

  FootballMatch _buildMatch({
    required String id,
    required String league,
    required String home,
    required String away,
    required DateTime kickoff,
  }) {
    final int homeScore = (70 + home.length % 20).toInt();
    final int awayScore = (65 + away.length % 20).toInt();
    final int goalsScore = (75 + ((home.length + away.length) % 15)).toInt();

    final int diff = homeScore - awayScore;

    final int aiScore = (60 + (goalsScore ~/ 2) + (diff.abs() ~/ 2))
        .clamp(50, 92)
        .toInt();

    final TipType tip;
    final String label;

    if (goalsScore >= 82) {
      tip = TipType.over25;
      label = 'Über 2.5 Tore';
    } else if (diff >= 10) {
      tip = TipType.homeWin;
      label = 'Heimsieg';
    } else if (diff <= -10) {
      tip = TipType.awayWin;
      label = 'Auswärtssieg';
    } else {
      tip = TipType.doubleChance;
      label = 'Doppelchance';
    }

    final double odds = (1.60 + (away.length % 3) * 0.20).toDouble();

    return FootballMatch(
      id: id,
      season: kickoff.year,
      league: league,
      homeTeam: home,
      awayTeam: away,
      kickoff: kickoff,
      kickoffLabel: _kickoffLabel(kickoff),
      tipType: tip,
      tipLabel: label,
      aiScore: aiScore,
      riskLevel: aiScore >= 82 ? RiskLevel.low : RiskLevel.medium,
      odds: odds,
      homeFormScore: homeScore,
      awayFormScore: awayScore,
      goalsScore: goalsScore,
      shortReason: 'TheSportsDB Daten · lokale KickMind KI-Analyse.',
    );
  }

  bool _isInTimeWindow(DateTime kickoff, {int hours = 36}) {
    final now = DateTime.now();

    return kickoff.isAfter(now) &&
        kickoff.isBefore(now.add(Duration(hours: hours)));
  }

  void _saveCache(List<FootballMatch> data) {
    _cache = data;
    _cacheTime = DateTime.now();
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _kickoffLabel(DateTime kickoff) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final matchDay = DateTime(kickoff.year, kickoff.month, kickoff.day);

    final diff = matchDay.difference(today).inDays;

    final time =
        '${kickoff.hour.toString().padLeft(2, '0')}:${kickoff.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return 'Heute • $time';
    if (diff == 1) return 'Morgen • $time';
    if (diff == 2) return 'Übermorgen • $time';

    return '${kickoff.day.toString().padLeft(2, '0')}.'
        '${kickoff.month.toString().padLeft(2, '0')} • $time';
  }

  List<FootballMatch> _fallback() {
    final now = DateTime.now();

    return [
      _buildMatch(
        id: 'demo_1',
        league: 'Demo League',
        home: 'Team Alpha',
        away: 'Team Beta',
        kickoff: now.add(const Duration(hours: 2)),
      ),
      _buildMatch(
        id: 'demo_2',
        league: 'Demo League',
        home: 'Team Gamma',
        away: 'Team Delta',
        kickoff: now.add(const Duration(hours: 5)),
      ),
    ];
  }
}