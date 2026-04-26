import '../../predictions/domain/prediction_engine.dart';
import '../domain/football_match.dart';

class MockMatchesRepository {
  const MockMatchesRepository();

  List<FootballMatch> getTodayMatches() {
    final now = DateTime.now();

    return [
      _buildMatch(
        id: 'match_001',
        league: 'Premier League',
        homeTeam: 'Manchester City',
        awayTeam: 'Arsenal',
        kickoff: DateTime(now.year, now.month, now.day, 18, 30),
        tipType: TipType.homeWin,
        tipLabel: 'Heimsieg',
        odds: 1.72,
        homeFormScore: 88,
        awayFormScore: 74,
        goalsScore: 81,
      ),
      _buildMatch(
        id: 'match_002',
        league: 'Bundesliga',
        homeTeam: 'Bayern München',
        awayTeam: 'Dortmund',
        kickoff: DateTime(now.year, now.month, now.day, 20, 30),
        tipType: TipType.over25,
        tipLabel: 'Über 2.5 Tore',
        odds: 1.64,
        homeFormScore: 82,
        awayFormScore: 76,
        goalsScore: 91,
      ),
    ];
  }

  List<FootballMatch> getTopTips() {
    return getTodayMatches()
        .where((match) => match.isStrongTip)
        .toList()
      ..sort((a, b) => b.aiScore.compareTo(a.aiScore));
  }

  FootballMatch _buildMatch({
    required String id,
    required String league,
    required String homeTeam,
    required String awayTeam,
    required DateTime kickoff,
    required TipType tipType,
    required String tipLabel,
    required double odds,
    required int homeFormScore,
    required int awayFormScore,
    required int goalsScore,
  }) {
    const engine = PredictionEngine();

    final aiScore = engine.calculateAiScore(
      homeFormScore: homeFormScore,
      awayFormScore: awayFormScore,
      goalsScore: goalsScore,
      odds: odds,
      tipType: tipType,
    );

    final riskLevel = engine.calculateRisk(
      aiScore: aiScore,
      odds: odds,
    );

    final reason = engine.buildReason(
      tipType: tipType,
      homeFormScore: homeFormScore,
      awayFormScore: awayFormScore,
      goalsScore: goalsScore,
      aiScore: aiScore,
    );

    return FootballMatch(
      id: id,
      season: DateTime.now().year,
      league: league,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      kickoff: kickoff,
      tipType: tipType,
      tipLabel: tipLabel,
      aiScore: aiScore,
      riskLevel: riskLevel,
      odds: odds,
      homeFormScore: homeFormScore,
      awayFormScore: awayFormScore,
      goalsScore: goalsScore,
      shortReason: reason,
    );
  }
}