import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/pro_prediction_input.dart';

class PredictionEngine {
  const PredictionEngine();

  FootballMatch buildProMatch(ProPredictionInput input) {
    final match = input.match;

    final formScore = _weighted(
      input.homeStats.overallFormScore,
      input.awayStats.overallFormScore,
      0.55,
    );

    final homePower = input.homeAdvantageScore;
    final goalsTrend = input.goalsTrendScore;
    final tablePower = input.tableAdvantageScore;
    final h2hPower = input.headToHeadScore;

    final aiScore = ((formScore * 0.30) +
        (homePower * 0.25) +
        (goalsTrend * 0.20) +
        (tablePower * 0.15) +
        (h2hPower * 0.10))
        .round()
        .clamp(1, 99);

    final tipLabel = _proTipLabel(
      input: input,
      aiScore: aiScore,
      goalsTrend: goalsTrend,
    );

    final tipType = _mapLabelToTipType(tipLabel);
    final odds = estimateOdds(tipType);
    final risk = calculateRisk(aiScore: aiScore, odds: odds);

    return match.copyWith(
      tipType: tipType,
      tipLabel: tipLabel,
      aiScore: aiScore,
      riskLevel: risk,
      odds: odds,
      homeFormScore: input.homeStats.overallFormScore,
      awayFormScore: input.awayStats.overallFormScore,
      goalsScore: goalsTrend,
      shortReason: buildProReason(
        tipLabel: tipLabel,
        aiScore: aiScore,
        input: input,
      ),
    );
  }

  String buildProReason({
    required String tipLabel,
    required int aiScore,
    required ProPredictionInput input,
  }) {
    return '$tipLabel: AI $aiScore. '
        'Form ${input.homeStats.overallFormScore}:${input.awayStats.overallFormScore}, '
        'Heimvorteil ${input.homeAdvantageScore}, '
        'Tore-Trend ${input.goalsTrendScore}, '
        'Tabelle ${input.tableAdvantageScore}, '
        'Direkte Duelle ${input.headToHeadScore}.';
  }

  String _proTipLabel({
    required ProPredictionInput input,
    required int aiScore,
    required int goalsTrend,
  }) {
    final formDiff = input.formDifference;
    final tableScore = input.tableAdvantageScore;
    final h2h = input.headToHeadScore;

    if (goalsTrend >= 76) return 'Über 2.5';
    if (goalsTrend <= 38) return 'Unter 2.5';

    if (formDiff >= 16 && tableScore >= 58) return '1';
    if (formDiff <= -16 && tableScore <= 42) return '2';

    if (formDiff >= 7 && h2h >= 50) return '1X';
    if (formDiff <= -7 && h2h <= 50) return 'X2';

    if (formDiff.abs() <= 6) return 'X';

    return goalsTrend >= 62 ? 'BTTS' : '12';
  }

  TipType _mapLabelToTipType(String label) {
    switch (label) {
      case '1':
      case '1X':
        return TipType.homeWin;
      case '2':
      case 'X2':
        return TipType.awayWin;
      case 'X':
        return TipType.draw;
      case 'Über 2.5':
        return TipType.over25;
      case 'Unter 2.5':
        return TipType.under25;
      case 'BTTS':
        return TipType.btts;
      case '12':
        return TipType.homeWin;
      default:
        return TipType.homeWin;
    }
  }

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

    final resolvedOdds = odds ?? estimateOdds(resolvedTipType);

    final aiScore = calculateAiScore(
      homeFormScore: resolvedHomeForm,
      awayFormScore: resolvedAwayForm,
      goalsScore: resolvedGoalsScore,
      odds: resolvedOdds,
      tipType: resolvedTipType,
    );

    final risk = calculateRisk(aiScore: aiScore, odds: resolvedOdds);

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
      tipLabel: tipLabel(resolvedTipType),
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
      TipType.draw => (100 - (homeFormScore - awayFormScore).abs()).clamp(40, 95),
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
  }) {
    if (aiScore >= 82 && odds <= 1.90) return 'Niedrig';
    if (aiScore >= 70 && odds <= 2.40) return 'Mittel';
    return 'Hoch';
  }

  String buildReason({
    required TipType tipType,
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
    required int aiScore,
  }) {
    final tip = tipLabel(tipType);
    return '$tip: AI $aiScore. Form $homeFormScore:$awayFormScore, Tore-Score $goalsScore.';
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

  double estimateOdds(TipType type) {
    switch (type) {
      case TipType.homeWin:
        return 1.78;
      case TipType.draw:
        return 3.20;
      case TipType.awayWin:
        return 2.15;
      case TipType.over25:
        return 1.85;
      case TipType.under25:
        return 1.95;
      case TipType.btts:
        return 1.82;
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

  int _stableScore(String seed, {required int min, required int max}) {
    final hash = seed.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return min + (hash % (max - min + 1));
  }

  int _weighted(int home, int away, double homeWeight) {
    return ((home * homeWeight) + (away * (1 - homeWeight))).round();
  }

  String _formatKickoff(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}