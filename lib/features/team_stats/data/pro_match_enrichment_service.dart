import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_breakdown.dart';
import 'package:kickmind_ai/features/predictions/domain/pro_prediction_input.dart';
import 'package:kickmind_ai/features/team_stats/data/mock_team_stats_repository.dart';

/// Sichere Pro-Schicht für Phase 3.
///
/// Nimmt vorhandene Matches und reichert sie mit transparenten Analysewerten an:
/// Form, Heim/Auswärts, Tore-Trend, H2H und Tabelle.
/// Später kann MockTeamStatsRepository ohne UI-Änderung durch echte API-Daten
/// ersetzt werden.
class ProStatsEnrichmentService {
  const ProStatsEnrichmentService({
    MockTeamStatsRepository statsRepository = const MockTeamStatsRepository(),
  }) : _statsRepository = statsRepository;

  final MockTeamStatsRepository _statsRepository;

  List<FootballMatch> enrichAll(List<FootballMatch> matches) {
    return matches.map(enrich).toList();
  }

  FootballMatch enrich(FootballMatch match) {
    final input = _statsRepository.buildInput(match);
    final breakdown = buildBreakdown(input);

    return match.copyWith(
      tipType: breakdown.tipType,
      tipLabel: breakdown.tipLabel,
      aiScore: breakdown.aiScore,
      riskLevel: breakdown.riskLevel,
      odds: breakdown.estimatedOdds,
      homeFormScore: input.homeStats.overallFormScore,
      awayFormScore: input.awayStats.overallFormScore,
      goalsScore: input.goalsTrendScore,
      shortReason: breakdown.reason,
    );
  }

  PredictionBreakdown buildBreakdown(ProPredictionInput input) {
    final formScore = _formScore(input);
    final homeAwayScore = input.homeAdvantageScore.clamp(1, 99);
    final goalsTrendScore = input.goalsTrendScore.clamp(1, 99);
    final headToHeadScore = input.headToHeadScore.clamp(1, 99);
    final tableScore = input.tableAdvantageScore.clamp(1, 99);

    final aiScore = ((formScore * 0.30) +
        (homeAwayScore * 0.20) +
        (goalsTrendScore * 0.20) +
        (headToHeadScore * 0.15) +
        (tableScore * 0.15))
        .round()
        .clamp(1, 99);

    final tipLabel = _tipLabelFor(
      input: input,
      aiScore: aiScore,
      goalsTrendScore: goalsTrendScore,
      formScore: formScore,
      tableScore: tableScore,
      headToHeadScore: headToHeadScore,
    );

    final tipType = _tipTypeFromLabel(tipLabel);
    final odds = _estimatedOdds(tipLabel);
    final risk = _riskLevel(aiScore: aiScore, odds: odds, tipLabel: tipLabel);
    final confidence = _confidence(
      aiScore: aiScore,
      riskLevel: risk,
      tipLabel: tipLabel,
    );

    return PredictionBreakdown(
      formScore: formScore,
      homeAwayScore: homeAwayScore,
      goalsTrendScore: goalsTrendScore,
      headToHeadScore: headToHeadScore,
      tableScore: tableScore,
      aiScore: aiScore,
      confidence: confidence,
      riskLevel: risk,
      tipLabel: tipLabel,
      tipType: tipType,
      estimatedOdds: odds,
      reason: _reason(
        input: input,
        tipLabel: tipLabel,
        aiScore: aiScore,
        confidence: confidence,
        riskLevel: risk,
        formScore: formScore,
        homeAwayScore: homeAwayScore,
        goalsTrendScore: goalsTrendScore,
        headToHeadScore: headToHeadScore,
        tableScore: tableScore,
      ),
    );
  }

  int _formScore(ProPredictionInput input) {
    final diff = input.homeStats.overallFormScore - input.awayStats.overallFormScore;
    if (diff.abs() <= 5) return 68;

    final stronger = diff > 0
        ? input.homeStats.overallFormScore
        : input.awayStats.overallFormScore;

    final weaker = diff > 0
        ? input.awayStats.overallFormScore
        : input.homeStats.overallFormScore;

    return ((stronger * 0.70) + ((100 - weaker) * 0.30)).round().clamp(1, 99);
  }

