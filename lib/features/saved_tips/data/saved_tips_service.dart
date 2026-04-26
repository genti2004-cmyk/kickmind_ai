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

  Future<void> deleteTip(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? [];

    current.removeWhere((raw) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['id']?.toString() == id;
    });

    await prefs.setStringList(_key, current);
  }
}