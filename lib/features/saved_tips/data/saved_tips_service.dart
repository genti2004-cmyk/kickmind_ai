import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/saved_tip.dart';

class SavedTipsService {
  static const String _key = 'saved_tips_v1';

  const SavedTipsService();

  Future<List<SavedTip>> loadTips() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? [];

    return rawList
        .map((raw) => SavedTip.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  Future<void> saveTip(SavedTip tip) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? [];

    current.removeWhere((raw) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['id']?.toString() == tip.id;
    });

    current.add(jsonEncode(tip.toJson()));
    await prefs.setStringList(_key, current);
  }

  Future<void> updateResult(String id, TipResult result) async {
    final tips = await loadTips();

    final updated = tips.map((tip) {
      if (tip.id == id) {
        return tip.copyWith(result: result);
      }
      return tip;
    }).toList();

    await _saveAll(updated);
  }

  Future<void> deleteTip(String id) async {
    final tips = await loadTips();
    final updated = tips.where((tip) => tip.id != id).toList();

    await _saveAll(updated);
  }

  Future<void> _saveAll(List<SavedTip> tips) async {
    final prefs = await SharedPreferences.getInstance();

    final rawList = tips
        .map((tip) => jsonEncode(tip.toJson()))
        .toList();

    await prefs.setStringList(_key, rawList);
  }
}