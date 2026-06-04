import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_breakdown.dart';
import 'package:kickmind_ai/features/predictions/domain/pro_prediction_input.dart';

/// PredictionEngine für KickMind AI.
///
/// Stufe 8:
/// - realistischere Gewichtung der Signale
/// - vorsichtigere 1/X/2-Auswahl
/// - bessere No-Bet-/Risiko-Vorbereitung über Risiko und Confidence
/// - stabilere Begründungen für Top Tipps, Detailseite und Analyse
/// - alte Methoden bleiben kompatibel: buildMatch(), buildProMatch(),
///   buildBreakdown(), rankTopTips(), smartScore(), calculateAiScore().
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
    final ranked = matches
        .where((match) => _isPlayableMatch(match))
        .toList()
      ..sort((a, b) {
        final confidenceA = _derivedConfidenceFromMatch(a);
        final confidenceB = _derivedConfidenceFromMatch(b);

        final confidenceCompare = confidenceB.compareTo(confidenceA);
        if (confidenceCompare != 0) return confidenceCompare;

        final scoreCompare = b.aiScore.compareTo(a.aiScore);
        if (scoreCompare != 0) return scoreCompare;

        // Bei gleicher Qualität bevorzugen wir keine extremen Fantasiequoten.
        final oddsDistanceA = (a.odds - 1.85).abs();
        final oddsDistanceB = (b.odds - 1.85).abs();
        return oddsDistanceA.compareTo(oddsDistanceB);
      });

    return ranked.take(limit).toList();
  }

  int smartScore(FootballMatch match) {
    final confidence = _derivedConfidenceFromMatch(match);
    final oddsPenalty = match.odds >= 3.20 ? 6 : 0;
    final riskPenalty = match.riskLevel == 'Hoch' ? 8 : 0;
    return ((match.aiScore * 0.70) + (confidence * 0.30) - oddsPenalty - riskPenalty)
        .round()
        .clamp(1, 99);
  }

  int calculateAiScore({
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
    required double odds,
    required TipType tipType,
  }) {
    final formDiff = homeFormScore - awayFormScore;
    final balancedScore = (100 - formDiff.abs()).clamp(35, 96);

    final marketScore = switch (tipType) {
      TipType.homeWin => _sideWinScore(
        ownForm: homeFormScore,
        opponentForm: awayFormScore,
        diff: formDiff,
      ),
      TipType.awayWin => _sideWinScore(
        ownForm: awayFormScore,
        opponentForm: homeFormScore,
        diff: -formDiff,
      ),
      TipType.draw => balancedScore,
      TipType.over25 => ((goalsScore * 0.80) + (_bothTeamsForm(homeFormScore, awayFormScore) * 0.20)).round(),
      TipType.under25 => (((100 - goalsScore) * 0.82) + (balancedScore * 0.18)).round(),
      TipType.btts => ((goalsScore * 0.58) + (_bothTeamsForm(homeFormScore, awayFormScore) * 0.42)).round(),
    };

    final oddsScore = _oddsQualityScore(odds);

    return ((marketScore * 0.72) + (oddsScore * 0.18) + (balancedScore * 0.10))
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
    final volatileMarket = label == 'X' || odds >= 3.00;

    if (aiScore >= 84 && (odds <= 1.95 || saferMarket)) return 'Niedrig';
    if (aiScore >= 76 && saferMarket) return 'Niedrig';
    if (volatileMarket && aiScore < 88) return 'Hoch';
    if (aiScore >= 72 && odds <= 2.35) return 'Mittel';
    if (aiScore >= 78 && odds <= 2.75) return 'Mittel';
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
      confidence += 1;
    }
    if (tipLabel == 'X') {
      confidence -= 4;
    }

    if (riskLevel == 'Niedrig') confidence += 4;
    if (riskLevel == 'Mittel') confidence += 1;
    if (riskLevel == 'Hoch') confidence -= 10;

    if (formScore != null && formScore >= 82) confidence += 2;
    if (goalsTrendScore != null && goalsTrendScore >= 82) confidence += 1;
    if (goalsTrendScore != null && goalsTrendScore <= 34 && tipLabel == 'Unter 2.5') {
      confidence += 2;
    }

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
    final formText = '$homeFormScore:$awayFormScore';

    if (tipType == TipType.homeWin) {
      return '$tip empfohlen: Heimteam hat den klareren Formvorteil ($formText). AI $aiScore, Tore-Trend $goalsScore.';
    }
    if (tipType == TipType.awayWin) {
      return '$tip empfohlen: Auswärtsteam hat den klareren Formvorteil ($awayFormScore:$homeFormScore). AI $aiScore, Tore-Trend $goalsScore.';
    }
    if (tipType == TipType.draw) {
      return '$tip empfohlen: beide Teams liegen eng beieinander (Differenz ${diff.abs()}). AI $aiScore.';
    }
    if (tipType == TipType.over25) {
      return '$tip empfohlen: starker Tore-Trend $goalsScore/100 und passende Offensivwerte. AI $aiScore.';
    }
    if (tipType == TipType.under25) {
      return '$tip empfohlen: niedriger Tore-Trend $goalsScore/100, daher vorsichtiger Under-Markt. AI $aiScore.';
    }
    return '$tip empfohlen: beide Teams zeigen genug Offensivpotenzial. AI $aiScore, Tore-Trend $goalsScore.';
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
    final consistency = _consistencyScore([
      formScore,
      homeAwayScore,
      goalsTrendScore,
      headToHeadScore,
      tableScore,
    ]);

    return ((formScore * 0.34) +
        (homeAwayScore * 0.18) +
        (goalsTrendScore * 0.18) +
        (headToHeadScore * 0.12) +
        (tableScore * 0.14) +
        (consistency * 0.04))
        .round()
        .clamp(1, 99);
  }

  int _formScore(ProPredictionInput input) {
    final home = input.homeStats.overallFormScore;
    final away = input.awayStats.overallFormScore;
    final diff = home - away;

    if (diff.abs() <= 5) return 66;

    final stronger = diff > 0 ? home : away;
    final weaker = diff > 0 ? away : home;
    final diffBoost = (diff.abs() * 0.85).round().clamp(0, 18);

    return ((stronger * 0.66) + ((100 - weaker) * 0.22) + diffBoost)
        .round()
        .clamp(1, 99);
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
    final tableSupportsHome = tableScore >= 58;
    final tableSupportsAway = tableScore <= 42;
    final h2hSupportsHome = headToHeadScore >= 55;
    final h2hSupportsAway = headToHeadScore <= 45;
    final closeMatch = formDiff.abs() <= 5;

    // Under braucht sehr klare Signale, sonst produziert die App zu viele künstliche Under-Tipps.
    if (goalsTrendScore <= 34 && aiScore >= 66 && closeMatch) {
      return 'Unter 2.5';
    }

    // Over/BTTS nur dann bevorzugen, wenn der Tore-Trend wirklich trägt.
    if (goalsTrendScore >= 82 && aiScore >= 70) return 'Über 2.5';
    if (goalsTrendScore >= 70 && aiScore >= 66 && formDiff.abs() <= 12) {
      return 'BTTS';
    }

    // Klare 1/2-Tipps nur bei mehreren bestätigenden Signalen.
    if (formDiff >= 16 && aiScore >= 76 && (tableSupportsHome || h2hSupportsHome)) {
      return '1';
    }
    if (formDiff <= -16 && aiScore >= 76 && (tableSupportsAway || h2hSupportsAway)) {
      return '2';
    }

    // Sicherheitsmärkte, wenn Favorit vorhanden, aber nicht hart genug für 1/2.
    if (formDiff >= 8 && aiScore >= 63) return '1X';
    if (formDiff <= -8 && aiScore >= 63) return 'X2';

    // X nur bei enger Partie und ohne starken Tore-Trend.
    if (closeMatch && aiScore >= 64 && goalsTrendScore < 68) return 'X';

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

    if (goalsScore >= 82) return TipType.over25;
    if (goalsScore <= 36 && diff.abs() <= 8) return TipType.under25;
    if (diff >= 14) return TipType.homeWin;
    if (diff <= -14) return TipType.awayWin;
    if (diff.abs() <= 5 && goalsScore < 68) return TipType.draw;
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
    final signal = _mainSignalText(
      tipLabel: tipLabel,
      formScore: formScore,
      homeAwayScore: homeAwayScore,
      goalsTrendScore: goalsTrendScore,
      headToHeadScore: headToHeadScore,
      tableScore: tableScore,
    );

    return '$tipLabel empfohlen. AI $aiScore, Confidence $confidence%, Risiko $riskLevel. '
        '$signal Form $formText, Heim/Auswärts $homeAwayScore, Tore-Trend $goalsTrendScore, '
        'H2H $headToHeadScore, $tableText.';
  }

  String _mainSignalText({
    required String tipLabel,
    required int formScore,
    required int homeAwayScore,
    required int goalsTrendScore,
    required int headToHeadScore,
    required int tableScore,
  }) {
    if (tipLabel == 'Über 2.5' || tipLabel == 'BTTS') {
      return 'Hauptsignal: Tore-Trend. ';
    }
    if (tipLabel == 'Unter 2.5') {
      return 'Hauptsignal: kontrollierter Spielverlauf. ';
    }
    if (tipLabel == '1' || tipLabel == '2' || tipLabel == '1X' || tipLabel == 'X2') {
      return 'Hauptsignal: Form plus Tabellen-/H2H-Abgleich. ';
    }
    if (tipLabel == 'X') {
      return 'Hauptsignal: ausgeglichene Kräfteverhältnisse. ';
    }
    return 'Hauptsignal: Sicherheitsmarkt wegen gemischter Signale. ';
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

  bool _isPlayableMatch(FootballMatch match) {
    if (match.aiScore < 58) return false;
    if (match.riskLevel == 'Hoch' && match.aiScore < 78) return false;
    if (match.odds >= 4.20) return false;
    return true;
  }

  int _sideWinScore({
    required int ownForm,
    required int opponentForm,
    required int diff,
  }) {
    final diffScore = (50 + (diff * 1.55)).round().clamp(25, 96);
    return ((ownForm * 0.62) + ((100 - opponentForm) * 0.18) + (diffScore * 0.20))
        .round()
        .clamp(1, 99);
  }

  int _bothTeamsForm(int homeFormScore, int awayFormScore) {
    return ((homeFormScore + awayFormScore) / 2).round().clamp(1, 99);
  }

  int _oddsQualityScore(double odds) {
    if (odds <= 1.01) return 45;
    if (odds <= 1.35) return 74;
    if (odds <= 1.90) return 88;
    if (odds <= 2.35) return 80;
    if (odds <= 2.90) return 67;
    if (odds <= 3.60) return 52;
    return 38;
  }

  int _consistencyScore(List<int> values) {
    if (values.isEmpty) return 50;
    final average = values.reduce((a, b) => a + b) / values.length;
    final variance = values
        .map((value) => (value - average).abs())
        .fold<double>(0, (sum, value) => sum + value) /
        values.length;
    return (100 - (variance * 1.8)).round().clamp(35, 96);
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
