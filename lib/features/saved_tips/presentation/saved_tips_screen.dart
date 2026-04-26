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
  final service = const SavedTipsService();

  Future<List<SavedTip>>? futureTips;

  @override
  void initState() {
    super.initState();
    futureTips = service.loadTips();
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tips.length,
            itemBuilder: (context, index) {
              final tip = tips[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SavedTipCard(
                  tip: tip,
                  onDelete: () async {
                    await service.deleteTip(tip.id);
                    reload();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedTipCard extends StatelessWidget {
  final SavedTip tip;
  final VoidCallback onDelete;

  const _SavedTipCard({
    required this.tip,
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Löschen'),
            ),
          ),
        ],
      ),
    );
  }
}