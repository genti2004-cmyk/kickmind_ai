import '../../matches/domain/football_match.dart';

class PredictionEngine {
  const PredictionEngine();

  int calculateAiScore({
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
    required double odds,
    required TipType tipType,
  }) {
    final formEdge = (homeFormScore - awayFormScore).abs();

    double score =
        (homeFormScore * 0.28) +
            (awayFormScore * 0.18) +
            (goalsScore * 0.30) +
            (formEdge * 0.14) +
            (_oddsQualityScore(odds) * 0.10);

    if (tipType == TipType.doubleChance) {
      score += 4;
    }

    if (tipType == TipType.over25 || tipType == TipType.bothTeamsScore) {
      score += goalsScore >= 80 ? 5 : 0;
    }

    return score.clamp(1, 99).round();
  }

  RiskLevel calculateRisk({
    required int aiScore,
    required double odds,
  }) {
    if (aiScore >= 80 && odds <= 1.80) {
      return RiskLevel.low;
    }

    if (aiScore >= 68 && odds <= 2.20) {
      return RiskLevel.medium;
    }

    return RiskLevel.high;
  }

  String buildReason({
    required TipType tipType,
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
    required int aiScore,
  }) {
    final formEdge = (homeFormScore - awayFormScore).abs();

    if (tipType == TipType.over25) {
      return 'Hohe Torbewertung ($goalsScore%) und offensive Tendenz sprechen für Über 2.5 Tore.';
    }

    if (tipType == TipType.bothTeamsScore) {
      return 'Beide Teams zeigen starke Torwahrscheinlichkeit. BTTS ist statistisch interessant.';
    }

    if (tipType == TipType.doubleChance) {
      return 'Doppelchance reduziert Risiko. Formabstand liegt bei $formEdge Punkten.';
    }

    if (aiScore >= 80) {
      return 'Sehr starke Gesamtbewertung mit klarem Form- und Statistikvorteil.';
    }

    if (aiScore >= 70) {
      return 'Solide Prognose mit guter Formbasis, aber nicht komplett risikofrei.';
    }

    return 'Prognose ist möglich, aber Risiko und Datenlage sind nicht optimal.';
  }

  double _oddsQualityScore(double odds) {
    if (odds <= 1.30) return 62;
    if (odds <= 1.60) return 78;
    if (odds <= 1.90) return 88;
    if (odds <= 2.20) return 74;
    if (odds <= 2.80) return 58;
    return 40;
  }
}