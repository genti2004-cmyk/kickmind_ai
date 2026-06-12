import 'package:kickmind_ai/core/config/kickmind_feature_flags.dart';
import 'package:kickmind_ai/features/matches/data/sources/football_api_data_source.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/domain/match_repository.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';
import 'package:kickmind_ai/features/team_stats/data/team_stats_service.dart';

class MatchRepositoryImpl implements MatchRepository {
  final FootballApiDataSource _api;
  final PredictionEngine _engine;
  final TeamStatsService _stats;

  MatchRepositoryImpl({
    FootballApiDataSource? api,
    PredictionEngine? engine,
    TeamStatsService? stats,
  })  : _api = api ?? FootballApiDataSource(),
        _engine = engine ?? const PredictionEngine(),
        _stats = stats ?? TeamStatsService();

  @override
  Future<List<FootballMatch>> getTodayMatches() {
    return getMatches(range: MatchDateRange.today);
  }

  @override
  Future<List<FootballMatch>> getMatches({
    MatchDateRange range = MatchDateRange.today,
  }) async {
    final now = DateTime.now();
    final start = range.startDate(now);
    final days = _safeDurationDays(range);

    var matches = <FootballMatch>[];

    if (KickMindFeatureFlags.useRealApi) {
      try {
        matches = await _api.getFixturesForRange(
          start: start,
          days: days,
        );
      } catch (_) {
        matches = <FootballMatch>[];
      }
    }

    matches = _sanitizeMatches(matches, start: start, days: days);

    if (matches.isEmpty && KickMindFeatureFlags.allowMockFallback) {
      matches = _fallbackMatches(range);
    }

    matches.sort((a, b) => a.kickoff.compareTo(b.kickoff));

    if (!KickMindFeatureFlags.useProEnrichment || matches.isEmpty) {
      return matches;
    }

    // SofaScore-Logik: Spielplan zuerst stabil anzeigen. Pro-Enrichment darf
    // nicht hunderte Fixture-Only-Spiele blockieren oder bei API-Limits leer wirken lassen.
    final playableIds = matches.where((m) => m.hasPlayableOdds).map((m) => m.id).toSet();
    if (playableIds.isEmpty) {
      return matches;
    }

    final enriched = await Future.wait(
      matches.map((match) async {
        if (!playableIds.contains(match.id)) {
          return match.copyWith(
            riskLevel: 'Kein Tipp',
            odds: 0.0,
            hasRealOdds: false,
            realOddsBookmaker: null,
            shortReason: match.shortReason,
          );
        }

        try {
          final input = await _stats.buildInput(match);
          final proMatch = _engine.buildProMatch(input);

          // Pro-Enrichment darf Score/Form verbessern, aber nicht den echten
          // Bookmaker-Markt und die echte Quote überschreiben.
          return proMatch.copyWith(
            tipType: match.tipType,
            tipLabel: match.tipLabel,
            odds: match.odds,
            hasRealOdds: match.hasRealOdds,
            realOddsBookmaker: match.realOddsBookmaker,
            shortReason: _mergeReasons(
              proReason: proMatch.shortReason,
              bookmakerReason: match.shortReason,
            ),
          );
        } catch (_) {
          return match;
        }
      }),
    );

    enriched.sort((a, b) => a.kickoff.compareTo(b.kickoff));
    return enriched;
  }


  String _mergeReasons({
    required String proReason,
    required String bookmakerReason,
  }) {
    final marker = 'Quote von ';
    final markerIndex = bookmakerReason.indexOf(marker);
    if (markerIndex < 0) return proReason;

    final bookmakerPart = bookmakerReason.substring(markerIndex).trim();
    if (bookmakerPart.isEmpty) return proReason;
    return '$proReason · $bookmakerPart';
  }

  int _safeDurationDays(MatchDateRange range) {
    final raw = range.durationDays;
    if (raw < 1) return 1;
    if (raw > 7) return 7;
    return raw;
  }

  List<FootballMatch> _sanitizeMatches(
      List<FootballMatch> matches, {
        required DateTime start,
        required int days,
      }) {
    if (matches.isEmpty) return <FootballMatch>[];

    final from = DateTime(start.year, start.month, start.day);
    final to = from.add(Duration(days: days));
    final unique = <String, FootballMatch>{};

    for (final match in matches) {
      if (match.homeTeam.trim().isEmpty || match.awayTeam.trim().isEmpty) {
        continue;
      }
      if (match.kickoff.isBefore(from) || !match.kickoff.isBefore(to)) {
        continue;
      }

      final key = '${match.fixtureId ?? match.id}_${match.homeTeam}_${match.awayTeam}_${match.kickoff.millisecondsSinceEpoch}';
      unique[key] = match;
    }

    final result = unique.values.toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    return result;
  }

