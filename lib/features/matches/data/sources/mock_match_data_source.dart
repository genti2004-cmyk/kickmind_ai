import 'package:kickmind_ai/features/matches/data/mock_matches_repository.dart';
import 'package:kickmind_ai/features/matches/data/sources/match_data_source.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';

/// Sichere Mock-Datenquelle als Fallback/Testquelle.
/// Wird nur benutzt, wenn KickMindFeatureFlags.useRealFixtures = false ist.
class MockMatchDataSource implements MatchDataSource {
  MockMatchDataSource({MockMatchesRepository? repository})
      : _repository = repository ?? MockMatchesRepository();

  final MockMatchesRepository _repository;

  @override
  Future<List<FootballMatch>> fetchToday({bool forceRefresh = false}) async {
    return _repository.getTodayMatches();
  }

  @override
  Future<List<FootballMatch>> fetchTomorrow({bool forceRefresh = false}) async {
    final base = _repository.getTodayMatches();
    return _shiftMatches(base, const Duration(days: 1));
  }

  @override
  Future<List<FootballMatch>> fetchNext3Days({bool forceRefresh = false}) async {
    final today = _repository.getTodayMatches();
    return <FootballMatch>[
      ...today,
      ..._shiftMatches(today, const Duration(days: 1)),
      ..._shiftMatches(today, const Duration(days: 2)),
    ];
  }

  @override
  Future<List<FootballMatch>> fetchWeek({bool forceRefresh = false}) async {
    final today = _repository.getTodayMatches();
    final result = <FootballMatch>[];
    for (var i = 0; i < 7; i++) {
      result.addAll(_shiftMatches(today, Duration(days: i)));
    }
    return result;
  }

  List<FootballMatch> _shiftMatches(
      List<FootballMatch> matches,
      Duration offset,
      ) {
    return matches.map((m) {
      final shifted = m.kickoff.add(offset);
      return m.copyWith(
        id: '${m.id}_${offset.inDays}',
        kickoff: shifted,
        kickoffLabel: _formatTime(shifted),
      );
    }).toList();
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
