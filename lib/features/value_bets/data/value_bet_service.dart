import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/value_bets/domain/value_bet_result.dart';
import 'package:kickmind_ai/features/odds/data/live_odds_service.dart';

class ValueBetService {
  const ValueBetService();

  /// Implizite Wahrscheinlichkeit aus Quote.
  /// Beispiel: Quote 2.00 = 50% implizit.
  double impliedProbability(double odds) {
    if (odds <= 1.0) return 1.0;
    return (1 / odds).clamp(0.0, 1.0);
  }

  /// Schätzt AI-Wahrscheinlichkeit aus aiScore + riskLevel.
  /// Das bleibt stabil, auch wenn keine echte Odds-API vorhanden ist.
  double aiProbability(FootballMatch match) {
    final base = (match.aiScore / 100).clamp(0.0, 0.99);
    final riskPenalty = _riskPenalty(match.riskLevel);
    return (base - riskPenalty).clamp(0.05, 0.95);
  }

  ValueBetResult evaluate(FootballMatch match) {
    final odds = match.odds <= 1.0 ? _fallbackOdds(match) : match.odds;
    final aiProb = aiProbability(match);
    final implied = impliedProbability(odds);
    final edge = aiProb - implied;
    final isValue = edge >= 0.07 && match.aiScore >= 70 && match.riskLevel.toLowerCase() != 'hoch';

    return ValueBetResult(
      match: match,
      aiProbability: aiProb,
      impliedProbability: implied,
      edge: edge,
      odds: odds,
      isValueBet: isValue,
      label: isValue ? 'VALUE BET' : 'Kein Value',
      explanation: _buildExplanation(
        match: match,
        aiProbability: aiProb,
        impliedProbability: implied,
        edge: edge,
        isValue: isValue,
      ),
    );
  }

  List<ValueBetResult> evaluateAll(List<FootballMatch> matches) {
    final results = matches.map(evaluate).toList();
    results.sort((a, b) {
      final valueCompare = b.isValueBet.toString().compareTo(a.isValueBet.toString());
      if (valueCompare != 0) return valueCompare;
      final edgeCompare = b.edge.compareTo(a.edge);
      if (edgeCompare != 0) return edgeCompare;
      return b.match.aiScore.compareTo(a.match.aiScore);
    });
    return results;
  }

  List<ValueBetResult> valueOnly(List<FootballMatch> matches) {
    return evaluateAll(matches).where((r) => r.isValueBet).toList();
  }

  double _riskPenalty(String risk) {
    final value = risk.toLowerCase();
    if (value.contains('niedrig') || value.contains('low')) return 0.00;
    if (value.contains('mittel') || value.contains('medium')) return 0.04;
    return 0.10;
  }

  double _fallbackOdds(FootballMatch match) {
    switch (match.tipLabel) {
      case '1':
        return 1.80;
      case 'X':
        return 3.20;
      case '2':
        return 2.20;
      case '1X':
        return 1.35;
      case 'X2':
        return 1.55;
      case '12':
        return 1.42;
      case 'Über 2.5':
      case 'Over 2.5':
        return 1.85;
      case 'Unter 2.5':
      case 'Under 2.5':
        return 1.95;
      case 'BTTS':
        return 1.82;
      default:
        return 1.90;
    }
  }

  String _buildExplanation({
    required FootballMatch match,
    required double aiProbability,
    required double impliedProbability,
    required double edge,
    required bool isValue,
  }) {
    final ai = (aiProbability * 100).round();
    final implied = (impliedProbability * 100).round();
    final edgePct = (edge * 100).round();

    if (isValue) {
      return 'Value erkannt: Deine AI sieht $ai% Chance, die Quote entspricht nur $implied%. Vorteil: +$edgePct%. Tipp: ${match.tipLabel}.';
    }

    if (edge >= 0) {
      return 'Leichter Vorteil, aber noch kein starker Value: AI $ai%, Quote impliziert $implied%, Edge +$edgePct%.';
    }

    return 'Kein Value: AI $ai%, Quote impliziert $implied%. Die Quote ist aktuell nicht attraktiv genug.';
  }
}
