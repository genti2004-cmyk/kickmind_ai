import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/performance/data/performance_tracking_service.dart';
import 'package:kickmind_ai/features/performance/domain/performance_summary.dart';
import 'package:kickmind_ai/features/performance/domain/tracked_tip.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final PerformanceTrackingService _service = PerformanceTrackingService();
  late Future<List<TrackedTip>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.loadTrackedTips();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.loadTrackedTips();
    });
  }

  Future<void> _setStatus(TrackedTip tip, TipResultStatus status) async {
    await _service.updateStatus(tip.match.id, status);
    await _reload();
  }

  Future<void> _removeTip(TrackedTip tip) async {
    await _service.removeTrackedTip(tip.match.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<TrackedTip>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingState();
          }

          final tips = snapshot.data ?? <TrackedTip>[];
          if (tips.isEmpty) {
            return const _EmptyState();
          }

          final summary = PerformanceSummary.fromTips(tips);
          final insights = _PerformanceInsights.fromTips(tips);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _PerformanceHero(summary: summary),
                const SizedBox(height: 14),
                _SummaryGrid(summary: summary),
                const SizedBox(height: 14),
                _InsightPanel(insights: insights),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Getrackte Tipps',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _SmallPill(
                      text: '${tips.length} Tipps',
                      color: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...tips.map(
                      (tip) => _TrackedTipCard(
                    tip: tip,
                    onStatusChanged: (status) => _setStatus(tip, status),
                    onRemove: () => _removeTip(tip),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PerformanceHero extends StatelessWidget {
  final PerformanceSummary summary;

  const _PerformanceHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    final profitColor = summary.profit >= 0 ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade500,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deine Tipp-Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.settled == 0
                ? 'Noch keine ausgewerteten Tipps. Markiere Tipps als gewonnen oder verloren.'
                : 'Trefferquote ${summary.hitRate.toStringAsFixed(1)}% bei ${summary.settled} ausgewerteten Tipps.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Trefferquote',
                  value: '${summary.hitRate.toStringAsFixed(1)}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Profit',
                  value: '${summary.profit >= 0 ? '+' : ''}${summary.profit.toStringAsFixed(2)}',
                  valueColor: profitColor == Colors.green ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _HeroMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final PerformanceSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.analytics_rounded,
                label: 'ROI',
                value: '${summary.roi.toStringAsFixed(1)}%',
                color: summary.roi >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                icon: Icons.sports_score_rounded,
                label: 'Ausgewertet',
                value: '${summary.settled}',
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.check_circle_rounded,
                label: 'Gewonnen',
                value: '${summary.won}',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                icon: Icons.cancel_rounded,
                label: 'Verloren',
                value: '${summary.lost}',
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                icon: Icons.hourglass_top_rounded,
                label: 'Offen',
                value: '${summary.pending}',
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  final _PerformanceInsights insights;

  const _InsightPanel({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analyse-Insights',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _InsightRow(label: 'Beste Liga', value: insights.bestLeague),
          const SizedBox(height: 8),
          _InsightRow(label: 'Beste Tippart', value: insights.bestTipLabel),
          const SizedBox(height: 8),
          _InsightRow(label: 'Ø AI Score', value: insights.avgAiScoreText),
          const SizedBox(height: 8),
          _InsightRow(label: 'Starke Tipps', value: '${insights.strongTips} mit AI ≥ 80'),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;

  const _InsightRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _TrackedTipCard extends StatelessWidget {
  final TrackedTip tip;
  final ValueChanged<TipResultStatus> onStatusChanged;
  final VoidCallback onRemove;

  const _TrackedTipCard({
    required this.tip,
    required this.onStatusChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (tip.status) {
      TipResultStatus.won => Colors.green,
      TipResultStatus.lost => Colors.red,
      TipResultStatus.voided => Colors.grey,
      TipResultStatus.pending => Colors.orange,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.match.teamsLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip.match.league,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SmallPill(text: tip.status.label, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallPill(text: 'Tipp ${tip.match.tipLabel}', color: Colors.blue),
              _SmallPill(text: 'AI ${tip.match.aiScore}', color: _scoreColor(tip.match.aiScore)),
              _SmallPill(text: '${tip.match.riskEmoji} ${tip.match.riskLevel}', color: _riskColor(tip.match.riskLevel)),
              _SmallPill(text: 'Quote ${tip.match.odds.toStringAsFixed(2)}', color: Colors.indigo),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProfitBox(
                  label: 'Einsatz',
                  value: tip.stake.toStringAsFixed(2),
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfitBox(
                  label: 'Möglicher Return',
                  value: tip.possibleReturn.toStringAsFixed(2),
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfitBox(
                  label: 'Profit',
                  value: '${tip.profit >= 0 ? '+' : ''}${tip.profit.toStringAsFixed(2)}',
                  color: tip.profit >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusButton(
                label: 'Gewonnen',
                icon: Icons.check_rounded,
                color: Colors.green,
                onPressed: () => onStatusChanged(TipResultStatus.won),
              ),
              _StatusButton(
                label: 'Verloren',
                icon: Icons.close_rounded,
                color: Colors.red,
                onPressed: () => onStatusChanged(TipResultStatus.lost),
              ),
              _StatusButton(
                label: 'Offen',
                icon: Icons.hourglass_top_rounded,
                color: Colors.orange,
                onPressed: () => onStatusChanged(TipResultStatus.pending),
              ),
              _StatusButton(
                label: 'Löschen',
                icon: Icons.delete_outline_rounded,
                color: Colors.grey,
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _scoreColor(int score) {
    if (score >= 82) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  static Color _riskColor(String risk) {
    final value = risk.toLowerCase();
    if (value.contains('niedrig') || value.contains('low')) return Colors.green;
    if (value.contains('mittel') || value.contains('medium')) return Colors.orange;
    return Colors.red;
  }
}

class _ProfitBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProfitBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PerformanceInsights {
  final String bestLeague;
  final String bestTipLabel;
  final String avgAiScoreText;
  final int strongTips;

  const _PerformanceInsights({
    required this.bestLeague,
    required this.bestTipLabel,
    required this.avgAiScoreText,
    required this.strongTips,
  });

  factory _PerformanceInsights.fromTips(List<TrackedTip> tips) {
    final wonTips = tips.where((t) => t.status == TipResultStatus.won).toList();
    final source = wonTips.isNotEmpty ? wonTips : tips;

    return _PerformanceInsights(
      bestLeague: _mostCommon(source.map((t) => t.match.league), fallback: '-'),
      bestTipLabel: _mostCommon(source.map((t) => t.match.tipLabel), fallback: '-'),
      avgAiScoreText: _averageAi(tips),
      strongTips: tips.where((t) => t.match.aiScore >= 80).length,
    );
  }

  static String _mostCommon(Iterable<String> values, {required String fallback}) {
    final counts = <String, int>{};
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    if (counts.isEmpty) return fallback;

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  static String _averageAi(List<TrackedTip> tips) {
    if (tips.isEmpty) return '-';
    final total = tips.fold<int>(0, (sum, t) => sum + t.match.aiScore);
    return (total / tips.length).toStringAsFixed(1);
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: const [
        _Skeleton(height: 150),
        SizedBox(height: 12),
        _Skeleton(height: 82),
        SizedBox(height: 12),
        _Skeleton(height: 82),
        SizedBox(height: 12),
        _Skeleton(height: 180),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;

  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Colors.blue,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Noch keine Performance-Daten',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Speichere einen Tipp und markiere später, ob er gewonnen oder verloren hat. Danach siehst du Trefferquote, ROI und deine besten Tipparten.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
