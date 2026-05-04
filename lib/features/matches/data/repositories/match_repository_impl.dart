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

    final fixtures = <({String league, String home, String away, int hour, int minute})>[
      (league: 'Fallback Liga', home: 'Fallback Team A', away: 'Fallback Team B', hour: 18, minute: 30),
      (league: 'Fallback Liga', home: 'Fallback City', away: 'Fallback United', hour: 20, minute: 45),
      (league: 'Fallback Liga', home: 'Fallback SV', away: 'Fallback FC', hour: 21, minute: 0),
    ];

    return fixtures.asMap().entries.map((entry) {
      final i = entry.key;
      final f = entry.value;
      final kickoff = DateTime(start.year, start.month, start.day, f.hour, f.minute)
          .add(Duration(days: i % range.durationDays));

      return _engine.buildMatch(
        id: 'fallback_${range.name}_$i',
        league: f.league,
        home: f.home,
        away: f.away,
        kickoff: kickoff,
      );
    }).toList();
  }
}
