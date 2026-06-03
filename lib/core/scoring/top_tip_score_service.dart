import 'dart:math' as math;

import 'package:kickmind_ai/features/matches/domain/football_match.dart';

class TopTipScore {
  final double finalScore;
  final double valueEdge;
  final double confidence;
  final double riskBonus;
  final double oddsBonus;
  final double formBoost;
  final bool isRecommended;
  final bool isValueBet;
  final bool isHighRisk;
  final bool isLowRisk;

  const TopTipScore({
    required this.finalScore,
    required this.valueEdge,
    required this.confidence,
    required this.riskBonus,
    required this.oddsBonus,
    required this.formBoost,
    required this.isRecommended,
    required this.isValueBet,
    required this.isHighRisk,
    required this.isLowRisk,
  });

  factory TopTipScore.fromMatch(FootballMatch match) {
    return TopTipScoreService.instance.score(match);
  }

  bool get isNoBet => !isRecommended && finalScore < 58;

  String get recommendationLabel {
    if (isRecommended) return 'Top Tipp';
    if (isValueBet) return 'Value Chance';
    if (isNoBet) return 'No-Bet';
    return 'Beobachten';
  }
}

class TopTipValueInfo {
  final bool isValueBet;
  final double aiProbabilityPercent;
  final double impliedProbabilityPercent;
  final double edgePercent;

  const TopTipValueInfo({
    required this.isValueBet,
    required this.aiProbabilityPercent,
    required this.impliedProbabilityPercent,
    required this.edgePercent,
  });
}

class TopTipScoreService {
  const TopTipScoreService._();

  static const TopTipScoreService instance = TopTipScoreService._();

  TopTipScore score(FootballMatch match) {
    final valueEdge = calculateValueEdge(match);
    final riskBonus = calculateRiskBonus(match);
    final oddsBonus = calculateOddsBonus(match.odds);
    final formBoost = calculateFormBoost(match);

    final finalScore = (match.aiScore * 0.62 +
        valueEdge.clamp(-15.0, 18.0) * 0.95 +
        riskBonus +
        oddsBonus +
        formBoost)
        .clamp(1.0, 99.0)
        .toDouble();

    final confidence = (match.aiScore + riskBonus + formBoost + oddsBonus)
        .clamp(1.0, 99.0)
        .toDouble();

    final highRisk = isHighRisk(match);
    final recommended = match.aiScore >= 68 &&
        !(highRisk && match.aiScore < 82) &&
        finalScore >= 67;
    final valueBet = match.aiScore >= 70 && valueEdge >= 4.5;

    return TopTipScore(
      finalScore: finalScore,
      valueEdge: valueEdge,
      confidence: confidence,
      riskBonus: riskBonus,
      oddsBonus: oddsBonus,
      formBoost: formBoost,
      isRecommended: recommended,
      isValueBet: valueBet,
      isHighRisk: highRisk,
      isLowRisk: isLowRisk(match),
    );
  }

  int compareByFinalScore(FootballMatch a, FootballMatch b) {
    final scoreA = score(a);
    final scoreB = score(b);

    final finalCompare = scoreB.finalScore.compareTo(scoreA.finalScore);
    if (finalCompare != 0) return finalCompare;

    final aiCompare = b.aiScore.compareTo(a.aiScore);
    if (aiCompare != 0) return aiCompare;

    final valueCompare = scoreB.valueEdge.compareTo(scoreA.valueEdge);
    if (valueCompare != 0) return valueCompare;

    return a.odds.compareTo(b.odds);
  }

  TopTipValueInfo valueInfo(FootballMatch match) {
    if (match.odds <= 1.0) {
      return const TopTipValueInfo(
        isValueBet: false,
        aiProbabilityPercent: 0,
        impliedProbabilityPercent: 0,
        edgePercent: 0,
      );
    }

    final aiProbability = (match.aiScore / 100).clamp(0.0, 1.0).toDouble();
    final impliedProbability = (1 / match.odds).clamp(0.0, 1.0).toDouble();
    final edge = aiProbability - impliedProbability;

    return TopTipValueInfo(
      isValueBet: match.aiScore >= 70 && edge >= 0.045,
      aiProbabilityPercent: aiProbability * 100,
      impliedProbabilityPercent: impliedProbability * 100,
      edgePercent: edge * 100,
    );
  }

  bool isRecommendedTip(FootballMatch match) => score(match).isRecommended;

  bool isValueBet(FootballMatch match) => score(match).isValueBet;

  bool isHighRisk(FootballMatch match) {
    final risk = match.riskLevel.toLowerCase();
    return risk.contains('hoch') || risk.contains('high');
  }

  bool isLowRisk(FootballMatch match) {
    final risk = match.riskLevel.toLowerCase();
    return risk.contains('niedrig') || risk.contains('low');
  }

  double calculateValueEdge(FootballMatch match) {
    if (match.odds <= 1.0) return 0.0;

    final aiProbability = (match.aiScore / 100.0).clamp(0.0, 1.0).toDouble();
    final impliedProbability = (1.0 / match.odds).clamp(0.0, 1.0).toDouble();

    return (aiProbability - impliedProbability) * 100.0;
  }

  double calculateRiskBonus(FootballMatch match) {
    final risk = match.riskLevel.toLowerCase();

    if (risk.contains('niedrig') || risk.contains('low')) return 8.0;
    if (risk.contains('mittel') || risk.contains('medium')) return 2.0;
    return -10.0;
  }

  double calculateOddsBonus(double odds) {
    if (odds >= 1.45 && odds <= 2.05) return 5.0;
    if (odds > 2.05 && odds <= 2.45) return 1.0;
    if (odds < 1.25 || odds > 3.10) return -5.0;
    return 0.0;
  }

  double calculateFormBoost(FootballMatch match) {
    final strongestForm = math.max(match.homeFormScore, match.awayFormScore);

    if (strongestForm >= 84) return 5.0;
    if (strongestForm >= 76) return 2.5;
    if (strongestForm < 58) return -4.0;
    return 0.0;
  }
}
