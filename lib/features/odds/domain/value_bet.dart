import 'live_odds.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';

class ValueBet {
  final FootballMatch match;
  final LiveOdds odds;
  final double selectedOdds;
  final double aiProbability;
  final double impliedProbability;
  final double edge;
  final bool isValue;

  const ValueBet({
    required this.match,
    required this.odds,
    required this.selectedOdds,
    required this.aiProbability,
    required this.impliedProbability,
    required this.edge,
    required this.isValue,
  });

  String get edgeLabel => '${(edge * 100).toStringAsFixed(1)}%';
  String get probabilityLabel => '${(aiProbability * 100).toStringAsFixed(0)}%';
  String get impliedLabel => '${(impliedProbability * 100).toStringAsFixed(0)}%';
}
