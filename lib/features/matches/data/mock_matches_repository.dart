import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';

class MockMatchesRepository {
  final PredictionEngine _engine = const PredictionEngine();

   List<FootballMatch> getTodayMatches() {
    final now = DateTime.now();

    return [
      _engine.buildMatch(
        id: 'match_001',
        league: 'Premier League',
        home: 'Manchester City',
        away: 'Arsenal',
        kickoff: DateTime(now.year, now.month, now.day, 18, 30),
        tipType: TipType.homeWin,
        odds: 1.72,
        homeFormScore: 88,
        awayFormScore: 74,
        goalsScore: 81,
      ),
      _engine.buildMatch(
        id: 'match_002',
        league: 'Bundesliga',
        home: 'Bayern München',
        away: 'Dortmund',
        kickoff: DateTime(now.year, now.month, now.day, 20, 30),
        tipType: TipType.over25,
        odds: 1.64,
        homeFormScore: 82,
        awayFormScore: 76,
        goalsScore: 91,
      ),
      _engine.buildMatch(
        id: 'match_003',
        league: 'La Liga',
        home: 'Real Madrid',
        away: 'Barcelona',
        kickoff: DateTime(now.year, now.month, now.day, 21, 00),
        tipType: TipType.btts,
        odds: 1.82,
        homeFormScore: 84,
        awayFormScore: 83,
        goalsScore: 86,
      ),
    ];
  }

  List<FootballMatch> getTopTips() {
    return _engine.rankTopTips(getTodayMatches(), limit: 5);
  }
}
