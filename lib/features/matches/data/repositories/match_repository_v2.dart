import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';

/// Kompatibilitätsklasse für alte Screens/Imports.
/// Neue Screens sollen direkt MatchRepositoryImpl nutzen.
class MatchRepositoryV2 {
  MatchRepositoryV2({MatchRepositoryImpl? repository})
      : _repository = repository ?? MatchRepositoryImpl();

  final MatchRepositoryImpl _repository;

  Future<List<FootballMatch>> fetchToday({bool forceRefresh = false}) {
    return _repository.getMatches(range: MatchDateRange.today);
  }

  Future<List<FootballMatch>> fetchTomorrow({bool forceRefresh = false}) {
    return _repository.getMatches(range: MatchDateRange.tomorrow);
  }

  Future<List<FootballMatch>> fetchNext3Days({bool forceRefresh = false}) {
    return _repository.getMatches(range: MatchDateRange.next3Days);
  }

  Future<List<FootballMatch>> fetchWeek({bool forceRefresh = false}) {
    return _repository.getMatches(range: MatchDateRange.next7Days);
  }
}
