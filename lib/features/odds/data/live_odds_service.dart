import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kickmind_ai/core/config/api_config.dart';
import 'package:kickmind_ai/features/odds/domain/live_odds.dart';

class LiveOddsService {
  LiveOddsService({
    http.Client? client,
    this.days = 8,
    this.bookmakerPriority = const <String>[
      'Bet365',
      'Pinnacle',
      'Unibet',
      'Betfair',
      'William Hill',
      '1xBet',
    ],
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final int days;
  final List<String> bookmakerPriority;

  LiveOddsFetchDiagnostics lastDiagnostics = LiveOddsFetchDiagnostics.initial();

  static final Map<String, List<LiveOdds>> _cache = <String, List<LiveOdds>>{};
  static final Map<String, DateTime> _cacheTime = <String, DateTime>{};
  static final Map<String, _FixtureTeams> _fixtureTeamsCache = <String, _FixtureTeams>{};
  static bool _apiFootballDailyLimitReached = false;
  static DateTime? _apiFootballDailyLimitReachedAt;
  static bool _persistedLimitLoaded = false;

  static const String _apiFootballLimitDatePrefsKey = 'kickmind_live_odds_api_football_limit_date';
  static const Duration _cacheDuration = Duration(minutes: 20);

  static const List<_LiveOddsLeagueRef> _supplementalLeagues = <_LiveOddsLeagueRef>[
    _LiveOddsLeagueRef(1),
    _LiveOddsLeagueRef(2),
    _LiveOddsLeagueRef(3),
    _LiveOddsLeagueRef(4),
    _LiveOddsLeagueRef(10),
    _LiveOddsLeagueRef(15),
    _LiveOddsLeagueRef(39),
    _LiveOddsLeagueRef(61),
    _LiveOddsLeagueRef(78),
    _LiveOddsLeagueRef(88),
    _LiveOddsLeagueRef(94),
    _LiveOddsLeagueRef(103),
    _LiveOddsLeagueRef(113),
    _LiveOddsLeagueRef(135),
    _LiveOddsLeagueRef(140),
    _LiveOddsLeagueRef(253),
  ];

  Future<List<LiveOdds>> fetchLiveOdds({bool forceRefresh = false}) async {
    final normalizedToday = _dateOnly(DateTime.now());
    final safeDays = days < 1 ? 1 : days;
    final cacheKey = 'v3_${_formatDate(normalizedToday)}_$safeDays';
    final now = DateTime.now();
    await _loadPersistedApiFootballLimit();
    final rangeEnd = normalizedToday.add(Duration(days: safeDays - 1));
    final rangeText = '${_formatDate(normalizedToday)} bis ${_formatDate(rangeEnd)}';

    if (!ApiConfig.hasFootballApiKey) {
      lastDiagnostics = LiveOddsFetchDiagnostics(
        checkedAt: now,
        checkedDateRange: rangeText,
        requestedDays: safeDays,
        checkedDatesCount: 0,
        foundOddsDate: null,
        hasApiKey: false,
        usedCache: false,
        forceRefresh: forceRefresh,
        httpStatusCode: null,
        rawResponseCount: 0,
        parsedOddsCount: 0,
        visibleOddsCount: 0,
        message: 'API-Key fehlt in ApiConfig.',
      );
      return <LiveOdds>[];
    }

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cachedAt = _cacheTime[cacheKey];
      if (cachedAt != null && now.difference(cachedAt) < _cacheDuration) {
        final cached = _cache[cacheKey]!;
        lastDiagnostics = LiveOddsFetchDiagnostics(
          checkedAt: now,
          checkedDateRange: rangeText,
          requestedDays: safeDays,
          checkedDatesCount: 0,
          foundOddsDate: null,
          hasApiKey: true,
          usedCache: true,
          forceRefresh: forceRefresh,
          httpStatusCode: 200,
          rawResponseCount: cached.length,
          parsedOddsCount: cached.length,
          visibleOddsCount: cached.length,
          message: cached.isEmpty
              ? 'Cache war leer. Refresh erzwingt neuen API-Abruf.'
              : 'Daten aus Cache geladen. Refresh erzwingt neuen API-Abruf.',
        );
        return cached;
      }
    }

    if (_shouldSkipApiFootball('live odds $rangeText')) {
      lastDiagnostics = LiveOddsFetchDiagnostics(
        checkedAt: now,
        checkedDateRange: rangeText,
        requestedDays: safeDays,
        checkedDatesCount: 0,
        foundOddsDate: null,
        hasApiKey: true,
        usedCache: false,
        forceRefresh: forceRefresh,
        httpStatusCode: 429,
        rawResponseCount: 0,
        parsedOddsCount: 0,
        visibleOddsCount: 0,
        message: 'API-Football Tageslimit erreicht. Live-Quoten-Abruf wurde übersprungen.',
      );
      return <LiveOdds>[];
    }

    var rawResponseCount = 0;
    var parsedOddsCount = 0;
    var checkedDatesCount = 0;
    int? lastStatusCode;
    String? foundOddsDate;
    final notes = <String>[];
    final result = <LiveOdds>[];

    for (var offset = 0; offset < safeDays; offset++) {
      final day = normalizedToday.add(Duration(days: offset));
      checkedDatesCount++;
      final dayResult = await _fetchOddsForDateDetailed(day);
      rawResponseCount += dayResult.rawResponseCount;
      parsedOddsCount += dayResult.odds.length;
      lastStatusCode = dayResult.statusCode ?? lastStatusCode;

      if (dayResult.message.trim().isNotEmpty) {
        notes.add('${_formatDate(day)}: ${dayResult.message}');
      }

      if (dayResult.odds.isNotEmpty) {
        foundOddsDate ??= _formatDate(day);
        result.addAll(dayResult.odds);
      }
    }

    if (result.isEmpty) {
      final supplemental = await _fetchOddsForRangeByLeagues(
        start: normalizedToday,
        days: safeDays,
      );
      if (supplemental.isNotEmpty) {
        foundOddsDate ??= _formatDate(normalizedToday);
        parsedOddsCount += supplemental.length;
        result.addAll(supplemental);
        notes.add('League/Season-Fallback: ${supplemental.length} echte Quoten');
      }
    }

    final unique = <String, LiveOdds>{};
    for (final odds in result) {
      if (odds.matchId.isEmpty) continue;
      unique[odds.matchId] = odds;
    }

    final sorted = unique.values.toList()
      ..sort((a, b) {
        final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
        if (updatedCompare != 0) return updatedCompare;
        return '${a.homeTeam} ${a.awayTeam}'.compareTo('${b.homeTeam} ${b.awayTeam}');
      });

    if (sorted.isNotEmpty) {
      _cache[cacheKey] = sorted;
      _cacheTime[cacheKey] = DateTime.now();
    } else {
      _cache.remove(cacheKey);
      _cacheTime.remove(cacheKey);
    }

    final message = _buildDiagnosticsMessage(
      statusCode: lastStatusCode,
      rawResponseCount: rawResponseCount,
      parsedOddsCount: parsedOddsCount,
      visibleOddsCount: sorted.length,
      foundOddsDate: foundOddsDate,
      checkedDatesCount: checkedDatesCount,
      notes: notes,
    );

    lastDiagnostics = LiveOddsFetchDiagnostics(
      checkedAt: DateTime.now(),
      checkedDateRange: rangeText,
      requestedDays: safeDays,
      hasApiKey: true,
      checkedDatesCount: checkedDatesCount,
      foundOddsDate: foundOddsDate,
      usedCache: false,
      forceRefresh: forceRefresh,
      httpStatusCode: lastStatusCode,
      rawResponseCount: rawResponseCount,
      parsedOddsCount: parsedOddsCount,
      visibleOddsCount: sorted.length,
      message: message,
    );

    return sorted;
  }


  Future<List<LiveOdds>> fetchLiveOddsForRange({
    required DateTime start,
    required int days,
    bool forceRefresh = false,
  }) async {
    final normalizedStart = _dateOnly(start);
    final safeDays = days.clamp(1, 8).toInt();
    final rangeEnd = normalizedStart.add(Duration(days: safeDays - 1));
    final rangeText = '${_formatDate(normalizedStart)} bis ${_formatDate(rangeEnd)}';
    final cacheKey = 'range_v3_${_formatDate(normalizedStart)}_$safeDays';
    final now = DateTime.now();
    await _loadPersistedApiFootballLimit();

    if (!ApiConfig.hasFootballApiKey) {
      lastDiagnostics = LiveOddsFetchDiagnostics(
        checkedAt: now,
        checkedDateRange: rangeText,
        requestedDays: safeDays,
        checkedDatesCount: 0,
        foundOddsDate: null,
        hasApiKey: false,
        usedCache: false,
        forceRefresh: forceRefresh,
        httpStatusCode: null,
        rawResponseCount: 0,
        parsedOddsCount: 0,
        visibleOddsCount: 0,
        message: 'API-Key fehlt in ApiConfig.',
      );
      return <LiveOdds>[];
    }

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cachedAt = _cacheTime[cacheKey];
      final cached = _cache[cacheKey];
      if (cachedAt != null &&
          cached != null &&
          cached.isNotEmpty &&
          now.difference(cachedAt) < _cacheDuration) {
        lastDiagnostics = LiveOddsFetchDiagnostics(
          checkedAt: now,
          checkedDateRange: rangeText,
          requestedDays: safeDays,
          checkedDatesCount: 0,
          foundOddsDate: null,
          hasApiKey: true,
          usedCache: true,
          forceRefresh: forceRefresh,
          httpStatusCode: 200,
          rawResponseCount: cached.length,
          parsedOddsCount: cached.length,
          visibleOddsCount: cached.length,
          message: 'Top-Tips-Quoten aus Cache geladen.',
        );
        return List<LiveOdds>.from(cached);
      }
    }

    if (_shouldSkipApiFootball('live odds range $rangeText')) {
      lastDiagnostics = LiveOddsFetchDiagnostics(
        checkedAt: now,
        checkedDateRange: rangeText,
        requestedDays: safeDays,
        checkedDatesCount: 0,
        foundOddsDate: null,
        hasApiKey: true,
        usedCache: false,
        forceRefresh: forceRefresh,
        httpStatusCode: 429,
        rawResponseCount: 0,
        parsedOddsCount: 0,
        visibleOddsCount: 0,
        message: 'API-Football Tageslimit erreicht. Top-Tips-Quoten-Abruf wurde übersprungen.',
      );
      return <LiveOdds>[];
    }

    var rawResponseCount = 0;
    var parsedOddsCount = 0;
    var checkedDatesCount = 0;
    int? lastStatusCode;
    String? firstOddsDate;
    final notes = <String>[];
    final result = <LiveOdds>[];

    for (var offset = 0; offset < safeDays; offset++) {
      final day = normalizedStart.add(Duration(days: offset));
      checkedDatesCount++;
      final dayResult = await _fetchOddsForDateDetailed(day);
      rawResponseCount += dayResult.rawResponseCount;
      parsedOddsCount += dayResult.odds.length;
      lastStatusCode = dayResult.statusCode ?? lastStatusCode;

      if (dayResult.message.trim().isNotEmpty) {
        notes.add('${_formatDate(day)}: ${dayResult.message}');
      }

      if (dayResult.odds.isNotEmpty) {
        firstOddsDate ??= _formatDate(day);
        result.addAll(dayResult.odds);
      }
    }

    if (result.isEmpty) {
      final supplemental = await _fetchOddsForRangeByLeagues(
        start: normalizedStart,
        days: safeDays,
      );
      if (supplemental.isNotEmpty) {
        firstOddsDate ??= _formatDate(normalizedStart);
        parsedOddsCount += supplemental.length;
        result.addAll(supplemental);
        notes.add('League/Season-Fallback: ${supplemental.length} echte Quoten');
      }
    }

    final unique = <String, LiveOdds>{};
    for (final odds in result) {
      final key = odds.matchId.trim().isEmpty
          ? '${odds.homeTeam}_${odds.awayTeam}_${odds.bookmaker}'
          : odds.matchId.trim();
      unique[key] = odds;
    }

    final sorted = unique.values.toList()
      ..sort((a, b) {
        final nameCompare = '${a.homeTeam} ${a.awayTeam}'.compareTo('${b.homeTeam} ${b.awayTeam}');
        if (nameCompare != 0) return nameCompare;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    if (sorted.isNotEmpty) {
      _cache[cacheKey] = List<LiveOdds>.from(sorted);
      _cacheTime[cacheKey] = DateTime.now();
    } else {
      _cache.remove(cacheKey);
      _cacheTime.remove(cacheKey);
    }

    lastDiagnostics = LiveOddsFetchDiagnostics(
      checkedAt: DateTime.now(),
      checkedDateRange: rangeText,
      requestedDays: safeDays,
      checkedDatesCount: checkedDatesCount,
      foundOddsDate: firstOddsDate,
      hasApiKey: true,
      usedCache: false,
      forceRefresh: forceRefresh,
      httpStatusCode: lastStatusCode,
      rawResponseCount: rawResponseCount,
      parsedOddsCount: parsedOddsCount,
      visibleOddsCount: sorted.length,
      message: _buildDiagnosticsMessage(
        statusCode: lastStatusCode,
        rawResponseCount: rawResponseCount,
        parsedOddsCount: parsedOddsCount,
        visibleOddsCount: sorted.length,
        foundOddsDate: firstOddsDate,
        checkedDatesCount: checkedDatesCount,
        notes: notes,
      ),
    );

    return sorted;
  }

  String _buildDiagnosticsMessage({
    required int? statusCode,
    required int rawResponseCount,
    required int parsedOddsCount,
    required int visibleOddsCount,
    required String? foundOddsDate,
    required int checkedDatesCount,
    required List<String> notes,
  }) {
    if (statusCode == null) {
      return notes.isEmpty
          ? 'Keine Antwort von API-Football erhalten.'
          : notes.take(2).join(' · ');
    }

    if (statusCode != 200) {
      return 'API-Football antwortet mit Status $statusCode. Das kann Limit, Plan-Rechte oder temporäre Ablehnung bedeuten.';
    }

    if (rawResponseCount == 0) {
      return 'API-Football hat Status 200 geliefert, aber im geprüften Zeitraum keine Odds-Rohdaten gefunden.';
    }

    if (parsedOddsCount == 0) {
      return 'API-Football hat $rawResponseCount Roh-Datensätze geliefert, aber keine vollständigen 1/X/2-Quoten für die App.';
    }

    if (visibleOddsCount == 0) {
      return 'Quoten wurden geladen, aber nach Bereinigung/Dedupe ist keine sichtbare Karte übrig geblieben.';
    }

    if (foundOddsDate != null) {
      return 'API-Abruf erfolgreich: $visibleOddsCount sichtbare Spiele gefunden für $foundOddsDate nach $checkedDatesCount geprüften Tag(en).';
    }

    return 'API-Abruf erfolgreich: $visibleOddsCount sichtbare Spiele.';
  }

  Future<_OddsDateFetchResult> _fetchOddsForDateDetailed(DateTime date) async {
    if (_shouldSkipApiFootball('odds ${_formatDate(date)}')) {
      return const _OddsDateFetchResult(
        odds: <LiveOdds>[],
        statusCode: 429,
        rawResponseCount: 0,
        message: 'API-Football Tageslimit erreicht – Abruf übersprungen.',
      );
    }

    final list = <LiveOdds>[];
    var rawResponseCount = 0;
    int? lastStatusCode;
    final messages = <String>[];

    for (var page = 1; page <= 20; page++) {
      final uri = Uri.parse(
        '${ApiConfig.footballBaseUrl}/odds?date=${_formatDate(date)}&page=$page',
      );

      try {
        final response = await _client.get(
          uri,
          headers: <String, String>{
            'x-apisports-key': ApiConfig.footballApiKey,
          },
        ).timeout(const Duration(seconds: 14));

        lastStatusCode = response.statusCode;
        if (response.statusCode != 200) {
          messages.add('HTTP ${response.statusCode} auf Seite $page');
          break;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          messages.add('Seite $page: Antwort ist kein JSON-Objekt');
          break;
        }

        if (_hasApiFootballDailyLimitError(decoded)) {
          _markApiFootballDailyLimitReached('live odds ${_formatDate(date)} Seite $page');
          return _OddsDateFetchResult(
            odds: const <LiveOdds>[],
            statusCode: response.statusCode,
            rawResponseCount: rawResponseCount,
            message: 'API-Football Tageslimit erreicht – weitere Live-Quoten-Abrufe gestoppt.',
          );
        }

        final rawResponse = decoded['response'];
        if (rawResponse is! List || rawResponse.isEmpty) {
          if (page == 1) messages.add('response leer');
          break;
        }

        rawResponseCount += rawResponse.length;
        var parsedOnPage = 0;
        for (final item in rawResponse) {
          final map = _asMap(item);
          if (map == null) continue;
          final parsed = await _parseFixtureOdds(map);
          if (parsed != null) {
            list.add(parsed);
            parsedOnPage++;
          }
        }

        messages.add('Seite $page: ${rawResponse.length} roh, $parsedOnPage verwendbar');

        final paging = _asMap(decoded['paging']);
        final current = int.tryParse(paging?['current']?.toString() ?? '') ?? page;
        final total = int.tryParse(paging?['total']?.toString() ?? '') ?? page;
        if (current >= total) break;
      } catch (error) {
        messages.add('Seite $page Fehler: ${error.runtimeType}');
        break;
      }
    }

    final message = list.isEmpty
        ? (messages.isEmpty ? '0 Roh-Datensätze' : messages.take(3).join(' · '))
        : '${rawResponseCount} Roh-Datensätze, ${list.length} verwendbar (${messages.take(3).join(' · ')})';

    // ignore: avoid_print
    print('LIVE ODDS ${_formatDate(date)}: $message');

    return _OddsDateFetchResult(
      odds: list,
      statusCode: lastStatusCode,
      rawResponseCount: rawResponseCount,
      message: message,
    );
  }

  Future<List<LiveOdds>> _fetchOddsForRangeByLeagues({
    required DateTime start,
    required int days,
  }) async {
    final fromText = _formatDate(start);
    final toText = _formatDate(start.add(Duration(days: days - 1)));

    if (_shouldSkipApiFootball('odds league supplement $fromText-$toText')) {
      // ignore: avoid_print
      print('LIVE ODDS LEAGUE SUPPLEMENT $fromText-$toText: 0 (API-Football Tageslimit)');
      return <LiveOdds>[];
    }

    final result = <LiveOdds>[];
    final seasons = _seasonCandidates(start);

    for (final league in _supplementalLeagues) {
      for (final season in seasons) {
        if (result.length >= 80) break;

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

            if (_hasApiFootballDailyLimitError(decoded)) {
              _markApiFootballDailyLimitReached('live odds league supplement $fromText-$toText');
              final unique = <String, LiveOdds>{};
              for (final odds in result) {
                unique[odds.matchId] = odds;
              }
              final sorted = unique.values.toList()
                ..sort((a, b) => '${a.homeTeam} ${a.awayTeam}'.compareTo('${b.homeTeam} ${b.awayTeam}'));
              // ignore: avoid_print
              print('LIVE ODDS LEAGUE SUPPLEMENT $fromText-$toText: ${sorted.length} (API-Football Tageslimit)');
              return sorted;
            }

            final rawResponse = decoded['response'];
            if (rawResponse is! List || rawResponse.isEmpty) break;

            for (final raw in rawResponse) {
              final map = _asMap(raw);
              if (map == null) continue;
              final parsed = await _parseFixtureOdds(map);
              if (parsed != null) {
                result.add(parsed);
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

    final unique = <String, LiveOdds>{};
    for (final odds in result) {
      unique[odds.matchId] = odds;
    }

    final sorted = unique.values.toList()
      ..sort((a, b) => '${a.homeTeam} ${a.awayTeam}'.compareTo('${b.homeTeam} ${b.awayTeam}'));
    // ignore: avoid_print
    print('LIVE ODDS LEAGUE SUPPLEMENT $fromText-$toText: ${sorted.length}');
    return sorted;
  }


  List<int> _seasonCandidates(DateTime start) {
    final seasons = <int>{start.year, start.year - 1};
    if (start.month >= 7) seasons.add(start.year + 1);
    return seasons.toList()..sort((a, b) => b.compareTo(a));
  }

  Future<LiveOdds?> _parseFixtureOdds(Map<String, dynamic> raw) async {
    final fixture = _asMap(raw['fixture']);
    final bookmakersRaw = raw['bookmakers'];
    if (fixture == null || bookmakersRaw is! List || bookmakersRaw.isEmpty) {
      return null;
    }

    final bookmakers = _orderedBookmakers(bookmakersRaw);
    if (bookmakers.isEmpty) return null;

    final fixtureId = fixture['id']?.toString() ?? '';
    if (fixtureId.isEmpty) return null;

    final teamsFromOdds = _readTeamsFromOddsPayload(raw);
    final teams = teamsFromOdds ?? await _fetchFixtureTeams(fixtureId);
    final homeTeam = teams?.home.trim().isNotEmpty == true ? teams!.home.trim() : 'Heimteam $fixtureId';
    final awayTeam = teams?.away.trim().isNotEmpty == true ? teams!.away.trim() : 'Auswärtsteam $fixtureId';

    for (final selectedBookmaker in bookmakers) {
      final parsed = _parseMarketsForBookmaker(selectedBookmaker);
      if (parsed == null) continue;

      return LiveOdds(
        matchId: fixtureId,
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        homeWin: parsed.home,
        draw: parsed.draw,
        awayWin: parsed.away,
        over25: parsed.over25,
        under25: parsed.under25,
        bttsYes: parsed.bttsYes,
        bookmaker: selectedBookmaker['name']?.toString() ?? 'Bookmaker',
        updatedAt: DateTime.tryParse(raw['update']?.toString() ?? '') ?? DateTime.now(),
      );
    }

    return null;
  }

  List<Map<String, dynamic>> _orderedBookmakers(List<dynamic> bookmakersRaw) {
    final bookmakers = bookmakersRaw
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .where((bookmaker) => bookmaker['bets'] is List)
        .toList();

    if (bookmakers.isEmpty) return <Map<String, dynamic>>[];

    final ordered = <Map<String, dynamic>>[];
    for (final preferred in bookmakerPriority) {
      final preferredLower = preferred.toLowerCase();
      for (final bookmaker in bookmakers) {
        final name = bookmaker['name']?.toString().toLowerCase() ?? '';
        if (name.contains(preferredLower) && !ordered.contains(bookmaker)) {
          ordered.add(bookmaker);
        }
      }
    }

    for (final bookmaker in bookmakers) {
      if (!ordered.contains(bookmaker)) ordered.add(bookmaker);
    }

    return ordered;
  }

  _ParsedLiveMarkets? _parseMarketsForBookmaker(Map<String, dynamic> bookmaker) {
    final betsRaw = bookmaker['bets'];
    if (betsRaw is! List) return null;

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

    if (home == null || draw == null || away == null) return null;

    return _ParsedLiveMarkets(
      home: home,
      draw: draw,
      away: away,
      over25: over25,
      under25: under25,
      bttsYes: bttsYes,
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
    final cached = _fixtureTeamsCache[fixtureId];
    if (cached != null) return cached;

    if (_shouldSkipApiFootball('fixture teams $fixtureId')) return null;

    final uri = Uri.parse('${ApiConfig.footballBaseUrl}/fixtures?id=$fixtureId');

    try {
      final response = await _client.get(
        uri,
        headers: <String, String>{
          'x-apisports-key': ApiConfig.footballApiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      if (_hasApiFootballDailyLimitError(decoded)) {
        _markApiFootballDailyLimitReached('fixture teams $fixtureId');
        return null;
      }

      final rawResponse = decoded['response'];
      if (rawResponse is! List || rawResponse.isEmpty) return null;

      final first = _asMap(rawResponse.first);
      final teams = _asMap(first?['teams']);
      final home = _asMap(teams?['home'])?['name']?.toString().trim();
      final away = _asMap(teams?['away'])?['name']?.toString().trim();

      if (home == null || away == null || home.isEmpty || away.isEmpty) {
        return null;
      }

      final fixtureTeams = _FixtureTeams(home: home, away: away);
      _fixtureTeamsCache[fixtureId] = fixtureTeams;
      return fixtureTeams;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPersistedApiFootballLimit() async {
    if (_persistedLimitLoaded) return;
    _persistedLimitLoaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString(_apiFootballLimitDatePrefsKey);
      final today = _formatDate(DateTime.now());

      if (savedDate == today) {
        _apiFootballDailyLimitReached = true;
        _apiFootballDailyLimitReachedAt = DateTime.now();
        // ignore: avoid_print
        print('API-FOOTBALL LIMIT FAST SKIP live odds persisted $today');
      } else if (savedDate != null && savedDate.isNotEmpty) {
        await prefs.remove(_apiFootballLimitDatePrefsKey);
      }
    } catch (_) {
      // Persistenz darf Live-Odds nie blockieren.
    }
  }

  bool _shouldSkipApiFootball(String context) {
    if (!_apiFootballDailyLimitReached) return false;

    final reachedAt = _apiFootballDailyLimitReachedAt;
    if (reachedAt == null || !_isSameDate(reachedAt, DateTime.now())) {
      _apiFootballDailyLimitReached = false;
      _apiFootballDailyLimitReachedAt = null;
      return false;
    }

    // ignore: avoid_print
    print('API-FOOTBALL LIMIT SKIP live odds $context');
    return true;
  }

  void _markApiFootballDailyLimitReached(String context) {
    _apiFootballDailyLimitReached = true;
    _apiFootballDailyLimitReachedAt = DateTime.now();

    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_apiFootballLimitDatePrefsKey, _formatDate(DateTime.now())))
        .catchError((_) => false);

    // ignore: avoid_print
    print('API-FOOTBALL DAILY LIMIT REACHED live odds ($context)');
  }

  bool _hasApiFootballDailyLimitError(Map<String, dynamic> decoded) {
    final errors = decoded['errors'];
    if (errors == null) return false;

    final text = errors.toString().toLowerCase();
    return text.contains('request limit') ||
        text.contains('reached the request limit') ||
        text.contains('daily limit') ||
        text.contains('rate limit');
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  Map<String, dynamic>? _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class _LiveOddsLeagueRef {
  const _LiveOddsLeagueRef(this.id);

  final int id;
}

class LiveOddsFetchDiagnostics {
  const LiveOddsFetchDiagnostics({
    required this.checkedAt,
    required this.checkedDateRange,
    required this.requestedDays,
    required this.checkedDatesCount,
    required this.foundOddsDate,
    required this.hasApiKey,
    required this.usedCache,
    required this.forceRefresh,
    required this.httpStatusCode,
    required this.rawResponseCount,
    required this.parsedOddsCount,
    required this.visibleOddsCount,
    required this.message,
  });

  factory LiveOddsFetchDiagnostics.initial() {
    return LiveOddsFetchDiagnostics(
      checkedAt: DateTime.fromMillisecondsSinceEpoch(0),
      checkedDateRange: '-',
      requestedDays: 0,
      checkedDatesCount: 0,
      foundOddsDate: null,
      hasApiKey: false,
      usedCache: false,
      forceRefresh: false,
      httpStatusCode: null,
      rawResponseCount: 0,
      parsedOddsCount: 0,
      visibleOddsCount: 0,
      message: 'Noch kein API-Abruf durchgeführt.',
    );
  }

  final DateTime checkedAt;
  final String checkedDateRange;
  final int requestedDays;
  final int checkedDatesCount;
  final String? foundOddsDate;
  final bool hasApiKey;
  final bool usedCache;
  final bool forceRefresh;
  final int? httpStatusCode;
  final int rawResponseCount;
  final int parsedOddsCount;
  final int visibleOddsCount;
  final String message;

  String get checkedAtText {
    final hour = checkedAt.hour.toString().padLeft(2, '0');
    final minute = checkedAt.minute.toString().padLeft(2, '0');
    final second = checkedAt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

class _ParsedLiveMarkets {
  const _ParsedLiveMarkets({
    required this.home,
    required this.draw,
    required this.away,
    this.over25,
    this.under25,
    this.bttsYes,
  });

  final double home;
  final double draw;
  final double away;
  final double? over25;
  final double? under25;
  final double? bttsYes;
}

class _OddsDateFetchResult {
  const _OddsDateFetchResult({
    required this.odds,
    required this.statusCode,
    required this.rawResponseCount,
    required this.message,
  });

  final List<LiveOdds> odds;
  final int? statusCode;
  final int rawResponseCount;
  final String message;
}

class _FixtureTeams {
  const _FixtureTeams({
    required this.home,
    required this.away,
  });

  final String home;
  final String away;
}