  List<FootballMatch> _fallbackMatches(MatchDateRange range) {
    final now = DateTime.now();
    final start = range.startDate(now);
    final days = _safeDurationDays(range);
    final normalizedStart = DateTime(start.year, start.month, start.day);

    final maxCount = _fallbackCountForRange(range, days);
    final seed = normalizedStart.difference(DateTime(2024)).inDays.abs();
    final rotated = <_FallbackFixture>[
      for (var i = 0; i < _fallbackCatalog.length; i++)
        _fallbackCatalog[(seed + i) % _fallbackCatalog.length],
    ];

    final selected = rotated.take(maxCount).toList();

    return selected.asMap().entries.map((entry) {
      final i = entry.key;
      final f = entry.value;

      final dayOffset = i % days;
      final day = normalizedStart.add(Duration(days: dayOffset));
      final kickoff = DateTime(day.year, day.month, day.day, f.hour, f.minute);

      return _engine.buildMatch(
        id: 'fallback_${range.name}_${_formatDate(day)}_${i}_${f.home}_${f.away}',
        league: f.league,
        home: f.home,
        away: f.away,
        kickoff: kickoff,
        tipType: f.tipType,
        odds: f.odds,
        homeFormScore: f.homeFormScore,
        awayFormScore: f.awayFormScore,
        goalsScore: f.goalsScore,
      );
    }).toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
  }

