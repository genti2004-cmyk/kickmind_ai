import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/team_stats/domain/head_to_head_stats.dart';
import 'package:kickmind_ai/features/team_stats/domain/league_standing.dart';
import 'package:kickmind_ai/features/team_stats/domain/team_stats.dart';

class ProPredictionInput {
  final FootballMatch match;
  final TeamStats homeStats;
  final TeamStats awayStats;
  final HeadToHeadStats headToHead;
  final LeagueStanding? homeStanding;
  final LeagueStanding? awayStanding;

  const ProPredictionInput({
    required this.match,
    required this.homeStats,
    required this.awayStats,
    required this.headToHead,
    this.homeStanding,
    this.awayStanding,
  });

  int get formDifference =>
      homeStats.overallFormScore - awayStats.overallFormScore;

  int get homeAdvantageScore =>
      ((homeStats.homeFormScore * 0.65) +
          (awayStats.awayFormScore * 0.35))
          .round();

  int get goalsTrendScore {
    final total =
        homeStats.goalsForPerGame +
            awayStats.goalsForPerGame +
            homeStats.goalsAgainstPerGame +
            awayStats.goalsAgainstPerGame;

    return (total * 18).round().clamp(1, 99);
  }

  int get tableAdvantageScore {
    if (homeStanding == null || awayStanding == null) return 50;

    final diff = awayStanding!.position - homeStanding!.position;
    return (50 + diff * 3).clamp(1, 99);
  }

  int get headToHeadScore {
    if (headToHead.matches == 0) return 50;

    final homePower =
        (headToHead.homeWins * 3) + headToHead.draws - headToHead.awayWins;

    return (50 + homePower * 4).clamp(1, 99);
  }
}