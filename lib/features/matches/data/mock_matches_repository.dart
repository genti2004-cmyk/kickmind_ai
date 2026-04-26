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
      _buildMatch(
        id: 'match_003',
        league: 'La Liga',
        homeTeam: 'Real Madrid',
        awayTeam: 'Valencia',
        kickoff: DateTime(now.year, now.month, now.day, 21, 00),
        tipType: TipType.doubleChance,
        tipLabel: '1X',
        odds: 1.28,
        homeFormScore: 86,
        awayFormScore: 61,
        goalsScore: 70,
      ),
      _buildMatch(
        id: 'match_004',
        league: 'Serie A',
        homeTeam: 'Inter Mailand',
        awayTeam: 'Lazio Rom',
        kickoff: DateTime(now.year, now.month, now.day, 19, 45),
        tipType: TipType.bothTeamsScore,
        tipLabel: 'Beide treffen',
        odds: 1.83,
        homeFormScore: 77,
        awayFormScore: 72,
        goalsScore: 84,
      ),
      _buildMatch(
        id: 'match_005',
        league: 'Ligue 1',
        homeTeam: 'PSG',
        awayTeam: 'Lille',
        kickoff: DateTime(now.year, now.month, now.day, 17, 00),
        tipType: TipType.homeWin,
        tipLabel: 'Heimsieg',
        odds: 1.58,
        homeFormScore: 80,
        awayFormScore: 68,
        goalsScore: 73,
      ),
    ];
  }

  List<FootballMatch> getTopTips() {
    return getTodayMatches()
        .where((match) => match.isTopTip)
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