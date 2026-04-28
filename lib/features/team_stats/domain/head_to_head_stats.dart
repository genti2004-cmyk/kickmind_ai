class HeadToHeadStats {
  final String homeTeam;
  final String awayTeam;
  final int matches;
  final int homeWins;
  final int draws;
  final int awayWins;
  final int goalsForHome;
  final int goalsForAway;

  const HeadToHeadStats({
    required this.homeTeam,
    required this.awayTeam,
    required this.matches,
    required this.homeWins,
    required this.draws,
    required this.awayWins,
    required this.goalsForHome,
    required this.goalsForAway,
  });

  double get averageGoals {
    if (matches == 0) return 0;
    return (goalsForHome + goalsForAway) / matches;
  }
}