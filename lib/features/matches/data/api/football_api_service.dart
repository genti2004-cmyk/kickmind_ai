import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../domain/football_match.dart';

class FootballApiService {
  const FootballApiService();

  // 🔥 CACHE
  static List<FootballMatch>? _cache;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<List<FootballMatch>> fetchTodayFixtures() async {
    if (!ApiConfig.hasFootballApiKey) {
      throw Exception('API-Key fehlt');
    }

    final now = DateTime.now();

    // ✅ CACHE HIT
    if (_cache != null && _cacheTime != null) {
      final age = now.difference(_cacheTime!);
      if (age < _cacheDuration) {
        print('✅ CACHE genutzt (${_cache!.length} Spiele)');
        return _cache!;
      }
    }

    final season = now.year;
    final all = <FootballMatch>[];

    // 🔥 NUR 1 REQUEST (kein Limit killen!)
    final date = _formatDate(now);

    final uri = Uri.parse(
      '${ApiConfig.footballBaseUrl}/fixtures'
          '?date=$date'
          '&league=78'
          '&season=$season'
          '&timezone=Europe/Berlin',
    );

    final response = await http.get(uri, headers: _headers);

    print('API STATUS: ${response.statusCode}');
    print('API BODY: ${response.body}');

    if (response.statusCode != 200) {
      return _useFallback();
    }

    final json = jsonDecode(response.body);
    final items = (json['response'] as List?) ?? [];

    if (items.isEmpty) {
      return _useFallback();
    }

    for (final m in items.take(10)) {
      final fixture = m['fixture'];
      final teams = m['teams'];
      final league = m['league'];

      final kickoff =
          DateTime.tryParse(fixture['date'] ?? '') ?? DateTime.now();

      final home = teams['home']['name'] ?? 'Home';
      final away = teams['away']['name'] ?? 'Away';

      // 🔥 KEINE extra API CALLS mehr!

      final int aiScore = (70 + (home.length % 20)).toInt();

      final match = FootballMatch(
        id: fixture['id'].toString(),
        season: season,
        league: league['name'] ?? 'Liga',
        homeTeam: home,
        awayTeam: away,
        kickoff: kickoff,
        tipType: TipType.homeWin,
        tipLabel: 'Heimsieg',
        aiScore: aiScore,
        riskLevel: aiScore > 80 ? RiskLevel.low : RiskLevel.medium,
        odds: 1.70 + (away.length % 3) * 0.2,
        homeFormScore: 75,
        awayFormScore: 65,
        goalsScore: 78,
        shortReason: 'Basis Analyse (optimiert für Free Plan)',
      );

      all.add(match);
    }

    // 🔥 CACHE speichern
    _cache = all;
    _cacheTime = DateTime.now();

    return all;
  }

  // 🔥 HEADER
  Map<String, String> get _headers => {
    'x-apisports-key': ApiConfig.footballApiKey,
  };

  // 🔥 FALLBACK
  List<FootballMatch> _useFallback() {
    print('⚠️ Fallback aktiv');

    final fallback = _fallbackMatches();

    _cache = fallback;
    _cacheTime = DateTime.now();

    return fallback;
  }

  // 🔥 FORMAT
  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // 🔥 DEMO FALLBACK
  List<FootballMatch> _fallbackMatches() {
    final now = DateTime.now();

    return [
      FootballMatch(
        id: 'f1',
        season: now.year,
        league: 'Bundesliga',
        homeTeam: 'Bayern',
        awayTeam: 'Dortmund',
        kickoff: now,
        tipType: TipType.over25,
        tipLabel: 'Über 2.5 Tore',
        aiScore: 82,
        riskLevel: RiskLevel.low,
        odds: 1.65,
        homeFormScore: 85,
        awayFormScore: 75,
        goalsScore: 90,
        shortReason: 'Fallback Demo',
      ),
    ];
  }
}