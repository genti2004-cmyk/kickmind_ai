import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';

abstract class MatchRepository {
  Future<List<FootballMatch>> getMatches({
    MatchDateRange range = MatchDateRange.today,
  });

  Future<List<FootballMatch>> getTodayMatches() {
    return getMatches(range: MatchDateRange.today);
  }
}
