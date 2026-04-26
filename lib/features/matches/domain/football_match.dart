enum TipType {
  homeWin,
  draw,
  awayWin,
  doubleChance,
  over25,
  under25,
  bothTeamsScore,
}

enum RiskLevel {
  low,
  medium,
  high,
}

class FootballMatch {
  final String id;
  final int? fixtureId;
  final int? leagueId;
  final int? homeTeamId;
  final int? awayTeamId;
  final int season;

  final String league;
  final String homeTeam;
  final String awayTeam;
  final DateTime kickoff;

  final TipType tipType;
  final String tipLabel;
  final int aiScore;
  final RiskLevel riskLevel;
  final double odds;

  final int homeFormScore;
  final int awayFormScore;
  final int goalsScore;
  final String shortReason;

  const FootballMatch({
    required this.id,
    this.fixtureId,
    this.leagueId,
    this.homeTeamId,
    this.awayTeamId,
    required this.season,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoff,
    required this.tipType,
    required this.tipLabel,
    required this.aiScore,
    required this.riskLevel,
    required this.odds,
    required this.homeFormScore,
    required this.awayFormScore,
    required this.goalsScore,
    required this.shortReason,
  });

  bool get isTopTip => aiScore >= 75;

  String get riskLabel {
    switch (riskLevel) {
      case RiskLevel.low:
        return 'Niedrig';
      case RiskLevel.medium:
        return 'Mittel';
      case RiskLevel.high:
        return 'Hoch';
    }
  }
}