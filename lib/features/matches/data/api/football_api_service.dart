import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kickmind_ai/core/config/api_config.dart';
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
  static final Map<String, Future<List<FootballMatch>>> _inFlight = <String, Future<List<FootballMatch>>>{};
  static final Map<String, List<FootballMatch>> _fixtureDayCache = <String, List<FootballMatch>>{};
  static final Map<String, List<_OddsSnapshot>> _oddsDayCache = <String, List<_OddsSnapshot>>{};
  static final Map<String, _FixtureTeams> _fixtureTeamsByIdCache = <String, _FixtureTeams>{};
  static final Map<String, Future<List<FootballMatch>>> _fixtureDayInFlight = <String, Future<List<FootballMatch>>>{};
  static final Map<String, Future<List<_OddsSnapshot>>> _oddsDayInFlight = <String, Future<List<_OddsSnapshot>>>{};

  // Kurzer Speicher nur gegen doppelte Parallel-Requests beim Tab-/Seitenwechsel.
  // Leere Ergebnisse werden nie gecacht.
  static const Duration _cacheDuration = Duration(minutes: 2);
  static const Duration _diskCacheMaxAge = Duration(hours: 18);
  static const int _maxDaysPerRequest = 7;
  static const int _minimumFixtureTargetPerDay = 8;

  // API-Football Free/Plan-Limit-Schutz:
  // Sobald API-Football meldet, dass das Tageslimit erreicht ist, stoppen wir
  // weitere API-Football-Requests in dieser App-Sitzung und nutzen nur noch
  // echte Fallback-Spielpläne. So wird das Limit nicht durch Folge-Requests
  // weiter belastet und die App bleibt stabil.
  static bool _apiFootballDailyLimitReached = false;
  static String? _apiFootballDailyLimitDateKey;
  static bool _apiFootballDailyLimitLoadedFromDisk = false;
  static const String _apiFootballDailyLimitPrefsKey = 'kickmind_api_football_daily_limit_date_v1';
  static final Set<String> _printedLogKeys = <String>{};

  void _logOnce(String key, String message) {
    if (_printedLogKeys.add(key)) {
      // ignore: avoid_print
      print(message);
    }
  }


  static const List<_ApiLeagueRef> _supplementalApiFootballLeagues = <_ApiLeagueRef>[
    _ApiLeagueRef(1),
    _ApiLeagueRef(2),
    _ApiLeagueRef(3),
    _ApiLeagueRef(4),
    _ApiLeagueRef(10),
    _ApiLeagueRef(15),
    _ApiLeagueRef(39),
    _ApiLeagueRef(40),
    _ApiLeagueRef(61),
    _ApiLeagueRef(78),
    _ApiLeagueRef(88),
    _ApiLeagueRef(94),
    _ApiLeagueRef(103),
    _ApiLeagueRef(113),
    _ApiLeagueRef(119),
    _ApiLeagueRef(135),
    _ApiLeagueRef(140),
    _ApiLeagueRef(144),
    _ApiLeagueRef(203),
    _ApiLeagueRef(218),
    _ApiLeagueRef(244),
    _ApiLeagueRef(253),
    _ApiLeagueRef(71),
    _ApiLeagueRef(128),
  ];

  static const List<_EspnSoccerLeagueRef> _espnSoccerLeagues = <_EspnSoccerLeagueRef>[
    _EspnSoccerLeagueRef('fifa.world', 'FIFA World Cup'),
    _EspnSoccerLeagueRef('uefa.champions', 'UEFA Champions League'),
    _EspnSoccerLeagueRef('uefa.europa', 'UEFA Europa League'),
    _EspnSoccerLeagueRef('uefa.europa.conf', 'UEFA Conference League'),
    _EspnSoccerLeagueRef('eng.1', 'Premier League'),
    _EspnSoccerLeagueRef('eng.2', 'Championship'),
    _EspnSoccerLeagueRef('esp.1', 'LaLiga'),
    _EspnSoccerLeagueRef('ger.1', 'Bundesliga'),
    _EspnSoccerLeagueRef('ita.1', 'Serie A'),
    _EspnSoccerLeagueRef('fra.1', 'Ligue 1'),
    _EspnSoccerLeagueRef('ned.1', 'Eredivisie'),
    _EspnSoccerLeagueRef('por.1', 'Liga Portugal'),
    _EspnSoccerLeagueRef('tur.1', 'Super Lig'),
    _EspnSoccerLeagueRef('usa.1', 'MLS'),
    _EspnSoccerLeagueRef('mex.1', 'Liga MX'),
    _EspnSoccerLeagueRef('bra.1', 'Brasileirao'),
    _EspnSoccerLeagueRef('arg.1', 'Argentine Primera'),
  ];

  static const List<String> _acceptedBookmakerNames = <String>[
    'betano',
    'bet365',
    'bet 365',
    'betbat',
    'bet bat',
    'homebet',
    'home bet',
    'bet-at-home',
    'bet at home',
    'betathome',
  ];

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
    final key = 'sofascore_style_v3_${_formatDate(normalizedStart)}_$safeDays';
    final now = DateTime.now();

    if (!forceRefresh && _rangeCache.containsKey(key)) {
      final cacheTime = _rangeCacheTime[key];
      final cached = _rangeCache[key];
      if (cacheTime != null &&
          cached != null &&
          cached.isNotEmpty &&
          now.difference(cacheTime) < _cacheDuration) {
        return List<FootballMatch>.from(cached);
      }
    }

    if (!forceRefresh && _inFlight.containsKey(key)) {
      return List<FootballMatch>.from(await _inFlight[key]!);
    }

    final future = _loadFixturesForRangeOnline(
      key: key,
      normalizedStart: normalizedStart,
      safeDays: safeDays,
    );

    _inFlight[key] = future;
    try {
      return List<FootballMatch>.from(await future);
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<List<FootballMatch>> _loadFixturesForRangeOnline({
    required String key,
    required DateTime normalizedStart,
    required int safeDays,
  }) async {
    if (!ApiConfig.hasFootballApiKey) {
      return _loadPersistedRange(key, normalizedStart, safeDays);
    }

    await _restoreApiFootballDailyLimitIfNeeded();

    final fixtureMatches = <FootballMatch>[];
    final oddsByFixtureId = <int, _OddsSnapshot>{};

    for (var offset = 0; offset < safeDays; offset++) {
      final day = normalizedStart.add(Duration(days: offset));
      final dayFixtures = await _fetchFixturesForDay(day);
      fixtureMatches.addAll(dayFixtures);

      final dayOdds = await _fetchAcceptedOddsForDay(day);
      for (final odds in dayOdds) {
        oddsByFixtureId[odds.fixtureId] = odds;
      }
    }

    final minimumFixtureTarget = safeDays * _minimumFixtureTargetPerDay;

    // Wenn /fixtures?date=... nur sehr wenige Spiele liefert, ergänzen wir mit
    // echten API-Football-League-Abfragen für denselben Zeitraum. Dadurch wird
    // die Liste nicht künstlich auf 3 Spiele pro Tag begrenzt.
    if (fixtureMatches.length < minimumFixtureTarget) {
      final supplementalFixtures = await _fetchApiFootballFixturesByLeagueRange(
        start: normalizedStart,
        days: safeDays,
        currentCount: fixtureMatches.length,
      );
      fixtureMatches.addAll(supplementalFixtures);
    }

    // Wenn API-Football /fixtures weiter leer oder zu klein bleibt, nutzen wir
    // TheSportsDB als echten Spielplan-Fallback. Keine Dummy-Spiele.
    if (fixtureMatches.length < minimumFixtureTarget) {
      for (var offset = 0; offset < safeDays; offset++) {
        final day = normalizedStart.add(Duration(days: offset));
        final dayFixtures = await _fetchDayFromSportsDb(day);
        fixtureMatches.addAll(dayFixtures);
      }
    }

    // Zweite echte Zusatzquelle: ESPN Soccer Scoreboard. Wichtig: nicht der
    // allgemeine Soccer-Endpunkt, sondern konkrete Liga-Codes. So finden wir
    // auch Turniere wie FIFA World Cup über fifa.world. Keine Dummy-Spiele.
    if (fixtureMatches.length < minimumFixtureTarget) {
      final espnMatches = await _fetchEspnSoccerSupplement(
        start: normalizedStart,
        days: safeDays,
      );
      fixtureMatches.addAll(espnMatches);
    }

    // Odds werden ebenfalls nur echt ergänzt: zuerst Datum, danach League/Season.
    if (oddsByFixtureId.length < safeDays * 4) {
      final supplementalOdds = await _fetchAcceptedOddsByLeagueRange(
        start: normalizedStart,
        days: safeDays,
        currentCount: oddsByFixtureId.length,
      );
      for (final odds in supplementalOdds) {
        oddsByFixtureId[odds.fixtureId] = odds;
      }
    }

    final mergedByFixtureId = <int, FootballMatch>{};
    final synthetic = <FootballMatch>[];

    for (final match in fixtureMatches) {
      final fixtureId = match.fixtureId;
      if (fixtureId == null) {
        final odds = _findOddsByTeams(match, oddsByFixtureId.values);
        if (odds == null) {
          synthetic.add(match);
        } else {
          mergedByFixtureId[odds.fixtureId] = _applyOddsToFixture(match, odds);
        }
        continue;
      }

      final odds = oddsByFixtureId[fixtureId] ?? _findOddsByTeams(match, oddsByFixtureId.values);
      mergedByFixtureId[fixtureId] = odds == null ? match : _applyOddsToFixture(match, odds);
    }

    for (final odds in oddsByFixtureId.values) {
      if (mergedByFixtureId.containsKey(odds.fixtureId)) continue;
      final fallback = _buildMatchFromOddsSnapshot(odds);
      if (fallback != null) mergedByFixtureId[odds.fixtureId] = fallback;
    }

    final result = _dedupeAndSort(<FootballMatch>[
      ...mergedByFixtureId.values,
      ...synthetic,
    ])
        .where((match) => _isInsideRange(match.kickoff, normalizedStart, safeDays))
        .take(260)
        .toList();

    if (result.isNotEmpty) {
      _rememberSuccessfulRange(key, result);
      await _persistSuccessfulRange(key, result);
      return result;
    }

    // Wichtig: ein leerer API-Abruf darf die zuvor echten geladenen Spiele
    // nicht löschen. Dadurch bleibt die App nach Neustart/Tabwechsel stabil.
    return _loadPersistedRange(key, normalizedStart, safeDays);
  }


  void _rememberSuccessfulRange(String key, List<FootballMatch> matches) {
    if (matches.isEmpty) return;
    _rangeCache[key] = List<FootballMatch>.from(matches);
    _rangeCacheTime[key] = DateTime.now();
  }

  Future<void> _persistSuccessfulRange(String key, List<FootballMatch> matches) async {
    if (matches.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'savedAt': DateTime.now().toIso8601String(),
        'matches': matches.map((m) => m.toJson()).toList(),
      };
      await prefs.setString(_diskCacheKey(key), jsonEncode(payload));
    } catch (_) {
      // Cache darf niemals den echten API-Flow blockieren.
    }
  }

  Future<List<FootballMatch>> _loadPersistedRange(
      String key,
      DateTime normalizedStart,
      int safeDays,
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskCacheKey(key));
      if (raw == null || raw.trim().isEmpty) return <FootballMatch>[];

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <FootballMatch>[];

      final savedAt = DateTime.tryParse(decoded['savedAt']?.toString() ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > _diskCacheMaxAge) {
        await prefs.remove(_diskCacheKey(key));
        return <FootballMatch>[];
      }

      final rawMatches = decoded['matches'];
      if (rawMatches is! List || rawMatches.isEmpty) return <FootballMatch>[];

      final matches = rawMatches
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .map(FootballMatch.fromJson)
          .where((m) => _isInsideRange(m.kickoff, normalizedStart, safeDays))
          .where((m) => m.homeTeam.trim().isNotEmpty && m.awayTeam.trim().isNotEmpty)
          .toList();

      final result = _dedupeAndSort(matches);
      if (result.isNotEmpty) {
        _rememberSuccessfulRange(key, result);
      }
      return result;
    } catch (_) {
      return <FootballMatch>[];
    }
  }

  String _diskCacheKey(String key) => 'kickmind_real_fixtures_cache_v2_$key';

  Future<List<FootballMatch>> _fetchFixturesForDay(DateTime day) async {
    final key = _formatDate(day);
    final cached = _fixtureDayCache[key];
    if (cached != null && cached.isNotEmpty) return List<FootballMatch>.from(cached);

    final running = _fixtureDayInFlight[key];
    if (running != null) return List<FootballMatch>.from(await running);

    final future = _fetchFixturesForDayOnline(day);
    _fixtureDayInFlight[key] = future;
    try {
      final result = await future;
      if (result.isNotEmpty) _fixtureDayCache[key] = List<FootballMatch>.from(result);
      return result;
    } finally {
      _fixtureDayInFlight.remove(key);
    }
  }

  Future<List<FootballMatch>> _fetchFixturesForDayOnline(DateTime day) async {
    final date = _formatDate(day);
    if (_isApiFootballDailyLimitBlocked()) {
      _logOnce('api_limit_skip_fixtures', 'API-FOOTBALL LIMIT SKIP fixtures: Tageslimit aktiv.');
      return <FootballMatch>[];
    }

    try {
      final uri = Uri.parse('${ApiConfig.footballBaseUrl}/fixtures?date=$date');
      final response = await _client.get(
        uri,
        headers: <String, String>{
          'x-apisports-key': ApiConfig.footballApiKey,
        },
      ).timeout(const Duration(seconds: 14));

      if (response.statusCode != 200) {
        _logOnce('fixtures_status_${response.statusCode}', 'FIXTURES STATUS ${response.statusCode}.');
        return <FootballMatch>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return <FootballMatch>[];
      if (_markApiFootballDailyLimitIfNeeded(decoded, context: 'fixtures $date')) {
        return <FootballMatch>[];
      }

      final rawResponse = decoded['response'];
      if (rawResponse is! List || rawResponse.isEmpty) {
        _logOnce('fixtures_empty', 'FIXTURES EMPTY: API-Football liefert aktuell keine Fixture-Liste.');
        return <FootballMatch>[];
      }

      final matches = <FootballMatch>[];
      for (final raw in rawResponse) {
        final item = _asMap(raw);
        if (item == null) continue;
        final match = _buildFixtureOnlyMatch(item, fallbackDay: day);
        if (match != null) matches.add(match);
      }

      final sorted = _dedupeAndSort(matches);
      // Konsole ruhig halten: erfolgreiche Fixture-Abrufe werden nicht jedes Mal geloggt.
      return sorted;
    } catch (_) {
      return <FootballMatch>[];
    }
  }


  Future<List<FootballMatch>> _fetchApiFootballFixturesByLeagueRange({
    required DateTime start,
    required int days,
    required int currentCount,
  }) async {
    final result = <FootballMatch>[];
    final from = _formatDate(start);
    final to = _formatDate(start.add(Duration(days: days - 1)));
    if (_isApiFootballDailyLimitBlocked()) {
      _logOnce('api_limit_skip_fixtures_league', 'API-FOOTBALL LIMIT SKIP fixtures league supplement: Tageslimit aktiv.');
      return <FootballMatch>[];
    }
    final target = days * _minimumFixtureTargetPerDay;
    final seasons = _seasonCandidates(start);

    for (final league in _supplementalApiFootballLeagues) {
      for (final season in seasons) {
        if (currentCount + result.length >= target * 2) break;

        try {
          final uri = Uri.parse(
            '${ApiConfig.footballBaseUrl}/fixtures?league=${league.id}&season=$season&from=$from&to=$to&timezone=Europe/Tirane',
          );
          final response = await _client.get(
            uri,
            headers: <String, String>{
              'x-apisports-key': ApiConfig.footballApiKey,
            },
          ).timeout(const Duration(seconds: 12));

          if (response.statusCode != 200) continue;

          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) continue;
          if (_markApiFootballDailyLimitIfNeeded(
            decoded,
            context: 'fixtures league ${league.id} season $season $from-$to',
          )) {
            return _dedupeAndSort(result);
          }

          final rawResponse = decoded['response'];
          if (rawResponse is! List || rawResponse.isEmpty) continue;

          for (final raw in rawResponse) {
            final item = _asMap(raw);
            if (item == null) continue;
            final match = _buildFixtureOnlyMatch(item, fallbackDay: start);
            if (match != null && _isInsideRange(match.kickoff, start, days)) {
              result.add(match);
            }
          }
        } catch (_) {
          continue;
        }
      }
    }

    final sorted = _dedupeAndSort(result);
    // Konsole ruhig halten: League-Supplement-Erfolg wird nicht jedes Mal geloggt.
    return sorted;
  }

  Future<List<_OddsSnapshot>> _fetchAcceptedOddsByLeagueRange({
    required DateTime start,
    required int days,
    required int currentCount,
  }) async {
    final result = <_OddsSnapshot>[];
    final from = _formatDate(start);
    final to = _formatDate(start.add(Duration(days: days - 1)));
    if (_isApiFootballDailyLimitBlocked()) {
      _logOnce('api_limit_skip_odds_league', 'API-FOOTBALL LIMIT SKIP odds league supplement: Tageslimit aktiv.');
      return <_OddsSnapshot>[];
    }
    final target = (days * 12).clamp(12, 80).toInt();
    final seasons = _seasonCandidates(start);

    for (final league in _supplementalApiFootballLeagues.take(16)) {
      for (final season in seasons) {
        if (currentCount + result.length >= target) break;

        for (var page = 1; page <= 4; page++) {
          try {
            final uri = Uri.parse(
              '${ApiConfig.footballBaseUrl}/odds?league=${league.id}&season=$season&page=$page',
            );
            final response = await _client.get(
              uri,
              headers: <String, String>{
                'x-apisports-key': ApiConfig.footballApiKey,
              },
            ).timeout(const Duration(seconds: 12));

            if (response.statusCode != 200) break;

            final decoded = jsonDecode(response.body);
            if (decoded is! Map<String, dynamic>) break;
            if (_markApiFootballDailyLimitIfNeeded(
              decoded,
              context: 'odds league ${league.id} season $season page $page',
            )) {
              return result;
            }

            final rawResponse = decoded['response'];
            if (rawResponse is! List || rawResponse.isEmpty) break;

            for (final raw in rawResponse) {
              final item = _asMap(raw);
              if (item == null) continue;
              final odds = await _readOddsSnapshot(item, fallbackDay: start);
              if (odds != null && _isInsideRange(odds.kickoff, start, days)) {
                result.add(odds);
              }
            }

            final paging = _asMap(decoded['paging']);
            final current = int.tryParse(paging?['current']?.toString() ?? '') ?? page;
            final total = int.tryParse(paging?['total']?.toString() ?? '') ?? page;
            if (current >= total) break;
          } catch (_) {
            break;
          }
        }
      }
    }

    final unique = <int, _OddsSnapshot>{};
    for (final odds in result) {
      unique[odds.fixtureId] = odds;
    }

    final sorted = unique.values.toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    // Konsole ruhig halten: Odds-Supplement-Erfolg wird nicht jedes Mal geloggt.
    return sorted;
  }

  List<int> _seasonCandidates(DateTime start) {
    final seasons = <int>{start.year, start.year - 1};
    if (start.month >= 7) seasons.add(start.year + 1);
    return seasons.toList()..sort((a, b) => b.compareTo(a));
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
      if (response.statusCode != 200) {
        _logOnce('sportsdb_status_${response.statusCode}', 'SPORTSDB STATUS ${response.statusCode}.');
        return <FootballMatch>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return <FootballMatch>[];

      final events = decoded['events'];
      if (events is! List || events.isEmpty) {
        _logOnce('sportsdb_empty', 'SPORTSDB EMPTY: keine Soccer-Spiele für geprüften Tag.');
        return <FootballMatch>[];
      }

      final result = <FootballMatch>[];

      for (final raw in events) {
        final item = _asMap(raw);
        if (item == null) continue;

        final home = _clean(item['strHomeTeam']);
        final away = _clean(item['strAwayTeam']);
        if (home == null || away == null) continue;

        final league = _clean(item['strLeague']) ?? 'Soccer';
        final eventId = _clean(item['idEvent']) ?? '${home}_${away}_$date';
        final kickoff = _parseSportsDbKickoff(item, fallbackDay: day);

        final match = _predictionEngine.buildMatch(
          id: 'sportsdb_$eventId',
          fixtureId: null,
          league: league,
          home: home,
          away: away,
          kickoff: kickoff,
          odds: 0.0,
        );

        result.add(
          _applyKickMindMatchScore(
            match,
            source: 'TheSportsDB',
            baseReason: 'Echtes Spiel aus TheSportsDB-Spielplan. Keine echte passende Betano/Bet365/Betbat/Homebet-Quote gefunden – deshalb kein echter Wett-Tipp.',
          ),
        );
      }

      final sorted = _dedupeAndSort(result).take(220).toList();
      // Konsole ruhig halten: erfolgreiche SportsDB-Fallbacks werden nicht jedes Mal geloggt.
      return sorted;
    } catch (error) {
      _logOnce('sportsdb_error_${error.runtimeType}', 'SPORTSDB ERROR: ${error.runtimeType}');
      return <FootballMatch>[];
    }
  }

  Future<List<FootballMatch>> _fetchEspnSoccerSupplement({
    required DateTime start,
    required int days,
  }) async {
    final result = <FootballMatch>[];
    final fromText = _formatDate(start);
    final toText = _formatDate(start.add(Duration(days: days - 1)));

    for (var offset = 0; offset < days; offset++) {
      final day = DateTime(start.year, start.month, start.day).add(Duration(days: offset));
      for (final league in _espnSoccerLeagues) {
        try {
          final dayMatches = await _fetchEspnSoccerLeagueDay(
            day: day,
            league: league,
          );
          result.addAll(dayMatches);
        } catch (_) {
          // Einzelne ESPN-Ligen dürfen den gesamten echten Fallback nicht blockieren.
        }
      }
    }

    final sorted = _dedupeAndSort(result)
        .where((match) => _isInsideRange(match.kickoff, start, days))
        .take(220)
        .toList();

    // Konsole ruhig halten: erfolgreiche ESPN-Supplements werden nicht jedes Mal geloggt.
    return sorted;
  }

  Future<List<FootballMatch>> _fetchEspnSoccerLeagueDay({
    required DateTime day,
    required _EspnSoccerLeagueRef league,
  }) async {
    final result = <FootballMatch>[];
    final uri = Uri.https(
      'site.api.espn.com',
      '/apis/site/v2/sports/soccer/${league.code}/scoreboard',
      <String, String>{
        'dates': _formatEspnDate(day),
        'limit': '200',
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return <FootballMatch>[];

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return <FootballMatch>[];

    final events = decoded['events'];
    if (events is! List || events.isEmpty) return <FootballMatch>[];

    for (final raw in events) {
      final event = _asMap(raw);
      if (event == null) continue;
      final match = _buildEspnMatch(event, fallbackDay: day, fallbackLeague: league.name);
      if (match != null) result.add(match);
    }

    return _dedupeAndSort(result);
  }

  FootballMatch? _buildEspnMatch(
      Map<String, dynamic> event, {
        required DateTime fallbackDay,
        required String fallbackLeague,
      }) {
    final eventId = _clean(event['id']);
    final competitions = event['competitions'];
    if (competitions is! List || competitions.isEmpty) return null;

    final competition = _asMap(competitions.first);
    if (competition == null) return null;

    final competitors = competition['competitors'];
    if (competitors is! List || competitors.length < 2) return null;

    String? home;
    String? away;

    for (final rawCompetitor in competitors) {
      final competitor = _asMap(rawCompetitor);
      if (competitor == null) continue;
      final team = _asMap(competitor['team']);
      final name = _clean(team?['displayName']) ??
          _clean(team?['shortDisplayName']) ??
          _clean(team?['name']);
      if (name == null) continue;

      final homeAway = _clean(competitor['homeAway'])?.toLowerCase();
      if (homeAway == 'home') {
        home = name;
      } else if (homeAway == 'away') {
        away = name;
      }
    }

    // Sicherheitsfallback, falls ESPN bei neutralen Spielen homeAway anders setzt.
    if (home == null || away == null) {
      final first = _asMap(competitors[0]);
      final second = _asMap(competitors[1]);
      home ??= _clean(_asMap(first?['team'])?['displayName']) ??
          _clean(_asMap(first?['team'])?['shortDisplayName']) ??
          _clean(_asMap(first?['team'])?['name']);
      away ??= _clean(_asMap(second?['team'])?['displayName']) ??
          _clean(_asMap(second?['team'])?['shortDisplayName']) ??
          _clean(_asMap(second?['team'])?['name']);
    }

    if (home == null || away == null || home.trim().isEmpty || away.trim().isEmpty) {
      return null;
    }

    final kickoff = _parseEspnKickoff(event['date'], fallbackDay: fallbackDay);
    final leagueName = _clean(_asMap(event['league'])?['name']) ?? fallbackLeague;
    final id = eventId == null || eventId.isEmpty
        ? 'espn_${_normalizeTeamName(home)}_${_normalizeTeamName(away)}_${_formatDate(kickoff)}'
        : 'espn_$eventId';

    final match = _predictionEngine.buildMatch(
      id: id,
      fixtureId: null,
      season: kickoff.year,
      league: leagueName,
      home: home,
      away: away,
      kickoff: kickoff,
      tipType: TipType.homeWin,
      odds: 0.0,
    );

    return _applyKickMindMatchScore(
      match,
      source: 'ESPN',
      baseReason: 'Echtes Spiel aus ESPN Soccer Scoreboard. Keine echte passende Betano/Bet365/Betbat/Homebet-Quote gefunden – deshalb kein echter Wett-Tipp.',
    );
  }

  DateTime _parseEspnKickoff(
      Object? rawDate, {
        required DateTime fallbackDay,
      }) {
    final text = rawDate?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      final parsed = DateTime.tryParse(text);
      if (parsed != null) return parsed.toLocal();
    }

    return DateTime(fallbackDay.year, fallbackDay.month, fallbackDay.day, 12);
  }

  String _formatEspnDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseSportsDbKickoff(
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

  FootballMatch _applyKickMindMatchScore(
      FootballMatch match, {
        required String source,
        required String baseReason,
      }) {
    final sourceScore = _sourceQualityScore(source);
    final leagueScore = _leagueQualityScore(match.league);
    final teamScore = _teamNameQualityScore(match.homeTeam, match.awayTeam);
    final timeScore = _kickoffQualityScore(match.kickoff);
    final oddsScore = match.hasPlayableOdds ? _oddsQualityScore(match.odds) : 0;

    final rawScore = 42 + sourceScore + leagueScore + teamScore + timeScore + oddsScore;
    final kickMindScore = rawScore.clamp(35, 88).toInt();
    final risk = _riskFromKickMindScore(kickMindScore, hasOdds: match.hasPlayableOdds);
    final tipType = _selectFallbackTipType(match, kickMindScore);
    final tipLabel = _tipLabelFor(tipType);
    final reason = _buildKickMindScoreReason(
      baseReason: baseReason,
      source: source,
      score: kickMindScore,
      leagueScore: leagueScore,
      teamScore: teamScore,
      timeScore: timeScore,
      hasOdds: match.hasPlayableOdds,
    );

    return match.copyWith(
      tipType: tipType,
      tipLabel: tipLabel,
      aiScore: kickMindScore,
      riskLevel: risk,
      odds: match.hasPlayableOdds ? match.odds : 0.0,
      hasRealOdds: match.hasRealOdds,
      realOddsBookmaker: match.realOddsBookmaker,
      shortReason: reason,
    );
  }

  int _sourceQualityScore(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('api-football')) return 13;
    if (normalized.contains('espn')) return 11;
    if (normalized.contains('sportsdb')) return 8;
    return 6;
  }

  int _leagueQualityScore(String league) {
    final text = league.toLowerCase();
    if (text.contains('world cup') || text.contains('champions league')) return 13;
    if (text.contains('premier league') || text.contains('laliga') || text.contains('bundesliga')) return 12;
    if (text.contains('serie a') || text.contains('ligue 1') || text.contains('europa league')) return 11;
    if (text.contains('eredivisie') || text.contains('liga portugal') || text.contains('mls')) return 8;
    if (text.contains('championship') || text.contains('super lig') || text.contains('liga mx')) return 7;
    if (text.trim().isEmpty || text == 'soccer') return 3;
    return 5;
  }

  int _teamNameQualityScore(String home, String away) {
    final h = _normalizeTeamName(home);
    final a = _normalizeTeamName(away);
    if (h.isEmpty || a.isEmpty || h == a) return 0;
    if (h.startsWith('heimteam') || a.startsWith('auswartsteam') || a.startsWith('auswärtsteam')) return 0;
    var score = 5;
    if (h.length >= 4 && a.length >= 4) score += 3;
    if (h.length >= 8 && a.length >= 8) score += 2;
    return score.clamp(0, 10).toInt();
  }

  int _kickoffQualityScore(DateTime kickoff) {
    final now = DateTime.now();
    final diffHours = kickoff.difference(now).inHours;
    if (diffHours >= 0 && diffHours <= 36) return 7;
    if (diffHours > 36 && diffHours <= 96) return 6;
    if (diffHours > 96 && diffHours <= 168) return 5;
    if (diffHours < 0 && diffHours >= -8) return 3;
    return 1;
  }

  int _oddsQualityScore(double odds) {
    if (odds < 1.18 || odds > 4.80) return 0;
    if (odds >= 1.55 && odds <= 2.25) return 9;
    if (odds >= 1.35 && odds <= 2.80) return 6;
    return 3;
  }

  String _riskFromKickMindScore(int score, {required bool hasOdds}) {
    if (!hasOdds) {
      if (score >= 72) return 'Mittel';
      return 'Beobachten';
    }
    if (score >= 76) return 'Niedrig';
    if (score >= 62) return 'Mittel';
    return 'Hoch';
  }

  TipType _selectFallbackTipType(FootballMatch match, int score) {
    if (match.hasPlayableOdds) return match.tipType;

    final league = match.league.toLowerCase();
    final home = _normalizeTeamName(match.homeTeam);
    final away = _normalizeTeamName(match.awayTeam);
    final homeBias = (home.length - away.length).abs();

    if (league.contains('world cup') || league.contains('champions') || league.contains('premier')) {
      return TipType.over25;
    }
    if (score >= 70 && homeBias <= 3) return TipType.btts;
    if (score >= 64) return TipType.over25;
    return TipType.homeWin;
  }

  String _tipLabelFor(TipType type) {
    switch (type) {
      case TipType.homeWin:
        return '1';
      case TipType.draw:
        return 'X';
      case TipType.awayWin:
        return '2';
      case TipType.over25:
        return 'Ü2.5';
      case TipType.under25:
        return 'U2.5';
      case TipType.btts:
        return 'BTTS';
    }
  }

  String _buildKickMindScoreReason({
    required String baseReason,
    required String source,
    required int score,
    required int leagueScore,
    required int teamScore,
    required int timeScore,
    required bool hasOdds,
  }) {
    final label = score >= 74
        ? 'Top-Kandidat'
        : score >= 64
        ? 'Solide Analyse'
        : 'Beobachten';
    final oddsText = hasOdds ? 'Quote vorhanden' : 'ohne echte Quote';
    return '$baseReason · KickMind Score $score/100: $label ($source, Liga +$leagueScore, Teams +$teamScore, Termin +$timeScore, $oddsText).';
  }

  _OddsSnapshot? _findOddsByTeams(FootballMatch match, Iterable<_OddsSnapshot> oddsList) {
    final home = _normalizeTeamName(match.homeTeam);
    final away = _normalizeTeamName(match.awayTeam);
    if (home.isEmpty || away.isEmpty) return null;

    for (final odds in oddsList) {
      final oddsHome = _normalizeTeamName(odds.homeTeam);
      final oddsAway = _normalizeTeamName(odds.awayTeam);
      if (oddsHome.isEmpty || oddsAway.isEmpty) continue;

      final sameDay = odds.kickoff.year == match.kickoff.year &&
          odds.kickoff.month == match.kickoff.month &&
          odds.kickoff.day == match.kickoff.day;
      if (!sameDay) continue;

      if (_teamsMatch(home, oddsHome) && _teamsMatch(away, oddsAway)) {
        return odds;
      }
    }

    return null;
  }

  bool _teamsMatch(String a, String b) {
    if (a == b) return true;
    if (a.length >= 5 && b.contains(a)) return true;
    if (b.length >= 5 && a.contains(b)) return true;
    return false;
  }

  String _normalizeTeamName(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'\b(fc|cf|sc|afc|fk|sk|club|deportivo|calcio|football|soccer)\b'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  FootballMatch? _buildFixtureOnlyMatch(
      Map<String, dynamic> item, {
        required DateTime fallbackDay,
      }) {
    final fixture = _asMap(item['fixture']);
    final league = _asMap(item['league']);
    final teams = _asMap(item['teams']);

    final fixtureId = int.tryParse(fixture?['id']?.toString() ?? '');
    final home = _asMap(teams?['home'])?['name']?.toString().trim() ?? '';
    final away = _asMap(teams?['away'])?['name']?.toString().trim() ?? '';
    if (fixtureId == null || home.isEmpty || away.isEmpty) return null;

    final leagueName = league?['name']?.toString().trim() ?? 'Soccer';
    final season = int.tryParse(league?['season']?.toString() ?? '') ?? fallbackDay.year;
    final kickoff = _parseApiFootballKickoff(fixture?['date'], fallbackDay: fallbackDay);

    final match = _predictionEngine.buildMatch(
      id: 'fixture_$fixtureId',
      fixtureId: fixtureId,
      season: season,
      league: leagueName,
      home: home,
      away: away,
      kickoff: kickoff,
      tipType: TipType.homeWin,
      odds: 0.0,
    );

    return _applyKickMindMatchScore(
      match,
      source: 'API-Football',
      baseReason: 'Echtes Spiel aus API-Football. Für dieses Spiel wurde aktuell keine passende Betano/Bet365/Betbat/Homebet-Quote gefunden – deshalb kein echter Wett-Tipp.',
    );
  }

  Future<List<_OddsSnapshot>> _fetchAcceptedOddsForDay(DateTime day) async {
    final key = _formatDate(day);
    final cached = _oddsDayCache[key];
    if (cached != null && cached.isNotEmpty) return List<_OddsSnapshot>.from(cached);

    final running = _oddsDayInFlight[key];
    if (running != null) return List<_OddsSnapshot>.from(await running);

    final future = _fetchAcceptedOddsForDayOnline(day);
    _oddsDayInFlight[key] = future;
    try {
      final result = await future;
      if (result.isNotEmpty) _oddsDayCache[key] = List<_OddsSnapshot>.from(result);
      return result;
    } finally {
      _oddsDayInFlight.remove(key);
    }
  }

  Future<List<_OddsSnapshot>> _fetchAcceptedOddsForDayOnline(DateTime day) async {
    final result = <_OddsSnapshot>[];
    final date = _formatDate(day);

    if (_isApiFootballDailyLimitBlocked()) {
      _logOnce('api_limit_skip_odds', 'API-FOOTBALL LIMIT SKIP odds: Tageslimit aktiv.');
      return <_OddsSnapshot>[];
    }

    for (var page = 1; page <= 20; page++) {
      try {
        final uri = Uri.parse('${ApiConfig.footballBaseUrl}/odds?date=$date&page=$page');

        final response = await _client.get(
          uri,
          headers: <String, String>{
            'x-apisports-key': ApiConfig.footballApiKey,
          },
        ).timeout(const Duration(seconds: 14));

        if (response.statusCode != 200) break;

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) break;
        if (_markApiFootballDailyLimitIfNeeded(decoded, context: 'odds $date page $page')) {
          break;
        }

        final rawResponse = decoded['response'];
        if (rawResponse is! List || rawResponse.isEmpty) break;

        for (final raw in rawResponse) {
          final item = _asMap(raw);
          if (item == null) continue;
          final odds = await _readOddsSnapshot(item, fallbackDay: day);
          if (odds != null) result.add(odds);
        }

        final paging = _asMap(decoded['paging']);
        final current = int.tryParse(paging?['current']?.toString() ?? '') ?? page;
        final total = int.tryParse(paging?['total']?.toString() ?? '') ?? page;
        if (current >= total) break;
      } catch (_) {
        break;
      }
    }

    // Konsole ruhig halten: erfolgreiche Odds-Day-Abrufe werden nicht jedes Mal geloggt.
    return result;
  }

  Future<_OddsSnapshot?> _readOddsSnapshot(
      Map<String, dynamic> item, {
        required DateTime fallbackDay,
      }) async {
    final fixture = _asMap(item['fixture']);
    final league = _asMap(item['league']);
    final teams = _asMap(item['teams']);
    final bookmakersRaw = item['bookmakers'];

    final fixtureId = int.tryParse(fixture?['id']?.toString() ?? '');
    if (fixtureId == null || bookmakersRaw is! List || bookmakersRaw.isEmpty) {
      return null;
    }

    final selectedBookmaker = _selectAcceptedBookmaker(bookmakersRaw);
    if (selectedBookmaker == null) return null;

    final markets = _readMarkets(selectedBookmaker);
    if (!markets.hasAnyTipMarket) return null;

    final bestTip = _selectTipFromOdds(markets);
    final bookmakerName = selectedBookmaker['name']?.toString().trim() ?? 'Bookmaker';
    final teamsFromPayload = _readTeamsFromOddsPayload(item);
    final teamsFromFixture = teamsFromPayload ?? await _fetchFixtureTeams(fixtureId.toString());
    final home = teamsFromFixture?.home.trim().isNotEmpty == true
        ? teamsFromFixture!.home.trim()
        : (_asMap(teams?['home'])?['name']?.toString().trim() ?? '');
    final away = teamsFromFixture?.away.trim().isNotEmpty == true
        ? teamsFromFixture!.away.trim()
        : (_asMap(teams?['away'])?['name']?.toString().trim() ?? '');

    return _OddsSnapshot(
      fixtureId: fixtureId,
      homeTeam: home,
      awayTeam: away,
      league: league?['name']?.toString().trim() ?? 'Soccer',
      season: int.tryParse(league?['season']?.toString() ?? '') ?? fallbackDay.year,
      kickoff: _parseApiFootballKickoff(fixture?['date'], fallbackDay: fallbackDay),
      bookmakerName: bookmakerName,
      tipType: bestTip.tipType,
      odd: bestTip.odd,
    );
  }

  _FixtureTeams? _readTeamsFromOddsPayload(Map<String, dynamic> raw) {
    final teams = _asMap(raw['teams']);
    final home = _asMap(teams?['home'])?['name']?.toString().trim();
    final away = _asMap(teams?['away'])?['name']?.toString().trim();

    if (home == null || away == null || home.isEmpty || away.isEmpty) {
      return null;
    }

    return _FixtureTeams(home: home, away: away);
  }

  Future<_FixtureTeams?> _fetchFixtureTeams(String fixtureId) async {
    final cached = _fixtureTeamsByIdCache[fixtureId];
    if (cached != null) return cached;

    if (_isApiFootballDailyLimitBlocked()) {
      return null;
    }

    try {
      final uri = Uri.parse('${ApiConfig.footballBaseUrl}/fixtures?id=$fixtureId');
      final response = await _client.get(
        uri,
        headers: <String, String>{
          'x-apisports-key': ApiConfig.footballApiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (_markApiFootballDailyLimitIfNeeded(decoded, context: 'fixture teams $fixtureId')) {
        return null;
      }

      final rawResponse = decoded['response'];
      if (rawResponse is! List || rawResponse.isEmpty) return null;

      final item = _asMap(rawResponse.first);
      final teams = _asMap(item?['teams']);
      final home = _asMap(teams?['home'])?['name']?.toString().trim();
      final away = _asMap(teams?['away'])?['name']?.toString().trim();

      if (home == null || away == null || home.isEmpty || away.isEmpty) {
        return null;
      }

      final result = _FixtureTeams(home: home, away: away);
      _fixtureTeamsByIdCache[fixtureId] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  FootballMatch _applyOddsToFixture(FootballMatch match, _OddsSnapshot odds) {
    final enriched = _predictionEngine.buildMatch(
      id: 'fixture_${odds.fixtureId}_${_normalizeBookmakerKey(odds.bookmakerName)}',
      fixtureId: odds.fixtureId,
      season: match.season,
      league: match.league,
      home: match.homeTeam,
      away: match.awayTeam,
      kickoff: match.kickoff,
      tipType: odds.tipType,
      odds: odds.odd,
    );

    return enriched.copyWith(
      hasRealOdds: true,
      realOddsBookmaker: odds.bookmakerName,
      shortReason: '${enriched.shortReason} · Echte Quote von ${odds.bookmakerName}.',
    );
  }

  FootballMatch? _buildMatchFromOddsSnapshot(_OddsSnapshot odds) {
    if (odds.homeTeam.isEmpty || odds.awayTeam.isEmpty) return null;

    final match = _predictionEngine.buildMatch(
      id: 'fixture_${odds.fixtureId}_${_normalizeBookmakerKey(odds.bookmakerName)}',
      fixtureId: odds.fixtureId,
      season: odds.season,
      league: odds.league,
      home: odds.homeTeam,
      away: odds.awayTeam,
      kickoff: odds.kickoff,
      tipType: odds.tipType,
      odds: odds.odd,
    );

    return match.copyWith(
      hasRealOdds: true,
      realOddsBookmaker: odds.bookmakerName,
      shortReason: '${match.shortReason} · Echte Quote von ${odds.bookmakerName}.',
    );
  }

  _OddsMarkets _readMarkets(Map<String, dynamic> bookmaker) {
    final betsRaw = bookmaker['bets'];
    if (betsRaw is! List) return const _OddsMarkets();

    double? home;
    double? draw;
    double? away;
    double? over25;
    double? under25;
    double? bttsYes;

    for (final betRaw in betsRaw) {
      final bet = _asMap(betRaw);
      if (bet == null) continue;

      final betName = bet['name']?.toString().toLowerCase().trim() ?? '';
      final valuesRaw = bet['values'];
      if (valuesRaw is! List) continue;

      if (_isMatchWinnerBet(betName)) {
        for (final valueRaw in valuesRaw) {
          final value = _asMap(valueRaw);
          if (value == null) continue;
          final label = value['value']?.toString().toLowerCase().trim() ?? '';
          final odd = _readOdd(value['odd']);
          if (odd == null) continue;

          if (label == 'home' || label == '1') home = odd;
          if (label == 'draw' || label == 'x') draw = odd;
          if (label == 'away' || label == '2') away = odd;
        }
      }

      if (_isGoalsBet(betName)) {
        for (final valueRaw in valuesRaw) {
          final value = _asMap(valueRaw);
          if (value == null) continue;
          final label = value['value']?.toString().toLowerCase().trim() ?? '';
          final odd = _readOdd(value['odd']);
          if (odd == null) continue;

          if (_isOver25(label)) over25 = odd;
          if (_isUnder25(label)) under25 = odd;
        }
      }

      if (_isBttsBet(betName)) {
        for (final valueRaw in valuesRaw) {
          final value = _asMap(valueRaw);
          if (value == null) continue;
          final label = value['value']?.toString().toLowerCase().trim() ?? '';
          final odd = _readOdd(value['odd']);
          if (odd == null) continue;

          if (label == 'yes' || label == 'ja') bttsYes = odd;
        }
      }
    }

    return _OddsMarkets(
      home: home,
      draw: draw,
      away: away,
      over25: over25,
      under25: under25,
      bttsYes: bttsYes,
    );
  }

  _SelectedTip _selectTipFromOdds(_OddsMarkets markets) {
    final candidates = <_SelectedTip>[];

    if (markets.home != null) {
      candidates.add(_SelectedTip(tipType: TipType.homeWin, odd: markets.home!));
    }
    if (markets.away != null) {
      candidates.add(_SelectedTip(tipType: TipType.awayWin, odd: markets.away!));
    }
    if (markets.draw != null && markets.draw! <= 4.20) {
      candidates.add(_SelectedTip(tipType: TipType.draw, odd: markets.draw!));
    }
    if (markets.over25 != null) {
      candidates.add(_SelectedTip(tipType: TipType.over25, odd: markets.over25!));
    }
    if (markets.under25 != null) {
      candidates.add(_SelectedTip(tipType: TipType.under25, odd: markets.under25!));
    }
    if (markets.bttsYes != null) {
      candidates.add(_SelectedTip(tipType: TipType.btts, odd: markets.bttsYes!));
    }

    candidates.sort((a, b) {
      final distanceA = (a.odd - 1.85).abs();
      final distanceB = (b.odd - 1.85).abs();
      return distanceA.compareTo(distanceB);
    });

    return candidates.first;
  }

  Map<String, dynamic>? _selectAcceptedBookmaker(List<dynamic> bookmakersRaw) {
    final bookmakers = bookmakersRaw
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .where((bookmaker) => bookmaker['bets'] is List)
        .toList();

    if (bookmakers.isEmpty) return null;

    // Wunsch-Bookmaker zuerst. Wichtig: Nur nehmen, wenn daraus wirklich
    // ein verwertbarer Markt gelesen werden kann. Sonst verlieren wir echte
    // Quoten, obwohl andere Bookmaker im selben API-Payload gültig sind.
    for (final accepted in _acceptedBookmakerNames) {
      for (final bookmaker in bookmakers) {
        final name = bookmaker['name']?.toString().toLowerCase().trim() ?? '';
        if (name.isEmpty || !name.contains(accepted)) continue;
        if (_readMarkets(bookmaker).hasAnyTipMarket) return bookmaker;
      }
    }

    // Fallback: kein Fake, sondern irgendein echter Bookmaker aus API-Football,
    // wenn er mindestens einen nutzbaren Markt enthält.
    for (final bookmaker in bookmakers) {
      if (_readMarkets(bookmaker).hasAnyTipMarket) return bookmaker;
    }

    return null;
  }

  List<FootballMatch> _dedupeAndSort(List<FootballMatch> matches) {
    final unique = <String, FootballMatch>{};

    for (final match in matches) {
      final key = match.fixtureId?.toString() ??
          '${match.id}_${match.homeTeam}_${match.awayTeam}_${match.kickoff.millisecondsSinceEpoch}';
      final existing = unique[key];
      if (existing == null || (!existing.hasPlayableOdds && match.hasPlayableOdds)) {
        unique[key] = match;
      }
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

  bool _isMatchWinnerBet(String name) {
    return name == 'match winner' ||
        name == '1x2' ||
        name == 'fulltime result' ||
        name.contains('match winner');
  }

  bool _isGoalsBet(String name) {
    return name == 'goals over/under' ||
        name == 'over/under' ||
        name.contains('goals over') ||
        name.contains('over/under');
  }

  bool _isBttsBet(String name) {
    return name == 'both teams score' ||
        name == 'both teams to score' ||
        name.contains('both teams');
  }

  bool _isOver25(String label) {
    return label == 'over 2.5' ||
        label == 'over 2,5' ||
        label == 'o 2.5' ||
        label.contains('over 2.5') ||
        label.contains('over 2,5');
  }

  bool _isUnder25(String label) {
    return label == 'under 2.5' ||
        label == 'under 2,5' ||
        label == 'u 2.5' ||
        label.contains('under 2.5') ||
        label.contains('under 2,5');
  }

  double? _readOdd(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw == null) return null;
    final text = raw.toString().replaceAll(',', '.').trim();
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 1.0) return null;
    return parsed;
  }

  DateTime _parseApiFootballKickoff(
      Object? rawDate, {
        required DateTime fallbackDay,
      }) {
    final text = rawDate?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      final parsed = DateTime.tryParse(text);
      if (parsed != null) return parsed.toLocal();
    }

    return DateTime(
      fallbackDay.year,
      fallbackDay.month,
      fallbackDay.day,
      12,
    );
  }

  String _normalizeBookmakerKey(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<void> _restoreApiFootballDailyLimitIfNeeded() async {
    if (_apiFootballDailyLimitLoadedFromDisk) return;
    _apiFootballDailyLimitLoadedFromDisk = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _formatDate(DateTime.now());
      final savedDateKey = prefs.getString(_apiFootballDailyLimitPrefsKey);

      if (savedDateKey == todayKey) {
        _apiFootballDailyLimitReached = true;
        _apiFootballDailyLimitDateKey = todayKey;
        _logOnce('api_limit_fast_skip_persisted', 'API-FOOTBALL LIMIT FAST SKIP persisted $todayKey');
        return;
      }

      if (savedDateKey != null && savedDateKey != todayKey) {
        await prefs.remove(_apiFootballDailyLimitPrefsKey);
      }
    } catch (_) {
      // Persistenter Limit-Cache darf den normalen Datenfluss nie blockieren.
    }
  }

  Future<void> _persistApiFootballDailyLimit(String todayKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiFootballDailyLimitPrefsKey, todayKey);
    } catch (_) {
      // Persistenter Limit-Cache ist nur Performance-Schutz.
    }
  }

  bool _isApiFootballDailyLimitBlocked() {
    if (!_apiFootballDailyLimitReached) return false;

    final todayKey = _formatDate(DateTime.now());
    if (_apiFootballDailyLimitDateKey == todayKey) return true;

    _apiFootballDailyLimitReached = false;
    _apiFootballDailyLimitDateKey = null;
    return false;
  }

  bool _markApiFootballDailyLimitIfNeeded(
      Map<String, dynamic> decoded, {
        required String context,
      }) {
    final errors = _asMap(decoded['errors']);
    if (errors == null || errors.isEmpty) return false;

    final message = errors.values.join(' ').toLowerCase();
    final isLimit = message.contains('request limit') ||
        message.contains('limit for the day') ||
        message.contains('too many requests') ||
        message.contains('quota');

    if (!isLimit) return false;

    final todayKey = _formatDate(DateTime.now());
    _apiFootballDailyLimitReached = true;
    _apiFootballDailyLimitDateKey = todayKey;
    _persistApiFootballDailyLimit(todayKey);

    _logOnce('api_limit_reached', "API-FOOTBALL DAILY LIMIT REACHED ($context): ${errors.values.join(' | ')}");
    return true;
  }

  Map<String, dynamic>? _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _EspnSoccerLeagueRef {
  const _EspnSoccerLeagueRef(this.code, this.name);

  final String code;
  final String name;
}

class _ApiLeagueRef {
  const _ApiLeagueRef(this.id);

  final int id;
}

class _FixtureTeams {
  const _FixtureTeams({
    required this.home,
    required this.away,
  });

  final String home;
  final String away;
}

class _OddsMarkets {
  const _OddsMarkets({
    this.home,
    this.draw,
    this.away,
    this.over25,
    this.under25,
    this.bttsYes,
  });

  final double? home;
  final double? draw;
  final double? away;
  final double? over25;
  final double? under25;
  final double? bttsYes;

  bool get hasAnyTipMarket =>
      home != null ||
          draw != null ||
          away != null ||
          over25 != null ||
          under25 != null ||
          bttsYes != null;
}

class _SelectedTip {
  const _SelectedTip({
    required this.tipType,
    required this.odd,
  });

  final TipType tipType;
  final double odd;
}

class _OddsSnapshot {
  const _OddsSnapshot({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.season,
    required this.kickoff,
    required this.bookmakerName,
    required this.tipType,
    required this.odd,
  });

  final int fixtureId;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final int season;
  final DateTime kickoff;
  final String bookmakerName;
  final TipType tipType;
  final double odd;
}
