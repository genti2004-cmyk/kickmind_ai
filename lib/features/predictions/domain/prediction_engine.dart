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
    final formBalance = ((homeFormScore + awayFormScore) / 2).clamp(1, 99);

    final valueScore = _valueScoreForOdds(odds);
    final marketFit = _marketFitScore(
      tipType: tipType,
      homeFormScore: homeFormScore,
      awayFormScore: awayFormScore,
      goalsScore: goalsScore,
    );

    double score =
        (formBalance * 0.26) +
            (goalsScore * 0.24) +
            (formEdge * 0.14) +
            (valueScore * 0.18) +
            (marketFit * 0.18);

    if (tipType == TipType.doubleChance) {
      score += 5;
    }

    if (odds > 3.50) {
      score -= 14;
    } else if (odds > 2.80) {
      score -= 7;
    }

    if (odds < 1.20) {
      score -= 6;
    }

    return score.clamp(1, 99).round();
  }

  RiskLevel calculateRisk({
    required int aiScore,
    required double odds,
  }) {
    if (aiScore >= 82 && odds <= 1.85) {
      return RiskLevel.low;
    }

    if (aiScore >= 70 && odds <= 2.60) {
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

    if (tipType == TipType.homeWin) {
      return 'Heimsieg wird bevorzugt, weil Heimform und Gesamtbewertung stärker ausfallen. Formabstand: $formEdge Punkte.';
    }

    if (tipType == TipType.awayWin) {
      return 'Auswärtssieg ist interessant, weil das Auswärtsteam statistisch klar stärker wirkt. Formabstand: $formEdge Punkte.';
    }

    if (tipType == TipType.over25) {
      return 'Über 2.5 Tore wird bevorzugt, weil der Tortrend mit $goalsScore% stark genug ist.';
    }

    if (tipType == TipType.under25) {
      return 'Unter 2.5 Tore wirkt sinnvoll, weil der Tortrend niedrig ausfällt und wenig Offensivdruck erwartet wird.';
    }

    if (tipType == TipType.bothTeamsScore) {
      return 'Beide Teams treffen ist interessant, weil Form und Tortrend ausgeglichen genug sind.';
    }

    if (tipType == TipType.doubleChance) {
      return 'Doppelchance reduziert Risiko. Der Formabstand liegt bei $formEdge Punkten.';
    }

    if (aiScore >= 82) {
      return 'Sehr starke Gesamtbewertung mit guter Datenlage und akzeptabler Quote.';
    }

    if (aiScore >= 70) {
      return 'Solide Prognose, aber mit mittlerem Risiko.';
    }

    return 'Prognose ist möglich, aber Risiko und Datenlage sind nicht optimal.';
  }

  double _valueScoreForOdds(double odds) {
    if (odds < 1.20) return 42;
    if (odds <= 1.45) return 65;
    if (odds <= 1.85) return 90;
    if (odds <= 2.30) return 84;
    if (odds <= 2.80) return 68;
    if (odds <= 3.50) return 48;
    return 20;
  }

  double _marketFitScore({
    required TipType tipType,
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
  }) {
    final edge = homeFormScore - awayFormScore;
    final absEdge = edge.abs();

    switch (tipType) {
      case TipType.homeWin:
        if (edge >= 18) return 96;
        if (edge >= 10) return 84;
        if (edge >= 5) return 70;
        return 45;

      case TipType.awayWin:
        if (edge <= -18) return 96;
        if (edge <= -10) return 84;
        if (edge <= -5) return 70;
        return 45;

      case TipType.doubleChance:
        if (absEdge >= 10) return 88;
        if (absEdge >= 5) return 78;
        return 65;

      case TipType.over25:
        if (goalsScore >= 88) return 94;
        if (goalsScore >= 80) return 84;
        if (goalsScore >= 72) return 70;
        return 45;

      case TipType.under25:
        if (goalsScore <= 45) return 92;
        if (goalsScore <= 55) return 80;
        if (goalsScore <= 62) return 68;
        return 40;

      case TipType.bothTeamsScore:
        final balance = 100 - absEdge;
        final combined = (balance * 0.45) + (goalsScore * 0.55);
        return combined.clamp(1, 99);

      case TipType.draw:
        if (absEdge <= 4 && goalsScore <= 68) return 82;
        if (absEdge <= 8) return 66;
        return 38;
    }
  }
}