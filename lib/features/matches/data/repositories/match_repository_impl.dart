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

    var matches = <FootballMatch>[];

    if (KickMindFeatureFlags.useRealApi) {
      try {
        matches = await _api.getFixturesForRange(
          start: start,
          days: range.durationDays,
        );
      } catch (_) {
        matches = <FootballMatch>[];
      }
    }

    if (matches.isEmpty && KickMindFeatureFlags.allowMockFallback) {
      matches = _fallbackMatches(range);
    }

    matches.sort((a, b) => a.kickoff.compareTo(b.kickoff));

    if (!KickMindFeatureFlags.useProEnrichment || matches.isEmpty) {
      return matches;
    }

    final enriched = await Future.wait(
      matches.map((match) async {
        try {
          final input = await _stats.buildInput(match);
          return _engine.buildProMatch(input);
        } catch (_) {
          return match;
        }
      }),
    );

    enriched.sort((a, b) => a.kickoff.compareTo(b.kickoff));
    return enriched;
  }

  List<FootballMatch> _fallbackMatches(MatchDateRange range) {
    final now = DateTime.now();
    final start = range.startDate(now);

    final fixtures = <_FallbackFixture>[
      const _FallbackFixture(
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
      const _FallbackFixture(
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
      const _FallbackFixture(
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
      const _FallbackFixture(
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
      const _FallbackFixture(
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
      const _FallbackFixture(
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
      const _FallbackFixture(
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
      const _FallbackFixture(
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
    ];

    final days = range.durationDays <= 0 ? 1 : range.durationDays;

    return fixtures.asMap().entries.map((entry) {
      final i = entry.key;
      final f = entry.value;
      final kickoff = DateTime(start.year, start.month, start.day, f.hour, f.minute)
          .add(Duration(days: i % days));

      return _engine.buildMatch(
        id: 'fallback_${range.name}_$i',
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
    }).toList();
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
