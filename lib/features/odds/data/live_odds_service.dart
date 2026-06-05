import 'dart:convert';

import 'package:http/http.dart' as http;
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

  static const Duration _cacheDuration = Duration(minutes: 20);

  Future<List<LiveOdds>> fetchLiveOdds({bool forceRefresh = false}) async {
    final normalizedToday = _dateOnly(DateTime.now());
    final safeDays = days < 1 ? 1 : days;
    final cacheKey = '${_formatDate(normalizedToday)}_$safeDays';
    final now = DateTime.now();
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
        foundOddsDate = _formatDate(day);
        result.addAll(dayResult.odds);
        break;
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

  Future<List<LiveOdds>> _fetchOddsForDate(DateTime date) async {
    final result = await _fetchOddsForDateDetailed(date);
    return result.odds;
  }

  Future<_OddsDateFetchResult> _fetchOddsForDateDetailed(DateTime date) async {
    final uri = Uri.parse(
      '${ApiConfig.footballBaseUrl}/odds?date=${_formatDate(date)}',
    );

    try {
      final response = await _client.get(
        uri,
        headers: <String, String>{
          'x-apisports-key': ApiConfig.footballApiKey,
        },
      ).timeout(const Duration(seconds: 14));

      if (response.statusCode != 200) {
        return _OddsDateFetchResult(
          odds: const <LiveOdds>[],
          statusCode: response.statusCode,
          rawResponseCount: 0,
          message: 'HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const _OddsDateFetchResult(
          odds: <LiveOdds>[],
          statusCode: 200,
          rawResponseCount: 0,
          message: 'Antwort ist kein JSON-Objekt',
        );
      }

      final rawResponse = decoded['response'];
      if (rawResponse is! List || rawResponse.isEmpty) {
        return const _OddsDateFetchResult(
          odds: <LiveOdds>[],
          statusCode: 200,
          rawResponseCount: 0,
          message: 'response leer',
        );
      }

      final list = <LiveOdds>[];
      for (final item in rawResponse) {
        if (item is! Map<String, dynamic>) continue;
        final parsed = await _parseFixtureOdds(item);
        if (parsed != null) list.add(parsed);
      }

      final message = list.isEmpty
          ? '${rawResponse.length} Roh-Datensätze, 0 vollständige 1/X/2-Quoten'
          : '${rawResponse.length} Roh-Datensätze, ${list.length} verwendbar';

      return _OddsDateFetchResult(
        odds: list,
        statusCode: 200,
        rawResponseCount: rawResponse.length,
        message: message,
      );
    } catch (error) {
      return _OddsDateFetchResult(
        odds: const <LiveOdds>[],
        statusCode: null,
        rawResponseCount: 0,
        message: 'Fehler: ${error.runtimeType}',
      );
    }
  }

  Future<LiveOdds?> _parseFixtureOdds(Map<String, dynamic> raw) async {
    final fixture = _asMap(raw['fixture']);
    final bookmakersRaw = raw['bookmakers'];
    if (fixture == null || bookmakersRaw is! List || bookmakersRaw.isEmpty) {
      return null;
    }

    final selectedBookmaker = _selectBookmaker(bookmakersRaw);
    if (selectedBookmaker == null) return null;

    final betsRaw = selectedBookmaker['bets'];
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

    final fixtureId = fixture['id']?.toString() ?? '';
    if (fixtureId.isEmpty) return null;

    final teamsFromOdds = _readTeamsFromOddsPayload(raw);
    final teams = teamsFromOdds ?? await _fetchFixtureTeams(fixtureId);
    final homeTeam = teams?.home.trim().isNotEmpty == true ? teams!.home.trim() : 'Heimteam $fixtureId';
    final awayTeam = teams?.away.trim().isNotEmpty == true ? teams!.away.trim() : 'Auswärtsteam $fixtureId';

    return LiveOdds(
      matchId: fixtureId,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeWin: home,
      draw: draw,
      awayWin: away,
      over25: over25,
      under25: under25,
      bttsYes: bttsYes,
      bookmaker: selectedBookmaker['name']?.toString() ?? 'Bookmaker',
      updatedAt: DateTime.tryParse(raw['update']?.toString() ?? '') ?? DateTime.now(),
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

  Map<String, dynamic>? _selectBookmaker(List<dynamic> bookmakersRaw) {
    final bookmakers = bookmakersRaw
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .where((bookmaker) => bookmaker['bets'] is List)
        .toList();

    if (bookmakers.isEmpty) return null;

    for (final preferred in bookmakerPriority) {
      final preferredLower = preferred.toLowerCase();
      for (final bookmaker in bookmakers) {
        final name = bookmaker['name']?.toString().toLowerCase() ?? '';
        if (name.contains(preferredLower)) return bookmaker;
      }
    }

    return bookmakers.first;
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
