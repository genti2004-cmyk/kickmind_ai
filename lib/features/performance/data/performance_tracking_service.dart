import 'dart:convert';

import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/performance/domain/performance_summary.dart';
import 'package:kickmind_ai/features/performance/domain/tracked_tip.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PerformanceTrackingService {
  static const String _key = 'kickmind_performance_tracked_tips_v1';

  Future<List<TrackedTip>> loadTrackedTips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    return raw
        .map((item) {
      try {
        return TrackedTip.fromJson(jsonDecode(item) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    })
        .whereType<TrackedTip>()
        .toList();
  }

  Future<void> trackTip(FootballMatch match, {double stake = 1.0}) async {
    final tips = await loadTrackedTips();
    tips.removeWhere((t) => t.match.id == match.id);
    tips.insert(
      0,
      TrackedTip(
        match: match,
        savedAt: DateTime.now(),
        stake: stake,
      ),
    );
    await _save(tips);
  }

  Future<bool> isTracked(String matchId) async {
    final tips = await loadTrackedTips();
    return tips.any((t) => t.match.id == matchId);
  }

  Future<void> removeTrackedTip(String matchId) async {
    final tips = await loadTrackedTips();
    tips.removeWhere((t) => t.match.id == matchId);
    await _save(tips);
  }

  Future<void> updateStatus(String matchId, TipResultStatus status) async {
    final tips = await loadTrackedTips();
    final index = tips.indexWhere((t) => t.match.id == matchId);
    if (index == -1) return;
    tips[index] = tips[index].copyWith(status: status);
    await _save(tips);
  }

  Future<PerformanceSummary> loadSummary() async {
    final tips = await loadTrackedTips();
    return PerformanceSummary.fromTips(tips);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _save(List<TrackedTip> tips) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = tips.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }
}
