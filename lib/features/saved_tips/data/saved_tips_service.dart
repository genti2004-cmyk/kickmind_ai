import 'dart:convert';

import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedTipsService {
  static const String _key = 'kickmind_saved_tips_v3';

  Future<List<FootballMatch>> loadSavedTips() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_key) ?? const <String>[];
    final result = <FootballMatch>[];

    for (final raw in rawItems) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          result.add(FootballMatch.fromJson(decoded));
        }
      } catch (_) {
        // Ignore corrupted entries instead of crashing the app.
      }
    }

    return result;
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
