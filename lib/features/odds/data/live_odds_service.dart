import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kickmind_ai/features/odds/domain/live_odds.dart';

class LiveOddsService {
  static const String apiKey = 'DEIN_ODDS_API_KEY';

  /// The Odds API sport keys examples:
  /// soccer_epl, soccer_germany_bundesliga, soccer_spain_la_liga,
  /// soccer_italy_serie_a, soccer_france_ligue_one.
  final String sportKey;
  final String regions;
  final String markets;

  const LiveOddsService({
    this.sportKey = 'soccer_epl',
    this.regions = 'eu',
    this.markets = 'h2h,totals',
  });

  Future<List<LiveOdds>> fetchLiveOdds() async {
    if (apiKey == 'DEIN_ODDS_API_KEY') {
      return <LiveOdds>[];
    }

    final uri = Uri.https(
      'api.the-odds-api.com',
      '/v4/sports/$sportKey/odds',
      {
        'apiKey': apiKey,
        'regions': regions,
        'markets': markets,
        'oddsFormat': 'decimal',
      },
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return <LiveOdds>[];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return <LiveOdds>[];

      return decoded.map<LiveOdds?>((raw) {
        if (raw is! Map<String, dynamic>) return null;

        final bookmakers = raw['bookmakers'];
        if (bookmakers is! List || bookmakers.isEmpty) return null;

        final bookmaker = bookmakers.first as Map<String, dynamic>;
        final marketsRaw = bookmaker['markets'];
        if (marketsRaw is! List) return null;

        double? home;
        double? draw;
        double? away;
        double? over25;
        double? under25;

        for (final marketRaw in marketsRaw) {
          if (marketRaw is! Map<String, dynamic>) continue;
          final key = marketRaw['key']?.toString();
          final outcomes = marketRaw['outcomes'];
          if (outcomes is! List) continue;

          if (key == 'h2h') {
            for (final outcomeRaw in outcomes) {
              if (outcomeRaw is! Map<String, dynamic>) continue;
              final name = outcomeRaw['name']?.toString() ?? '';
              final price = (outcomeRaw['price'] as num?)?.toDouble();
              if (price == null) continue;

              if (name == raw['home_team']?.toString()) home = price;
              if (name == raw['away_team']?.toString()) away = price;
              if (name.toLowerCase() == 'draw') draw = price;
            }
          }

          if (key == 'totals') {
            for (final outcomeRaw in outcomes) {
              if (outcomeRaw is! Map<String, dynamic>) continue;
              final name = outcomeRaw['name']?.toString().toLowerCase() ?? '';
              final point = (outcomeRaw['point'] as num?)?.toDouble();
              final price = (outcomeRaw['price'] as num?)?.toDouble();
              if (point == null || price == null) continue;
              if (point == 2.5 && name == 'over') over25 = price;
              if (point == 2.5 && name == 'under') under25 = price;
            }
          }
        }

        if (home == null || draw == null || away == null) return null;

        return LiveOdds(
          matchId: raw['id']?.toString() ?? '',
          homeTeam: raw['home_team']?.toString() ?? '',
          awayTeam: raw['away_team']?.toString() ?? '',
          homeWin: home,
          draw: draw,
          awayWin: away,
          over25: over25,
          under25: under25,
          bookmaker: bookmaker['title']?.toString() ?? 'Bookmaker',
          updatedAt: DateTime.tryParse(bookmaker['last_update']?.toString() ?? '') ?? DateTime.now(),
        );
      }).whereType<LiveOdds>().toList();
    } catch (_) {
      return <LiveOdds>[];
    }
  }
}
