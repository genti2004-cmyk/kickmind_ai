import 'package:kickmind_ai/features/matches/domain/football_match.dart';

/// Transparenter Pro-Breakdown für die AI-Auswertung.
///
/// Diese Klasse ändert keine API-Struktur. Sie erklärt nur, wie der AI-Score
/// zustande kommt und macht die Detailansicht später professioneller.
class PredictionBreakdown {
  final int formScore;
  final int homeAwayScore;
  final int goalsTrendScore;
  final int headToHeadScore;
  final int tableScore;
  final int aiScore;
  final int confidence;
  final String riskLevel;
  final String tipLabel;
  final TipType tipType;
  final double estimatedOdds;
  final String reason;

  const PredictionBreakdown({
    required this.formScore,
    required this.homeAwayScore,
    required this.goalsTrendScore,
    required this.headToHeadScore,
    required this.tableScore,
    required this.aiScore,
    required this.confidence,
    required this.riskLevel,
    required this.tipLabel,
    required this.tipType,
    required this.estimatedOdds,
    required this.reason,
  });

  Map<String, int> get weightedParts => <String, int>{
    'Form': formScore,
    'Heim/Auswärts': homeAwayScore,
    'Tore-Trend': goalsTrendScore,
    'Direkte Duelle': headToHeadScore,
    'Tabelle': tableScore,
  };

  bool get isProTip => aiScore >= 80 && riskLevel.toLowerCase() != 'hoch';

  String get riskEmoji {
    final value = riskLevel.toLowerCase();
    if (value.contains('niedrig') || value.contains('low')) return '🟢';
    if (value.contains('mittel') || value.contains('medium')) return '🟡';
    return '🔴';
  }

  String get confidenceLabel => '$confidence%';
}
