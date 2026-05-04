import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/odds/data/live_odds_service.dart';
import 'package:kickmind_ai/features/odds/domain/live_odds.dart';

class LiveOddsScreen extends StatefulWidget {
  const LiveOddsScreen({super.key});

  @override
  State<LiveOddsScreen> createState() => _LiveOddsScreenState();
}

class _LiveOddsScreenState extends State<LiveOddsScreen> {
  final LiveOddsService _oddsService = const LiveOddsService();

  late Future<List<LiveOdds>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LiveOdds>> _load() async {
    try {
      return await _oddsService.fetchLiveOdds();
    } catch (_) {
      return <LiveOdds>[];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Quoten'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<LiveOdds>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final odds = snapshot.data ?? <LiveOdds>[];

            if (odds.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.casino_rounded, size: 52, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Keine Live-Quoten gefunden',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Prüfe den API-Key in LiveOddsService. Dieser Screen zeigt nur Quoten und berechnet keine Value Bets.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.35),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: odds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _LiveOddsCard(odds: odds[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _LiveOddsCard extends StatelessWidget {
  final LiveOdds odds;

  const _LiveOddsCard({required this.odds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                child: Text(
                  '${odds.homeTeam} vs ${odds.awayTeam}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Badge(text: odds.bookmaker, color: Colors.indigo),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OddsBadge(label: '1', value: odds.homeWin),
              _OddsBadge(label: 'X', value: odds.draw),
              _OddsBadge(label: '2', value: odds.awayWin),
              if (odds.over25 != null) _OddsBadge(label: 'Ü2.5', value: odds.over25!),
              if (odds.under25 != null) _OddsBadge(label: 'U2.5', value: odds.under25!),
              if (odds.bttsYes != null) _OddsBadge(label: 'BTTS', value: odds.bttsYes!),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Aktualisiert: ${_formatDateTime(odds.updatedAt)}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute';
  }
}

class _OddsBadge extends StatelessWidget {
  final String label;
  final double value;

  const _OddsBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(2)}',
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({
    required this.text,
    required this.color,
  });

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
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
