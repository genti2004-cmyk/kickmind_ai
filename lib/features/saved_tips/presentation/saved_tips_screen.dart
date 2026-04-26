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
              child: Text('Noch keine Tipps gespeichert'),
            );
          }

          // 🔥 Ranking Logik
          final ranked = [...tips]
            ..sort((a, b) {
              // 1. offene zuerst
              if (a.result == TipResult.open && b.result != TipResult.open) {
                return -1;
              }
              if (b.result == TipResult.open && a.result != TipResult.open) {
                return 1;
              }

              // 2. gewonnene vor verlorenen
              if (a.result == TipResult.won && b.result == TipResult.lost) {
                return -1;
              }
              if (b.result == TipResult.won && a.result == TipResult.lost) {
                return 1;
              }

              // 3. AI Score
              final scoreCompare = b.aiScore.compareTo(a.aiScore);
              if (scoreCompare != 0) return scoreCompare;

              // 4. bessere Quote
              return a.odds.compareTo(b.odds);
            });

          final bestTips = ranked.take(3).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '🏆 Beste Tipps',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),

              ...bestTips.map(
                    (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SavedTipCard(
                    tip: tip,
                    highlight: true,
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

              const SizedBox(height: 20),

              const Text(
                'Alle Tipps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 12),

              ...ranked.map(
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

class _SavedTipCard extends StatelessWidget {
  final SavedTip tip;
  final bool highlight;
  final VoidCallback onWon;
  final VoidCallback onLost;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _SavedTipCard({
    required this.tip,
    this.highlight = false,
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
        color: highlight ? Colors.amber.withOpacity(0.15) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? Colors.amber
              : AppTheme.blue.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tip.homeTeam} vs ${tip.awayTeam}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text('${tip.tipLabel} · ${tip.aiScore}% · ${tip.resultLabel}'),
          const SizedBox(height: 6),
          Text(
              'Einsatz ${tip.stake}€ → Profit ${tip.profit.toStringAsFixed(2)}€'),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onWon,
                  child: const Text('Gewonnen'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: onLost,
                  child: const Text('Verloren'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onOpen,
                  child: const Text('Offen'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextButton(
                  onPressed: onDelete,
                  child: const Text('Löschen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}