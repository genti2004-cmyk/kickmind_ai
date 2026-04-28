class LeagueStanding {
  final String teamName;
  final int position;
  final int points;
  final int played;
  final int goalDifference;

  const LeagueStanding({
    required this.teamName,
    required this.position,
    required this.points,
    required this.played,
    required this.goalDifference,
  });
}