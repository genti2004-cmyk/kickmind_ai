import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_breakdown.dart';
import 'package:kickmind_ai/features/predictions/domain/pro_prediction_input.dart';

/// Finale PredictionEngine für KickMind AI.
///
/// Ziele:
/// - kompatibel mit deinem bestehenden FootballMatch-Modell
/// - keine neuen RiskLevel-Enums
/// - Tipp-Labels: 1, X, 2, 1X, X2, 12, Über 2.5, Unter 2.5, BTTS
/// - transparenter PredictionBreakdown für UI/Detail-Screen
/// - alte Methoden wie buildMatch(), rankTopTips(), smartScore() bleiben erhalten
class PredictionEngine {
  const PredictionEngine();

  /// Baut ein fertig angereichertes Match aus ProPredictionInput.
  FootballMatch buildProMatch(ProPredictionInput input) {
    final breakdown = buildBreakdown(input);
    final match = input.match;

    return match.copyWith(
      tipType: breakdown.tipType,
      tipLabel: breakdown.tipLabel,
      aiScore: breakdown.aiScore,
      riskLevel: breakdown.riskLevel,
      odds: breakdown.estimatedOdds,
      homeFormScore: input.homeStats.overallFormScore,
      awayFormScore: input.awayStats.overallFormScore,
      goalsScore: breakdown.goalsTrendScore,
      shortReason: breakdown.reason,
    );
  }

