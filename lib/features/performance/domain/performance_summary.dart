import 'tracked_tip.dart';

class PerformanceSummary {
  final int total;
  final int pending;
  final int won;
  final int lost;
  final int voided;
  final double totalStake;
  final double profit;

  const PerformanceSummary({
    required this.total,
    required this.pending,
    required this.won,
    required this.lost,
    required this.voided,
    required this.totalStake,
    required this.profit,
  });

  int get settled => won + lost;

  double get hitRate {
    if (settled == 0) return 0;
    return won / settled * 100;
  }

  double get roi {
    if (totalStake == 0) return 0;
    return profit / totalStake * 100;
  }

  static PerformanceSummary fromTips(List<TrackedTip> tips) {
    final won = tips.where((t) => t.status == TipResultStatus.won).length;
    final lost = tips.where((t) => t.status == TipResultStatus.lost).length;
    final pending = tips.where((t) => t.status == TipResultStatus.pending).length;
    final voided = tips.where((t) => t.status == TipResultStatus.voided).length;
    final settledTips = tips.where((t) => t.status == TipResultStatus.won || t.status == TipResultStatus.lost);
    final stake = settledTips.fold<double>(0, (sum, t) => sum + t.stake);
    final profit = tips.fold<double>(0, (sum, t) => sum + t.profit);

    return PerformanceSummary(
      total: tips.length,
      pending: pending,
      won: won,
      lost: lost,
      voided: voided,
      totalStake: stake,
      profit: profit,
    );
  }
}
