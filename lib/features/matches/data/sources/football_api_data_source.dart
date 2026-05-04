import 'package:kickmind_ai/features/matches/data/api/football_api_service.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';

class FootballApiDataSource {
  final FootballApiService _service;

  FootballApiDataSource({FootballApiService? service})
      : _service = service ?? FootballApiService();

  Future<List<FootballMatch>> getTodayMatches({bool forceRefresh = false}) {
    return _service.fetchTodayFixtures(forceRefresh: forceRefresh);
  }

  Future<List<FootballMatch>> getFixturesForRange({
    required DateTime start,
    required int days,
    bool forceRefresh = false,
  }) {
    return _service.fetchFixturesForRange(
      start: start,
      days: days,
      forceRefresh: forceRefresh,
    );
  }
}