  int _fallbackCountForRange(MatchDateRange range, int days) {
    switch (range.name) {
      case 'today':
        return 10;
      case 'tomorrow':
        return 10;
      case 'next3Days':
      case 'next3days':
      case 'threeDays':
        return 21;
      case 'week':
      case 'nextWeek':
        return 35;
      default:
        return (days * 7).clamp(8, 35);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _FallbackFixture {
  final String league;
  final String home;
  final String away;
  final int hour;
  final int minute;
  final TipType tipType;
  final double odds;
  final int homeFormScore;
  final int awayFormScore;
  final int goalsScore;

  const _FallbackFixture({
    required this.league,
    required this.home,
    required this.away,
    required this.hour,
    required this.minute,
    required this.tipType,
    required this.odds,
    required this.homeFormScore,
    required this.awayFormScore,
    required this.goalsScore,
  });
}

const List<_FallbackFixture> _fallbackCatalog = <_FallbackFixture>[
  _FallbackFixture(
    league: 'Premier League',
    home: 'Manchester City',
    away: 'Newcastle United',
    hour: 18,
    minute: 30,
    tipType: TipType.homeWin,
    odds: 1.62,
    homeFormScore: 88,
    awayFormScore: 68,
    goalsScore: 82,
  ),
  _FallbackFixture(
    league: 'Premier League',
    home: 'Arsenal',
    away: 'Brighton',
    hour: 16,
    minute: 0,
    tipType: TipType.homeWin,
    odds: 1.78,
    homeFormScore: 84,
    awayFormScore: 72,
    goalsScore: 80,
  ),
  _FallbackFixture(
    league: 'Premier League',
    home: 'Tottenham',
    away: 'Aston Villa',
    hour: 17,
    minute: 30,
    tipType: TipType.btts,
    odds: 1.72,
    homeFormScore: 76,
    awayFormScore: 75,
    goalsScore: 84,
  ),
  _FallbackFixture(
    league: 'Bundesliga',
    home: 'Bayern München',
    away: 'Eintracht Frankfurt',
    hour: 20,
    minute: 30,
    tipType: TipType.over25,
    odds: 1.74,
    homeFormScore: 84,
    awayFormScore: 71,
    goalsScore: 91,
  ),
  _FallbackFixture(
    league: 'Bundesliga',
    home: 'Borussia Dortmund',
    away: 'VfB Stuttgart',
    hour: 18,
    minute: 30,
    tipType: TipType.btts,
    odds: 1.68,
    homeFormScore: 78,
    awayFormScore: 79,
    goalsScore: 88,
  ),
  _FallbackFixture(
    league: 'Bundesliga',
    home: 'RB Leipzig',
    away: 'Mainz 05',
    hour: 15,
    minute: 30,
    tipType: TipType.homeWin,
    odds: 1.71,
    homeFormScore: 82,
    awayFormScore: 66,
    goalsScore: 76,
  ),
  _FallbackFixture(
    league: 'La Liga',
    home: 'Real Madrid',
    away: 'Valencia',
    hour: 21,
    minute: 0,
    tipType: TipType.homeWin,
    odds: 1.58,
    homeFormScore: 87,
    awayFormScore: 64,
    goalsScore: 76,
  ),
  _FallbackFixture(
    league: 'La Liga',
    home: 'Barcelona',
    away: 'Real Sociedad',
    hour: 20,
    minute: 45,
    tipType: TipType.homeWin,
    odds: 1.66,
    homeFormScore: 83,
    awayFormScore: 70,
    goalsScore: 79,
  ),
  _FallbackFixture(
    league: 'La Liga',
    home: 'Villarreal',
    away: 'Real Betis',
    hour: 18,
    minute: 15,
    tipType: TipType.over25,
    odds: 1.92,
    homeFormScore: 73,
    awayFormScore: 71,
    goalsScore: 81,
  ),
  _FallbackFixture(
    league: 'Serie A',
    home: 'Inter',
    away: 'Atalanta',
    hour: 20,
    minute: 45,
    tipType: TipType.btts,
    odds: 1.86,
    homeFormScore: 80,
    awayFormScore: 78,
    goalsScore: 84,
  ),
  _FallbackFixture(
    league: 'Serie A',
    home: 'Juventus',
    away: 'Bologna',
    hour: 19,
    minute: 0,
    tipType: TipType.homeWin,
    odds: 1.83,
    homeFormScore: 78,
    awayFormScore: 67,
    goalsScore: 69,
  ),
  _FallbackFixture(
    league: 'Serie A',
    home: 'Napoli',
    away: 'Fiorentina',
    hour: 20,
    minute: 45,
    tipType: TipType.over25,
    odds: 1.88,
    homeFormScore: 76,
    awayFormScore: 72,
    goalsScore: 82,
  ),
  _FallbackFixture(
    league: 'Ligue 1',
    home: 'PSG',
    away: 'Lille',
    hour: 19,
    minute: 0,
    tipType: TipType.over25,
    odds: 1.79,
    homeFormScore: 86,
    awayFormScore: 73,
    goalsScore: 88,
  ),
  _FallbackFixture(
    league: 'Ligue 1',
    home: 'Marseille',
    away: 'Rennes',
    hour: 21,
    minute: 0,
    tipType: TipType.homeWin,
    odds: 1.94,
    homeFormScore: 75,
    awayFormScore: 69,
    goalsScore: 74,
  ),
  _FallbackFixture(
    league: 'Eredivisie',
    home: 'PSV Eindhoven',
    away: 'AZ Alkmaar',
    hour: 18,
    minute: 45,
    tipType: TipType.btts,
    odds: 1.83,
    homeFormScore: 83,
    awayFormScore: 77,
    goalsScore: 86,
  ),
  _FallbackFixture(
    league: 'Eredivisie',
    home: 'Ajax',
    away: 'FC Utrecht',
    hour: 16,
    minute: 45,
    tipType: TipType.over25,
    odds: 1.70,
    homeFormScore: 74,
    awayFormScore: 70,
    goalsScore: 89,
  ),
  _FallbackFixture(
    league: 'Portugal',
    home: 'Benfica',
    away: 'Braga',
    hour: 21,
    minute: 15,
    tipType: TipType.over25,
    odds: 1.88,
    homeFormScore: 81,
    awayFormScore: 74,
    goalsScore: 83,
  ),
  _FallbackFixture(
    league: 'Portugal',
    home: 'Sporting CP',
    away: 'Vitória SC',
    hour: 20,
    minute: 0,
    tipType: TipType.homeWin,
    odds: 1.57,
    homeFormScore: 85,
    awayFormScore: 68,
    goalsScore: 78,
  ),
  _FallbackFixture(
    league: 'Championship',
    home: 'Leeds United',
    away: 'Norwich City',
    hour: 16,
    minute: 0,
    tipType: TipType.homeWin,
    odds: 1.95,
    homeFormScore: 78,
    awayFormScore: 70,
    goalsScore: 72,
  ),
  _FallbackFixture(
    league: 'Championship',
    home: 'Leicester City',
    away: 'West Brom',
    hour: 13,
    minute: 30,
    tipType: TipType.homeWin,
    odds: 1.82,
    homeFormScore: 80,
    awayFormScore: 69,
    goalsScore: 75,
  ),
  _FallbackFixture(
    league: 'Süper Lig',
    home: 'Galatasaray',
    away: 'Trabzonspor',
    hour: 18,
    minute: 0,
    tipType: TipType.homeWin,
    odds: 1.76,
    homeFormScore: 82,
    awayFormScore: 70,
    goalsScore: 79,
  ),
  _FallbackFixture(
    league: 'Süper Lig',
    home: 'Fenerbahçe',
    away: 'Beşiktaş',
    hour: 19,
    minute: 0,
    tipType: TipType.btts,
    odds: 1.80,
    homeFormScore: 81,
    awayFormScore: 76,
    goalsScore: 84,
  ),
  _FallbackFixture(
    league: 'MLS',
    home: 'Inter Miami',
    away: 'Atlanta United',
    hour: 1,
    minute: 30,
    tipType: TipType.over25,
    odds: 1.66,
    homeFormScore: 79,
    awayFormScore: 68,
    goalsScore: 90,
  ),
  _FallbackFixture(
    league: 'MLS',
    home: 'Los Angeles FC',
    away: 'Seattle Sounders',
    hour: 4,
    minute: 0,
    tipType: TipType.homeWin,
    odds: 1.91,
    homeFormScore: 77,
    awayFormScore: 69,
    goalsScore: 73,
  ),
  _FallbackFixture(
    league: 'Brazil Serie A',
    home: 'Flamengo',
    away: 'Fluminense',
    hour: 23,
    minute: 0,
    tipType: TipType.btts,
    odds: 1.91,
    homeFormScore: 78,
    awayFormScore: 75,
    goalsScore: 77,
  ),
  _FallbackFixture(
    league: 'Argentina Primera',
    home: 'River Plate',
    away: 'Racing Club',
    hour: 22,
    minute: 30,
    tipType: TipType.homeWin,
    odds: 1.88,
    homeFormScore: 79,
    awayFormScore: 70,
    goalsScore: 72,
  ),
];
