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
