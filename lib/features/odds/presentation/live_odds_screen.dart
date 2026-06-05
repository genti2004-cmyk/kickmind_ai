import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/odds/data/live_odds_service.dart';
import 'package:kickmind_ai/features/odds/domain/live_odds.dart';

class LiveOddsScreen extends StatefulWidget {
  const LiveOddsScreen({super.key});

  @override
  State<LiveOddsScreen> createState() => _LiveOddsScreenState();
}

class _LiveOddsScreenState extends State<LiveOddsScreen> {
  final LiveOddsService _oddsService = LiveOddsService();

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

  List<LiveOdds> _dedupeByMatch(List<LiveOdds> source) {
    final unique = <String, LiveOdds>{};
    for (final item in source) {
      final key = item.matchId.trim().isEmpty
          ? '${item.homeTeam}_${item.awayTeam}_${item.updatedAt.toIso8601String()}'
          : item.matchId.trim();
      unique[key] = item;
    }
    final values = unique.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Live Quoten'),
        backgroundColor: const Color(0xFF071D2F),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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

            final odds = _dedupeByMatch(snapshot.data ?? <LiveOdds>[]);

            if (odds.isEmpty) {
              return _LiveOddsEmptyState(onRefresh: _refresh);
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 150),
              itemCount: odds.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _LiveOddsHeader(
                    matchCount: odds.length,
                    bookmakerCount: odds.map((item) => item.bookmaker).toSet().length,
                  );
                }

                return _LiveOddsCard(odds: odds[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _LiveOddsHeader extends StatelessWidget {
  final int matchCount;
  final int bookmakerCount;

  const _LiveOddsHeader({
    required this.matchCount,
    required this.bookmakerCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B4EA2), Color(0xFF1685F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B4EA2).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.casino_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Quoten Radar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$matchCount Spiele · $bookmakerCount Bookmaker',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Ein Spiel wird nur einmal angezeigt. Die wichtigsten Märkte stehen kompakt in derselben Karte.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveOddsEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _LiveOddsEmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 150),
      children: [
        const Text(
          'Live Quoten',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Value, Risiko und Final Score werden automatisch berechnet, sobald Live-Odds verfügbar sind.',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.casino_rounded, size: 40, color: Colors.indigo),
              ),
              const SizedBox(height: 20),
              const Text(
                'Keine Live-Quoten gefunden',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Die Quoten-Seite ist bereit. Falls API-Football für das Datum keine Odds liefert, bleibt die Liste leer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Neu laden'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveOddsCard extends StatelessWidget {
  final LiveOdds odds;

  const _LiveOddsCard({required this.odds});

  @override
  Widget build(BuildContext context) {
    final title = _matchTitle(odds);
    final subtitle = _hasFallbackTeamNames(odds)
        ? 'Teamdaten nicht vollständig geladen · Fixture ${odds.matchId}'
        : 'Aktualisiert ${_formatDateTime(odds.updatedAt)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3ECF7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.sports_soccer_rounded, color: Color(0xFF176CC7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Badge(text: odds.bookmaker, color: Colors.indigo),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Märkte',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OddsBadge(label: '1', description: 'Heim', value: odds.homeWin),
              _OddsBadge(label: 'X', description: 'Remis', value: odds.draw),
              _OddsBadge(label: '2', description: 'Auswärts', value: odds.awayWin),
              if (odds.over25 != null)
                _OddsBadge(label: 'Ü2.5', description: 'Tore', value: odds.over25!),
              if (odds.under25 != null)
                _OddsBadge(label: 'U2.5', description: 'Tore', value: odds.under25!),
              if (odds.bttsYes != null)
                _OddsBadge(label: 'BTTS', description: 'Ja', value: odds.bttsYes!),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasFallbackTeamNames(LiveOdds value) {
    return value.homeTeam.startsWith('Heimteam') || value.awayTeam.startsWith('Auswärtsteam');
  }

  String _matchTitle(LiveOdds value) {
    if (_hasFallbackTeamNames(value)) {
      return 'Spiel ${value.matchId}';
    }
    return '${value.homeTeam} vs ${value.awayTeam}';
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
  final String description;
  final double value;

  const _OddsBadge({
    required this.label,
    required this.description,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF176CC7),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
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
