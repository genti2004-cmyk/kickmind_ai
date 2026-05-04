class LiveOdds {
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  final double homeWin;
  final double draw;
  final double awayWin;
  final double? over25;
  final double? under25;
  final double? bttsYes;
  final String bookmaker;
  final DateTime updatedAt;

  const LiveOdds({
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeWin,
    required this.draw,
    required this.awayWin,
    this.over25,
    this.under25,
    this.bttsYes,
    required this.bookmaker,
    required this.updatedAt,
  });

  double oddsForTip(String tipLabel) {
    switch (tipLabel) {
      case '1':
      case '1X':
        return homeWin;
      case 'X':
        return draw;
      case '2':
      case 'X2':
        return awayWin;
      case 'Über 2.5':
      case 'Over 2.5':
        return over25 ?? 1.0;
      case 'Unter 2.5':
      case 'Under 2.5':
        return under25 ?? 1.0;
      case 'BTTS':
        return bttsYes ?? 1.0;
      case '12':
        return homeWin > awayWin ? awayWin : homeWin;
      default:
        return homeWin;
    }
  }
}
