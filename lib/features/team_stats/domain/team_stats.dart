class TeamStats {
  final String teamName;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int homeFormScore;
  final int awayFormScore;
  final int overallFormScore;
  final List<String> lastResults;

  const TeamStats({
    required this.teamName,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.homeFormScore,
    required this.awayFormScore,
    required this.overallFormScore,
    required this.lastResults,
  });

  int get goalDifference => goalsFor - goalsAgainst;

  double get goalsForPerGame => played == 0 ? 0 : goalsFor / played;

  double get goalsAgainstPerGame => played == 0 ? 0 : goalsAgainst / played;
}