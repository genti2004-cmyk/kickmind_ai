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
  static const int _maxDaysPerRequest = 7;

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
    final safeDays = days.clamp(1, _maxDaysPerRequest).toInt();
    final key = '${_formatDate(normalizedStart)}_$safeDays';
    final now = DateTime.now();

    if (!forceRefresh && _rangeCache.containsKey(key)) {
      final cacheTime = _rangeCacheTime[key];
      final cached = _rangeCache[key];
      if (cacheTime != null &&
          cached != null &&
          now.difference(cacheTime) < _cacheDuration) {
        return List<FootballMatch>.from(cached);
      }
    }

    final all = <FootballMatch>[];

    for (var offset = 0; offset < safeDays; offset++) {
      final day = normalizedStart.add(Duration(days: offset));
      final dayMatches = await _fetchDayFromSportsDb(day);
      all.addAll(dayMatches);
    }

    final result = _dedupeAndSort(all)
        .where((match) => _isInsideRange(match.kickoff, normalizedStart, safeDays))
        .take(160)
        .toList();

    _rangeCache[key] = List<FootballMatch>.from(result);
    _rangeCacheTime[key] = DateTime.now();

    return result;
  }

  Future<List<FootballMatch>> _fetchDayFromSportsDb(DateTime day) async {
    try {
      final date = _formatDate(day);
      final uri = Uri.https(
        'www.thesportsdb.com',
        '/api/v1/json/123/eventsday.php',
        <String, String>{
          'd': date,
          's': 'Soccer',
        },
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

        final home = _clean(raw['strHomeTeam']);
        final away = _clean(raw['strAwayTeam']);
        if (home == null || away == null) continue;

        final league = _clean(raw['strLeague']) ?? 'Soccer';
        final id = _clean(raw['idEvent']) ?? '${home}_${away}_${date}';
        final kickoff = _parseKickoff(raw, fallbackDay: day);

        result.add(
          _predictionEngine.buildMatch(
            id: id,
            fixtureId: int.tryParse(id),
            league: league,
            home: home,
            away: away,
            kickoff: kickoff,
          ),
        );
      }

      return _dedupeAndSort(result).take(80).toList();
    } catch (_) {
      return <FootballMatch>[];
    }
  }

  List<FootballMatch> _dedupeAndSort(List<FootballMatch> matches) {
    final unique = <String, FootballMatch>{};

    for (final match in matches) {
      final key = match.fixtureId?.toString() ??
          '${match.id}_${match.homeTeam}_${match.awayTeam}_${match.kickoff.millisecondsSinceEpoch}';
      unique[key] = match;
    }

    final result = unique.values.toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    return result;
  }

  bool _isInsideRange(DateTime kickoff, DateTime start, int days) {
    final from = DateTime(start.year, start.month, start.day);
    final to = from.add(Duration(days: days));
    return !kickoff.isBefore(from) && kickoff.isBefore(to);
  }

  DateTime _parseKickoff(
      Map<String, dynamic> raw, {
        required DateTime fallbackDay,
      }) {
    final timestamp = _clean(raw['strTimestamp']);
    if (timestamp != null) {
      final parsedTimestamp = DateTime.tryParse(timestamp.replaceAll(' ', 'T'));
      if (parsedTimestamp != null) return parsedTimestamp.toLocal();
    }

    final rawDate = _clean(raw['dateEventLocal']) ??
        _clean(raw['dateEvent']) ??
        _formatDate(fallbackDay);
    final rawTime = _clean(raw['strTimeLocal']) ??
        _clean(raw['strTime']) ??
        '12:00:00';

    final cleanTime = rawTime.replaceAll('Z', '').trim();
    final candidates = <String>[
      '${rawDate}T$cleanTime',
      '$rawDate $cleanTime',
      rawDate,
    ];

    for (final candidate in candidates) {
      final parsed = DateTime.tryParse(candidate);
      if (parsed != null) return parsed.toLocal();
    }

    return DateTime(
      fallbackDay.year,
      fallbackDay.month,
      fallbackDay.day,
      12,
    );
  }

  String? _clean(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
