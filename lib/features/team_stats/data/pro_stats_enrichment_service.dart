import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_breakdown.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';
import 'package:kickmind_ai/features/predictions/domain/pro_prediction_input.dart';
import 'package:kickmind_ai/features/team_stats/data/mock_team_stats_repository.dart';

/// Zentrale Pro-Enrichment-Schicht.
///
/// Wichtig: Die echte Logik liegt jetzt in PredictionEngine.
/// Dieser Service ist nur der Adapter zwischen TeamStatsRepository und UI/Repository.
class ProStatsEnrichmentService {
  const ProStatsEnrichmentService({
    MockTeamStatsRepository statsRepository = const MockTeamStatsRepository(),
    PredictionEngine engine = const PredictionEngine(),
  })  : _statsRepository = statsRepository,
        _engine = engine;

  final MockTeamStatsRepository _statsRepository;
  final PredictionEngine _engine;

  List<FootballMatch> enrichAll(List<FootballMatch> matches) {
    return matches.map(enrich).toList();
  }

  FootballMatch enrich(FootballMatch match) {
    return _engine.buildProMatch(_statsRepository.buildInput(match));
  }

  PredictionBreakdown buildBreakdown(ProPredictionInput input) {
    return _engine.buildBreakdown(input);
  }

  PredictionBreakdown buildBreakdownForMatch(FootballMatch match) {
    return _engine.buildBreakdown(_statsRepository.buildInput(match));
  }
}
