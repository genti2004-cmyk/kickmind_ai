import 'package:kickmind_ai/features/matches/domain/football_match.dart';

class ValueBetResult {
  final FootballMatch match;
  final double aiProbability;
  final double impliedProbability;
  final double edge;
  final double odds;
  final bool isValueBet;
  final String label;
  final String explanation;

  const ValueBetResult({
    required this.match,
    required this.aiProbability,
    required this.impliedProbability,
    required this.edge,
    required this.odds,
    required this.isValueBet,
    required this.label,
    required this.explanation,
  });

  int get aiPercent => (aiProbability * 100).round().clamp(0, 100);
  int get impliedPercent => (impliedProbability * 100).round().clamp(0, 100);
  int get edgePercent => (edge * 100).round();

  String get edgeLabel {
    final prefix = edge >= 0 ? '+' : '';
    return '$prefix$edgePercent%';
  }
}