  String _tipLabelFor({
    required ProPredictionInput input,
    required int aiScore,
    required int goalsTrendScore,
    required int formScore,
    required int tableScore,
    required int headToHeadScore,
  }) {
    final formDiff = input.formDifference;
    final homeIsClearlyBetter = formDiff >= 14 && tableScore >= 56;
    final awayIsClearlyBetter = formDiff <= -14 && tableScore <= 44;

    if (goalsTrendScore >= 78 && aiScore >= 68) return 'Über 2.5';
    if (goalsTrendScore <= 40 && aiScore >= 64) return 'Unter 2.5';

    if (homeIsClearlyBetter && aiScore >= 74) return '1';
    if (awayIsClearlyBetter && aiScore >= 74) return '2';

    if (formDiff >= 7 && headToHeadScore >= 48) return '1X';
    if (formDiff <= -7 && headToHeadScore <= 52) return 'X2';

    if (formDiff.abs() <= 6 && aiScore >= 62) return 'X';
    if (goalsTrendScore >= 62) return 'BTTS';

    return '12';
  }

  TipType _tipTypeFromLabel(String label) {
    switch (label) {
      case '1':
      case '1X':
      case '12':
        return TipType.homeWin;
      case 'X':
        return TipType.draw;
      case '2':
      case 'X2':
        return TipType.awayWin;
      case 'Über 2.5':
        return TipType.over25;
      case 'Unter 2.5':
        return TipType.under25;
      case 'BTTS':
        return TipType.btts;
      default:
        return TipType.homeWin;
    }
  }

  double _estimatedOdds(String tipLabel) {
    switch (tipLabel) {
      case '1':
        return 1.78;
      case 'X':
        return 3.25;
      case '2':
        return 2.18;
      case '1X':
        return 1.35;
      case 'X2':
        return 1.48;
      case '12':
        return 1.28;
      case 'Über 2.5':
        return 1.85;
      case 'Unter 2.5':
        return 1.95;
      case 'BTTS':
        return 1.82;
      default:
        return 1.80;
    }
  }

  String _riskLevel({
    required int aiScore,
    required double odds,
    required String tipLabel,
  }) {
    final isSaferMarket = tipLabel == '1X' || tipLabel == 'X2' || tipLabel == '12';

    if (aiScore >= 82 && (odds <= 1.90 || isSaferMarket)) return 'Niedrig';
    if (aiScore >= 70 && odds <= 2.40) return 'Mittel';
    return 'Hoch';
  }

  int _confidence({
    required int aiScore,
    required String riskLevel,
    required String tipLabel,
  }) {
    var confidence = aiScore;

    if (tipLabel == '1X' || tipLabel == 'X2' || tipLabel == '12') {
      confidence += 5;
    }

    if (riskLevel == 'Hoch') confidence -= 8;
    if (riskLevel == 'Niedrig') confidence += 3;

    return confidence.clamp(1, 99);
  }

  String _reason({
    required ProPredictionInput input,
    required String tipLabel,
    required int aiScore,
    required int confidence,
    required String riskLevel,
    required int formScore,
    required int homeAwayScore,
    required int goalsTrendScore,
    required int headToHeadScore,
    required int tableScore,
  }) {
    final formText = '${input.homeStats.overallFormScore}:${input.awayStats.overallFormScore}';
    final tableText = input.homeStanding == null || input.awayStanding == null
        ? 'Tabelle neutral'
        : 'Tabelle ${input.homeStanding!.position}:${input.awayStanding!.position}';

    return '$tipLabel empfohlen. AI $aiScore, Confidence $confidence%, Risiko $riskLevel. '
        'Form $formText, Heim/Auswärts $homeAwayScore, Tore-Trend $goalsTrendScore, '
        'H2H $headToHeadScore, $tableText.';
  }
}
