import 'dart:math' as math;

enum OddsMarketType {
  home,
  draw,
  away,
  over25,
  under25,
  btts,
}

class OddsMarketScore {
  final double aiScore;
  final double finalScore;
  final double valueEdge;
  final double confidence;
  final String riskLevel;
  final String reason;

  const OddsMarketScore({
    required this.aiScore,
    required this.finalScore,
    required this.valueEdge,
    required this.confidence,
    required this.riskLevel,
    required this.reason,
  });
}


enum OddsMarketDecisionType { premium, value, stable, noBet }

class OddsMarketDecision {
  final OddsMarketDecisionType type;
  final String label;
  final String explanation;

  const OddsMarketDecision({
    required this.type,
    required this.label,
    required this.explanation,
  });

  bool get isPremium => type == OddsMarketDecisionType.premium;
  bool get isValue => type == OddsMarketDecisionType.value;
  bool get isStable => type == OddsMarketDecisionType.stable;
  bool get isNoBet => type == OddsMarketDecisionType.noBet;
}


class OddsScoreService {
  const OddsScoreService._();

  static const OddsScoreService instance = OddsScoreService._();

  OddsMarketScore evaluate({
    required double oddsValue,
    required double margin,
    required OddsMarketType marketType,
  }) {
    final implied = oddsValue > 1 ? (1 / oddsValue) * 100 : 0.0;
    final oddsQuality = _oddsQuality(oddsValue);
    final marketBias = _marketBias(marketType);
    final marginPenalty = math.min(10.0, margin * 100 * 0.65);
    final aiScore = (implied + oddsQuality + marketBias - marginPenalty)
        .clamp(18.0, 92.0)
        .toDouble();
    final valueEdge = aiScore - implied;
    final riskPenalty = _riskPenalty(oddsValue);
    final finalScore = (aiScore + (valueEdge * 1.25) - riskPenalty)
        .clamp(0.0, 99.0)
        .toDouble();
    final confidence = ((aiScore * 0.72) + (finalScore * 0.28))
        .clamp(0.0, 99.0)
        .toDouble();
    final risk = _riskLabel(oddsValue);

    return OddsMarketScore(
      aiScore: aiScore,
      finalScore: finalScore,
      valueEdge: valueEdge,
      confidence: confidence,
      riskLevel: risk,
      reason: _reason(
        value: oddsValue,
        finalScore: finalScore,
        valueEdge: valueEdge,
        risk: risk,
        margin: margin,
      ),
    );
  }

  OddsMarketDecision decisionFor({
    required double finalScore,
    required double valueEdge,
    required double confidence,
    required String riskLevel,
    required double oddsValue,
  }) {
    final extremeOdds = oddsValue >= 4.80 || oddsValue <= 1.28;

    if (riskLevel == 'Hoch' || finalScore < 54 || valueEdge < -2.0 || extremeOdds) {
      return const OddsMarketDecision(
        type: OddsMarketDecisionType.noBet,
        label: 'No Bet',
        explanation: 'Risiko oder Value passt aktuell nicht.',
      );
    }

    if (finalScore >= 74 && valueEdge >= 4.0 && confidence >= 68 && riskLevel != 'Hoch') {
      return const OddsMarketDecision(
        type: OddsMarketDecisionType.premium,
        label: 'Premium Value',
        explanation: 'Starker Markt mit Score, Value und Risiko im grünen Bereich.',
      );
    }

    if (finalScore >= 64 && valueEdge >= 2.0 && confidence >= 58 && riskLevel != 'Hoch') {
      return const OddsMarketDecision(
        type: OddsMarketDecisionType.value,
        label: 'Value Chance',
        explanation: 'Positive Value-Kante, aber noch nicht ganz Premium.',
      );
    }

    return const OddsMarketDecision(
      type: OddsMarketDecisionType.stable,
      label: 'Stabil beobachten',
      explanation: 'Solide Quote, aber noch kein klarer Value-Markt.',
    );
  }

  String finalReason({
    required OddsMarketDecision decision,
    required String baseReason,
    required double finalScore,
    required double valueEdge,
    required double confidence,
    required String riskLevel,
    required double oddsValue,
  }) {
    final valueText = valueEdge >= 0
        ? '+${valueEdge.toStringAsFixed(1)} Value'
        : '${valueEdge.toStringAsFixed(1)} Value';

    switch (decision.type) {
      case OddsMarketDecisionType.premium:
        return 'Premium Value: Final ${finalScore.toStringAsFixed(0)}, $valueText, Konfidenz ${confidence.toStringAsFixed(0)}% und Risiko $riskLevel. $baseReason';
      case OddsMarketDecisionType.value:
        return 'Value Chance: Die Quote hat eine positive Kante, bleibt aber unter Premium-Niveau. Final ${finalScore.toStringAsFixed(0)}, $valueText, Quote ${oddsValue.toStringAsFixed(2)}. $baseReason';
      case OddsMarketDecisionType.stable:
        return 'Stabil beobachten: Markt ist nicht schwach, aber der Value reicht noch nicht für einen klaren Einsatz. Final ${finalScore.toStringAsFixed(0)}, $valueText. $baseReason';
      case OddsMarketDecisionType.noBet:
        return 'No Bet: Quote, Risiko oder Value-Kante sind aktuell nicht sauber genug. Final ${finalScore.toStringAsFixed(0)}, $valueText, Risiko $riskLevel, Quote ${oddsValue.toStringAsFixed(2)}. $baseReason';
    }
  }

  double _oddsQuality(double value) {
    if (value >= 1.55 && value <= 2.25) return 10;
    if (value > 2.25 && value <= 3.20) return 5;
    if (value >= 1.30 && value < 1.55) return 3;
    if (value > 3.20) return -5;
    return -7;
  }

  double _marketBias(OddsMarketType type) {
    switch (type) {
      case OddsMarketType.home:
        return 4;
      case OddsMarketType.away:
        return 1;
      case OddsMarketType.draw:
        return -4;
      case OddsMarketType.over25:
        return 3;
      case OddsMarketType.under25:
        return 1;
      case OddsMarketType.btts:
        return 2;
    }
  }

  double _riskPenalty(double value) {
    if (value <= 1.70) return 3;
    if (value <= 2.30) return 6;
    if (value <= 3.10) return 12;
    return 20;
  }

  String _riskLabel(double value) {
    if (value <= 1.75) return 'Niedrig';
    if (value <= 2.65) return 'Mittel';
    return 'Hoch';
  }

  String _reason({
    required double value,
    required double finalScore,
    required double valueEdge,
    required String risk,
    required double margin,
  }) {
    final edgeText = valueEdge >= 0
        ? 'positiver Value Edge'
        : 'kein klarer Value Edge';
    final marginText = margin <= 0.08
        ? 'faire Markt-Marge'
        : 'erhöhte Buchmacher-Marge';

    if (finalScore >= 72) {
      return 'Starker Quoten-Kandidat: $edgeText, $marginText und Risiko $risk bei Quote ${value.toStringAsFixed(2)}.';
    }

    if (finalScore >= 60) {
      return 'Beobachten: solide Quote mit brauchbarer Bewertung, aber nicht als Blind-Tipp spielen.';
    }

    return 'Nur prüfen: Die Quote ist aktuell nicht stark genug für eine klare Top-Tipp-Empfehlung.';
  }
}