  /// Transparenter AI-Breakdown für Detail-Screen, MatchCard und Top-Tipps.
  PredictionBreakdown buildBreakdown(ProPredictionInput input) {
    final formScore = _formScore(input);
    final homeAwayScore = input.homeAdvantageScore.clamp(1, 99);
    final goalsTrendScore = input.goalsTrendScore.clamp(1, 99);
    final headToHeadScore = input.headToHeadScore.clamp(1, 99);
    final tableScore = input.tableAdvantageScore.clamp(1, 99);

    final aiScore = _buildAiScore(
      formScore: formScore,
      homeAwayScore: homeAwayScore,
      goalsTrendScore: goalsTrendScore,
      headToHeadScore: headToHeadScore,
      tableScore: tableScore,
    );

    final tipLabel = _bestProTipLabel(
      input: input,
      aiScore: aiScore,
      formScore: formScore,
      goalsTrendScore: goalsTrendScore,
      headToHeadScore: headToHeadScore,
      tableScore: tableScore,
    );

    final tipType = _mapLabelToTipType(tipLabel);
    final odds = estimateOddsForLabel(tipLabel);
    final risk = calculateRisk(
      aiScore: aiScore,
      odds: odds,
      tipLabel: tipLabel,
    );
    final confidence = buildConfidence(
      aiScore: aiScore,
      riskLevel: risk,
      tipLabel: tipLabel,
      formScore: formScore,
      goalsTrendScore: goalsTrendScore,
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
      reason: _buildReason(
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

  String buildProReason({
    required String tipLabel,
    required int aiScore,
    required ProPredictionInput input,
  }) {
    final breakdown = buildBreakdown(input);
    return breakdown.reason;
  }

  /// Fallback/MVP-Erzeugung, falls nur einfache Matchdaten vorhanden sind.
  FootballMatch buildMatch({
    required String id,
    int? fixtureId,
    int? season,
    required String league,
    required String home,
    required String away,
    required DateTime kickoff,
    TipType? tipType,
    double? odds,
    int? homeFormScore,
    int? awayFormScore,
    int? goalsScore,
  }) {
    final resolvedHomeForm =
        homeFormScore ?? _stableScore(home, min: 45, max: 88);
    final resolvedAwayForm =
        awayFormScore ?? _stableScore(away, min: 42, max: 86);
    final resolvedGoalsScore =
        goalsScore ?? _stableScore('$home-$away-goals', min: 48, max: 90);

    final resolvedTipType = tipType ??
        _bestTipType(
          homeFormScore: resolvedHomeForm,
          awayFormScore: resolvedAwayForm,
          goalsScore: resolvedGoalsScore,
        );

    final label = tipLabel(resolvedTipType);
    final resolvedOdds = odds ?? estimateOddsForLabel(label);

    final aiScore = calculateAiScore(
      homeFormScore: resolvedHomeForm,
      awayFormScore: resolvedAwayForm,
      goalsScore: resolvedGoalsScore,
      odds: resolvedOdds,
      tipType: resolvedTipType,
    );

    final risk = calculateRisk(
      aiScore: aiScore,
      odds: resolvedOdds,
      tipLabel: label,
    );

    return FootballMatch(
      id: id,
      fixtureId: fixtureId,
      season: season ?? DateTime.now().year,
      league: league,
      homeTeam: home,
      awayTeam: away,
      kickoff: kickoff,
      kickoffLabel: _formatKickoff(kickoff),
      tipType: resolvedTipType,
      tipLabel: label,
      aiScore: aiScore,
      riskLevel: risk,
      odds: resolvedOdds,
      homeFormScore: resolvedHomeForm,
      awayFormScore: resolvedAwayForm,
      goalsScore: resolvedGoalsScore,
      shortReason: buildReason(
        tipType: resolvedTipType,
        homeFormScore: resolvedHomeForm,
        awayFormScore: resolvedAwayForm,
        goalsScore: resolvedGoalsScore,
        aiScore: aiScore,
      ),
    );
  }

  List<FootballMatch> rankTopTips(
      List<FootballMatch> matches, {
        int limit = 5,
      }) {
    final sorted = [...matches]
      ..sort((a, b) {
        final confidenceA = _derivedConfidenceFromMatch(a);
        final confidenceB = _derivedConfidenceFromMatch(b);

        final confidenceCompare = confidenceB.compareTo(confidenceA);
        if (confidenceCompare != 0) return confidenceCompare;

        final scoreCompare = b.aiScore.compareTo(a.aiScore);
        if (scoreCompare != 0) return scoreCompare;

        return a.odds.compareTo(b.odds);
      });

    return sorted.take(limit).toList();
  }

  int smartScore(FootballMatch match) => match.aiScore;

  int calculateAiScore({
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
    required double odds,
    required TipType tipType,
  }) {
    final formScore = switch (tipType) {
      TipType.homeWin => homeFormScore,
      TipType.awayWin => awayFormScore,
      TipType.draw =>
          (100 - (homeFormScore - awayFormScore).abs()).clamp(40, 95),
      TipType.over25 => goalsScore,
      TipType.under25 => 100 - goalsScore,
      TipType.btts => ((goalsScore + homeFormScore + awayFormScore) / 3).round(),
    };

    final oddsScore = (100 - ((odds - 1.0) * 20)).round().clamp(35, 100);

    return ((formScore * 0.55) + (goalsScore * 0.25) + (oddsScore * 0.20))
        .round()
        .clamp(1, 99);
  }

  String calculateRisk({
    required int aiScore,
    required double odds,
    String? tipLabel,
  }) {
    final label = tipLabel ?? '';
    final saferMarket = label == '1X' || label == 'X2' || label == '12';

    if (aiScore >= 82 && (odds <= 1.90 || saferMarket)) return 'Niedrig';
    if (aiScore >= 70 && odds <= 2.45) return 'Mittel';
    return 'Hoch';
  }

  int buildConfidence({
    required int aiScore,
    required String riskLevel,
    required String tipLabel,
    int? formScore,
    int? goalsTrendScore,
  }) {
    var confidence = aiScore;

    if (tipLabel == '1X' || tipLabel == 'X2' || tipLabel == '12') {
      confidence += 5;
    }
    if (tipLabel == 'Über 2.5' || tipLabel == 'Unter 2.5' || tipLabel == 'BTTS') {
      confidence += 2;
    }

    if (riskLevel == 'Niedrig') confidence += 3;
    if (riskLevel == 'Hoch') confidence -= 8;

    if (formScore != null && formScore >= 80) confidence += 2;
    if (goalsTrendScore != null && goalsTrendScore >= 80) confidence += 2;

    return confidence.clamp(1, 99);
  }

  String buildReason({
    required TipType tipType,
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
    required int aiScore,
  }) {
    final tip = tipLabel(tipType);
    final diff = homeFormScore - awayFormScore;

    if (tipType == TipType.homeWin) {
      return '$tip empfohlen. Heimteam mit Formvorteil $homeFormScore:$awayFormScore. AI $aiScore, Tore-Trend $goalsScore.';
    }
    if (tipType == TipType.awayWin) {
      return '$tip empfohlen. Auswärtsteam mit Formvorteil $awayFormScore:$homeFormScore. AI $aiScore, Tore-Trend $goalsScore.';
    }
    if (tipType == TipType.draw) {
      return '$tip empfohlen. Teams liegen eng beieinander (Differenz ${diff.abs()}). AI $aiScore.';
    }
    if (tipType == TipType.over25) {
      return '$tip empfohlen. Hoher Tore-Trend $goalsScore/100. AI $aiScore.';
    }
    if (tipType == TipType.under25) {
      return '$tip empfohlen. Niedriger Tore-Trend $goalsScore/100. AI $aiScore.';
    }
    return '$tip empfohlen. Beide Teams mit offensivem Potenzial. AI $aiScore, Tore-Trend $goalsScore.';
  }

  String tipLabel(TipType type) {
    switch (type) {
      case TipType.homeWin:
        return '1';
      case TipType.draw:
        return 'X';
      case TipType.awayWin:
        return '2';
      case TipType.over25:
        return 'Über 2.5';
      case TipType.under25:
        return 'Unter 2.5';
      case TipType.btts:
        return 'BTTS';
    }
  }

  double estimateOdds(TipType type) => estimateOddsForLabel(tipLabel(type));

  double estimateOddsForLabel(String label) {
    switch (label) {
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

  int _buildAiScore({
    required int formScore,
    required int homeAwayScore,
    required int goalsTrendScore,
    required int headToHeadScore,
    required int tableScore,
  }) {
    return ((formScore * 0.32) +
        (homeAwayScore * 0.20) +
        (goalsTrendScore * 0.20) +
        (headToHeadScore * 0.13) +
        (tableScore * 0.15))
        .round()
        .clamp(1, 99);
  }

  int _formScore(ProPredictionInput input) {
    final home = input.homeStats.overallFormScore;
    final away = input.awayStats.overallFormScore;
    final diff = home - away;

    if (diff.abs() <= 5) return 68;

    final stronger = diff > 0 ? home : away;
    final weaker = diff > 0 ? away : home;

    return ((stronger * 0.72) + ((100 - weaker) * 0.28)).round().clamp(1, 99);
  }

  String _bestProTipLabel({
    required ProPredictionInput input,
    required int aiScore,
    required int formScore,
    required int goalsTrendScore,
    required int headToHeadScore,
    required int tableScore,
  }) {
    final formDiff = input.formDifference;
    final homeStrong = formDiff >= 15 && tableScore >= 56;
    final awayStrong = formDiff <= -15 && tableScore <= 44;
    final closeMatch = formDiff.abs() <= 6;

    // Zuerst klare Tor-Märkte, wenn der Trend stark ist.
    if (goalsTrendScore >= 80 && aiScore >= 68) return 'Über 2.5';
    if (goalsTrendScore <= 38 && aiScore >= 64) return 'Unter 2.5';

    // Danach klare 1/X/2 Tipps.
    if (homeStrong && aiScore >= 75) return '1';
    if (awayStrong && aiScore >= 75) return '2';

    // Sicherere Märkte, wenn der Favorit nicht klar genug ist.
    if (formDiff >= 7 && headToHeadScore >= 48) return '1X';
    if (formDiff <= -7 && headToHeadScore <= 52) return 'X2';

    if (closeMatch && aiScore >= 62) return 'X';
    if (goalsTrendScore >= 62) return 'BTTS';

    return '12';
  }

  TipType _mapLabelToTipType(String label) {
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

  TipType _bestTipType({
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
  }) {
    final diff = homeFormScore - awayFormScore;

    if (goalsScore >= 78) return TipType.over25;
    if (goalsScore <= 43) return TipType.under25;
    if (diff >= 10) return TipType.homeWin;
    if (diff <= -10) return TipType.awayWin;
    if (diff.abs() <= 5) return TipType.draw;
    return TipType.btts;
  }

  String _buildReason({
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
    final formText =
        '${input.homeStats.overallFormScore}:${input.awayStats.overallFormScore}';
    final tableText = input.homeStanding == null || input.awayStanding == null
        ? 'Tabelle neutral'
        : 'Tabelle ${input.homeStanding!.position}:${input.awayStanding!.position}';

    return '$tipLabel empfohlen. AI $aiScore, Confidence $confidence%, Risiko $riskLevel. '
        'Form $formText, Heim/Auswärts $homeAwayScore, Tore-Trend $goalsTrendScore, '
        'H2H $headToHeadScore, $tableText.';
  }

  int _derivedConfidenceFromMatch(FootballMatch match) {
    return buildConfidence(
      aiScore: match.aiScore,
      riskLevel: match.riskLevel,
      tipLabel: match.tipLabel,
      formScore: match.homeFormScore > match.awayFormScore
          ? match.homeFormScore
          : match.awayFormScore,
      goalsTrendScore: match.goalsScore,
    );
  }

  int _stableScore(String seed, {required int min, required int max}) {
    final hash = seed.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return min + (hash % (max - min + 1));
  }

  String _formatKickoff(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
