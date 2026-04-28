import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/pro_prediction_input.dart';
import 'package:kickmind_ai/features/team_stats/domain/head_to_head_stats.dart';
import 'package:kickmind_ai/features/team_stats/domain/league_standing.dart';
import 'package:kickmind_ai/features/team_stats/domain/team_stats.dart';

class MockTeamStatsRepository {
  const MockTeamStatsRepository();

  ProPredictionInput buildInput(FootballMatch match) {
    final homeStats = buildTeamStats(
      teamName: match.homeTeam,
      isHome: true,
    );

    final awayStats = buildTeamStats(
      teamName: match.awayTeam,
      isHome: false,
    );

    final h2h = buildHeadToHead(
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
    );

    final homeStanding = buildStanding(match.homeTeam);
    final awayStanding = buildStanding(match.awayTeam);

    return ProPredictionInput(
      match: match,
      homeStats: homeStats,
      awayStats: awayStats,
      headToHead: h2h,
      homeStanding: homeStanding,
      awayStanding: awayStanding,
    );
  }

  List<ProPredictionInput> buildInputs(List<FootballMatch> matches) {
    return matches.map(buildInput).toList();
  }

  TeamStats buildTeamStats({
    required String teamName,
    required bool isHome,
  }) {
    final base = _stableScore(teamName, min: 45, max: 88);
    final played = 10;

    final wins = (base / 18).round().clamp(1, 8);
    final draws = ((100 - base) / 25).round().clamp(0, 5);
    final losses = (played - wins - draws).clamp(0, played);

    final goalsFor = (base / 6).round().clamp(7, 24);
    final goalsAgainst = ((100 - base) / 7).round().clamp(4, 20);

    final homeBoost = isHome ? 6 : 0;
    final awayPenalty = isHome ? 0 : -4;

    final homeForm = (base + homeBoost).clamp(1, 99);
    final awayForm = (base + awayPenalty).clamp(1, 99);

    return TeamStats(
      teamName: teamName,
      played: played,
      wins: wins,
      draws: draws,
      losses: losses,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      homeFormScore: homeForm,
      awayFormScore: awayForm,
      overallFormScore: base,
      lastResults: _buildLastResults(base),
    );
  }

  HeadToHeadStats buildHeadToHead({
    required String homeTeam,
    required String awayTeam,
  }) {
    final seed = _stableScore('$homeTeam-$awayTeam-h2h', min: 35, max: 85);

    final matches = 5;
    final homeWins = (seed / 28).round().clamp(0, 4);
    final draws = ((100 - seed) / 35).round().clamp(0, 3);
    final awayWins = (matches - homeWins - draws).clamp(0, matches);

    final goalsForHome = (seed / 12).round().clamp(2, 12);
    final goalsForAway = ((100 - seed) / 13).round().clamp(1, 10);

    return HeadToHeadStats(
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      matches: matches,
      homeWins: homeWins,
      draws: draws,
      awayWins: awayWins,
      goalsForHome: goalsForHome,
      goalsForAway: goalsForAway,
    );
  }

  LeagueStanding buildStanding(String teamName) {
    final strength = _stableScore('$teamName-standing', min: 1, max: 18);

    final position = strength;
    final played = 20;
    final points = (60 - position * 2).clamp(12, 58);
    final goalDifference = (22 - position).clamp(-20, 25);

    return LeagueStanding(
      teamName: teamName,
      position: position,
      points: points,
      played: played,
      goalDifference: goalDifference,
    );
  }

  List<String> _buildLastResults(int base) {
    if (base >= 78) return const ['W', 'W', 'D', 'W', 'W'];
    if (base >= 65) return const ['W', 'D', 'W', 'L', 'W'];
    if (base >= 52) return const ['D', 'W', 'L', 'D', 'W'];
    return const ['L', 'D', 'L', 'W', 'L'];
  }

  int _stableScore(String seed, {required int min, required int max}) {
    final hash = seed.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return min + (hash % (max - min + 1));
  }
}