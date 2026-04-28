import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';

class FootballApiService {
  FootballApiService({PredictionEngine? predictionEngine})
      : _predictionEngine = predictionEngine ?? const PredictionEngine();

  final PredictionEngine _predictionEngine;

  static final Map<String, List<FootballMatch>> _cache = <String, List<FootballMatch>>{};
  static final Map<String, DateTime> _cacheTime = <String, DateTime>{};
  static final Map<String, Future<List<FootballMatch>>> _inFlight = <String, Future<List<FootballMatch>>>{};

  static const Duration _cacheDuration = Duration(minutes: 30);
  static const String _apiKey = '123';

  Future<List<FootballMatch>> fetchTodayFixtures({bool forceRefresh = false}) {
    final now = DateTime.now();
    return fetchFixturesRange(
      startDate: DateTime(now.year, now.month, now.day),
      days: 1,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<FootballMatch>> fetchTomorrowFixtures({bool forceRefresh = false}) {
    final now = DateTime.now().add(const Duration(days: 1));
    return fetchFixturesRange(
      startDate: DateTime(now.year, now.month, now.day),
      days: 1,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<FootballMatch>> fetchNext3DaysFixtures({bool forceRefresh = false}) {
    final now = DateTime.now();
    return fetchFixturesRange(
      startDate: DateTime(now.year, now.month, now.day),
      days: 3,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<FootballMatch>> fetchWeekFixtures({bool forceRefresh = false}) {
    final now = DateTime.now();
    return fetchFixturesRange(
      startDate: DateTime(now.year, now.month, now.day),
      days: 7,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<FootballMatch>> fetchFixturesRange({
    required DateTime startDate,
    required int days,
    bool forceRefresh = false,
  }) async {
    final safeDays = days.clamp(1, 14);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final cacheKey = '${_formatDate(start)}_$safeDays';
    final now = DateTime.now();

    if (!forceRefresh && _cache.containsKey(cacheKey) && _cacheTime.containsKey(cacheKey)) {
      if (now.difference(_cacheTime[cacheKey]!) < _cacheDuration) {
        return _cache[cacheKey]!;
      }
    }

    if (!forceRefresh && _inFlight.containsKey(cacheKey)) {
      return _inFlight[cacheKey]!;
    }

    final request = _loadRange(start: start, days: safeDays);
    _inFlight[cacheKey] = request;

    try {
      final data = await request;
      _cache[cacheKey] = data;
      _cacheTime[cacheKey] = DateTime.now();
      return data;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<List<FootballMatch>> _loadRange({
    required DateTime start,
    required int days,
  }) async {
    final all = <FootballMatch>[];

    for (var i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      final matches = await _fetchDate(date);
      all.addAll(matches);
    }

    final unique = <String, FootballMatch>{};
    for (final match in all) {
      unique[match.id] = match;
    }

    final result = unique.values.toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));

    return result.take(120).toList();
  }

  Future<List<FootballMatch>> _fetchDate(DateTime date) async {
    try {
      final formattedDate = _formatDate(date);
      final uri = Uri.parse(
        'https://www.thesportsdb.com/api/v1/json/$_apiKey/eventsday.php?d=$formattedDate&s=Soccer',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 12));
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
        final rawDate = raw['dateEventLocal']?.toString().trim().isNotEmpty == true
            ? raw['dateEventLocal'].toString().trim()
            : (raw['dateEvent']?.toString().trim().isNotEmpty == true
            ? raw['dateEvent'].toString().trim()
            : formattedDate);
        final rawTime = raw['strTimeLocal']?.toString().trim().isNotEmpty == true
            ? raw['strTimeLocal'].toString().trim()
            : (raw['strTime']?.toString().trim().isNotEmpty == true
            ? raw['strTime'].toString().trim()
            : '12:00:00');

        final kickoff = _parseKickoff(rawDate, rawTime, date).toLocal();

        result.add(
          _predictionEngine.buildMatch(
            id: raw['idEvent']?.toString() ?? '${home}_${away}_${kickoff.millisecondsSinceEpoch}',
            fixtureId: int.tryParse(raw['idEvent']?.toString() ?? ''),
            season: kickoff.year,
            league: league == null || league.isEmpty ? 'Soccer' : league,
            home: home,
            away: away,
            kickoff: kickoff,
          ),
        );
      }

      result.sort((a, b) => a.kickoff.compareTo(b.kickoff));
      return result;
    } catch (_) {
      return <FootballMatch>[];
    }
  }

  DateTime _parseKickoff(String rawDate, String rawTime, DateTime fallbackDate) {
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

    return DateTime(fallbackDate.year, fallbackDate.month, fallbackDate.day, 12);
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
