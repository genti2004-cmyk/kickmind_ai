import 'dart:convert';

import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedTipsService {
  static const String _key = 'kickmind_saved_tips_v3';

  Future<List<FootballMatch>> loadSavedTips() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_key) ?? const <String>[];
    final result = <FootballMatch>[];
    var needsCleanup = false;

    for (final raw in rawItems) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final match = FootballMatch.fromJson(decoded);
          if (_isRealSavedMatch(match)) {
            result.add(match);
          } else {
            needsCleanup = true;
          }
        }
      } catch (_) {
        needsCleanup = true;
        // Ignore corrupted entries instead of crashing the app.
      }
    }

    if (needsCleanup) {
      await prefs.setStringList(
        _key,
        result.map((m) => jsonEncode(m.toJson())).toList(),
      );
    }

    return result;
  }

  bool _isRealSavedMatch(FootballMatch match) {
    final id = match.id.trim().toLowerCase();
    if (id.isEmpty) return false;
    if (id.startsWith('fallback_')) return false;
    if (id.startsWith('mock_')) return false;
    if (id.startsWith('match_')) return false;
    if (match.homeTeam.trim().isEmpty || match.awayTeam.trim().isEmpty) return false;
    return true;
  }

  Future<bool> isSaved(String matchId) async {
    final items = await loadSavedTips();
    return items.any((m) => m.id == matchId);
  }

  Future<void> saveTip(FootballMatch match) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await loadSavedTips();

    final updated = items.where((m) => m.id != match.id).toList()
      ..insert(0, match);

    await prefs.setStringList(
      _key,
      updated.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  Future<void> removeTip(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await loadSavedTips();
    final updated = items.where((m) => m.id != matchId).toList();

    await prefs.setStringList(
      _key,
      updated.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  Future<void> clearSavedTips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
