import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/saved_tips_service.dart';
import '../domain/saved_tip.dart';

class SavedTipsScreen extends StatefulWidget {
  const SavedTipsScreen({super.key});

  @override
  State<SavedTipsScreen> createState() => _SavedTipsScreenState();
}

class _SavedTipsScreenState extends State<SavedTipsScreen> {
  final SavedTipsService service = const SavedTipsService();

  Future<List<SavedTip>>? futureTips;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    setState(() {
      futureTips = service.loadTips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Meine Tipps')),
      body: FutureBuilder<List<SavedTip>>(
        future: futureTips,
        builder: (context, snapshot) {
          final tips = snapshot.data ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tips.isEmpty) {
            return const Center(
              child: Text(
                'Noch keine Tipps gespeichert',
                style: TextStyle(color: AppTheme.text),
              ),
            );
          }

          final totalStake = tips.fold<double>(0, (sum, tip) => sum + tip.stake);
          final totalProfit = tips.fold<double>(0, (sum, tip) => sum + tip.profit);
          final won = tips.where((tip) => tip.result == TipResult.won).length;
          final lost = tips.where((tip) => tip.result == TipResult.lost).length;
          final open = tips.where((tip) => tip.result == TipResult.open).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _StatsHeader(
                totalStake: totalStake,
                totalProfit: totalProfit,
                won: won,
                lost: lost,
                open: open,
              ),
              const SizedBox(height: 16),
              ...tips.map(
                    (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SavedTipCard(
                    tip: tip,
                    onWon: () async {
                      await service.updateResult(tip.id, TipResult.won);
                      reload();
                    },
                    onLost: () async {
                      await service.updateResult(tip.id, TipResult.lost);
                      reload();
                    },
                    onOpen: () async {
                      await service.updateResult(tip.id, TipResult.open);
                      reload();
                    },
                    onDelete: () async {
                      await service.deleteTip(tip.id);
                      reload();
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final double totalStake;
  final double totalProfit;
  final int won;
  final int lost;
  final int open;

  const _StatsHeader({
    required this.totalStake,
    required this.totalProfit,
    required this.won,
    required this.lost,
    required this.open,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF063A68),
            Color(0xFF0B1B2E),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipp-Tracking',
            style: TextStyle(
              color: AppTheme.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Einsatz',
                  value: '${totalStake.toStringAsFixed(2)} €',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  label: 'Profit',
                  value: '${totalProfit.toStringAsFixed(2)} €',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _StatBox(label: 'Gewonnen', value: '$won')),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: 'Verloren', value: '$lost')),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: 'Offen', value: '$open')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.blue.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedTipCard extends StatelessWidget {
  final SavedTip tip;
  final VoidCallback onWon;
  final VoidCallback onLost;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _SavedTipCard({
    required this.tip,
    required this.onWon,
    required this.onLost,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.blue.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusRow(tip: tip),
          const SizedBox(height: 10),
          Text(
            tip.league,
            style: const TextStyle(
              color: AppTheme.blue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${tip.homeTeam} vs ${tip.awayTeam}',
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${tip.tipLabel} · ${tip.aiScore}% · Quote ${tip.odds.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Einsatz ${tip.stake.toStringAsFixed(2)} € · Auszahlung ${tip.payout.toStringAsFixed(2)} € · Profit ${tip.profit.toStringAsFixed(2)} €',
            style: const TextStyle(
              color: AppTheme.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ResultButton(
                  label: 'Gewonnen',
                  onPressed: onWon,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultButton(
                  label: 'Verloren',
                  onPressed: onLost,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ResultButton(
                  label: 'Offen',
                  onPressed: onOpen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Löschen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final SavedTip tip;

  const _StatusRow({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bookmark_rounded, color: AppTheme.blue, size: 18),
        const SizedBox(width: 6),
        Text(
          tip.resultLabel,
          style: const TextStyle(
            color: AppTheme.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          '${tip.savedAt.day.toString().padLeft(2, '0')}.${tip.savedAt.month.toString().padLeft(2, '0')}.${tip.savedAt.year}',
          style: const TextStyle(
            color: AppTheme.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ResultButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ResultButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.card,
        foregroundColor: AppTheme.text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(label),
    );
  }
}