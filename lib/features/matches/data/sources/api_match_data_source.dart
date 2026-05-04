import 'package:kickmind_ai/features/matches/data/api/football_api_service.dart';
import 'package:kickmind_ai/features/matches/data/sources/match_data_source.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';

class ApiMatchDataSource implements MatchDataSource {
  ApiMatchDataSource({FootballApiService? service})
      : _service = service ?? FootballApiService();

  final FootballApiService _service;

  @override
  Future<List<FootballMatch>> fetchToday({bool forceRefresh = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _service.fetchFixturesForRange(
      start: today,
      days: 1,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<List<FootballMatch>> fetchTomorrow({bool forceRefresh = false}) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return _service.fetchFixturesForRange(
      start: tomorrow,
      days: 1,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<List<FootballMatch>> fetchNext3Days({bool forceRefresh = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _service.fetchFixturesForRange(
      start: today,
      days: 3,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<List<FootballMatch>> fetchWeek({bool forceRefresh = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _service.fetchFixturesForRange(
      start: today,
      days: 7,
      forceRefresh: forceRefresh,
    );
  }
}
