import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';

class FootballApiService {
  FootballApiService({
    PredictionEngine? predictionEngine,
    http.Client? client,
  })  : _predictionEngine = predictionEngine ?? const PredictionEngine(),
        _client = client ?? http.Client();

  final PredictionEngine _predictionEngine;
  final http.Client _client;

  static final Map<String, List<FootballMatch>> _rangeCache = <String, List<FootballMatch>>{};
  static final Map<String, DateTime> _rangeCacheTime = <String, DateTime>{};
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<List<FootballMatch>> fetchTodayFixtures({bool forceRefresh = false}) {
    return fetchFixturesForRange(
      start: DateTime.now(),
      days: 1,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<FootballMatch>> fetchFixturesForRange({
    required DateTime start,
    required int days,
    bool forceRefresh = false,
  }) async {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final safeDays = days < 1 ? 1 : days;
    final key = '${_formatDate(normalizedStart)}_$safeDays';
    final now = DateTime.now();

    if (!forceRefresh && _rangeCache.containsKey(key)) {
      final cacheTime = _rangeCacheTime[key];
      if (cacheTime != null && now.difference(cacheTime) < _cacheDuration) {
        return _rangeCache[key]!;
      }
    }

    final all = <FootballMatch>[];

    for (var offset = 0; offset < safeDays; offset++) {
      final day = normalizedStart.add(Duration(days: offset));
      final dayMatches = await _fetchDayFromSportsDb(day);
      all.addAll(dayMatches);
    }

    final unique = <String, FootballMatch>{};
    for (final match in all) {
      unique[match.id] = match;
    }

    final result = unique.values.toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));

    _rangeCache[key] = result;
    _rangeCacheTime[key] = DateTime.now();

    return result;
  }

  Future<List<FootballMatch>> _fetchDayFromSportsDb(DateTime day) async {
    try {
      final date = _formatDate(day);
      final uri = Uri.parse(
        'https://www.thesportsdb.com/api/v1/json/123/eventsday.php?d=$date&s=Soccer',
      );

      final response = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return <FootballMatch>[];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return <FootballMatch>[];

      final events = decoded['events'];
      if (events is! List || events.isEmpty) return <FootballMatch>[];

      final result = <FootballMatch>[];

      for (final raw in events) {
        if (raw is! Map<String, dynamic>) continue;

        final home = raw['strHomeTeam']?.toString().trim();
        final away = raw['strAwayTeam']?.toString().trim();
        if (home == null || home.isEmpty || away == null || away.isEmpty) continue;

        final league = raw['strLeague']?.toString().trim();
        final rawDate = raw['dateEventLocal']?.toString() ?? raw['dateEvent']?.toString() ?? date;
        final rawTime = raw['strTimeLocal']?.toString() ?? raw['strTime']?.toString() ?? '12:00:00';
        final kickoff = _parseKickoff(rawDate, rawTime, day).toLocal();

        result.add(
          _predictionEngine.buildMatch(
            id: raw['idEvent']?.toString() ?? '${home}_${away}_${kickoff.millisecondsSinceEpoch}',
            fixtureId: int.tryParse(raw['idEvent']?.toString() ?? ''),
            league: league == null || league.isEmpty ? 'Soccer' : league,
            home: home,
            away: away,
            kickoff: kickoff,
          ),
        );
      }

      result.sort((a, b) => a.kickoff.compareTo(b.kickoff));
      return result.take(80).toList();
    } catch (_) {
      return <FootballMatch>[];
    }
  }

  DateTime _parseKickoff(String rawDate, String rawTime, DateTime fallback) {
    final cleanTime = rawTime.replaceAll('Z', '').trim();
    final candidates = <String>[
      '${rawDate}T$cleanTime',
      '$rawDate $cleanTime',
      rawDate,
    ];

    for (final candidate in candidates) {
      final parsed = DateTime.tryParse(candidate);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
