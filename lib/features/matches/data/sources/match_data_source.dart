import 'package:kickmind_ai/features/matches/domain/football_match.dart';

/// Gemeinsame Schnittstelle für Match-Datenquellen.
/// So kann die App später zwischen API, Cache, Mock oder Pro-Backend wechseln,
/// ohne UI-Screens umzubauen.
abstract class MatchDataSource {
  Future<List<FootballMatch>> fetchToday({bool forceRefresh = false});

  Future<List<FootballMatch>> fetchTomorrow({bool forceRefresh = false});

  Future<List<FootballMatch>> fetchNext3Days({bool forceRefresh = false});

  Future<List<FootballMatch>> fetchWeek({bool forceRefresh = false});
}
