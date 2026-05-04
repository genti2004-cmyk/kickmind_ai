import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';
import 'package:kickmind_ai/features/value_bets/data/value_bet_service.dart';
import 'package:kickmind_ai/features/value_bets/domain/value_bet_result.dart';

class ValueBetsScreen extends StatefulWidget {
  const ValueBetsScreen({super.key});

  @override
  State<ValueBetsScreen> createState() => _ValueBetsScreenState();
}

class _ValueBetsScreenState extends State<ValueBetsScreen> {
  final MatchRepositoryImpl _repo = MatchRepositoryImpl();
  final ValueBetService _service = const ValueBetService();

  MatchDateRange _range = MatchDateRange.today;
  late Future<List<ValueBetResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ValueBetResult>> _load() async {
    final matches = await _repo.getMatches(range: _range);
    return _service.evaluateAll(matches);
  }

  void _setRange(MatchDateRange range) {
    setState(() {
      _range = range;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Value Bets'),
      ),
      body: Column(
        children: [
          _RangeSelector(
            selected: _range,
            onChanged: _setRange,
          ),
          Expanded(
            child: FutureBuilder<List<ValueBetResult>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final results = snapshot.data ?? const <ValueBetResult>[];
                if (results.isEmpty) {
                  return const Center(child: Text('Keine Spiele gefunden.'));
                }

                final valueCount = results.where((r) => r.isValueBet).length;

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _future = _load());
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: results.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _HeaderCard(
                          valueCount: valueCount,
                          total: results.length,
                        );
                      }

                      final result = results[index - 1];
                      return _ValueBetCard(
                        result: result,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MatchDetailScreen(match: result.match),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final MatchDateRange selected;
  final ValueChanged<MatchDateRange> onChanged;

  const _RangeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = <({MatchDateRange range, String label})>[
      (range: MatchDateRange.today, label: 'Heute'),
      (range: MatchDateRange.tomorrow, label: 'Morgen'),
      (range: MatchDateRange.next3Days, label: '3 Tage'),
      (range: MatchDateRange.next7Days, label: 'Woche'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: items.map((item) {
          final active = selected == item.range;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              label: Text(item.label),
              onSelected: (_) => onChanged(item.range),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int valueCount;
  final int total;

  const _HeaderCard({
    required this.valueCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.diamond_rounded, color: Colors.blue, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Value Analyse',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '$valueCount von $total Spielen mit möglichem Value.',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBetCard extends StatelessWidget {
  final ValueBetResult result;
  final VoidCallback onTap;

  const _ValueBetCard({
    required this.result,
    required this.onTap,
  });

  FootballMatch get match => result.match;

  @override
  Widget build(BuildContext context) {
    final color = result.isValueBet ? Colors.green : Colors.orange;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.teamsLabel,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                _Badge(
                  text: result.isValueBet ? '💎 VALUE' : 'CHECK',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${match.league} • ${match.kickoffLabel}',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(text: 'Tipp ${match.tipLabel}', color: Colors.blue),
                _Badge(text: 'Quote ${result.odds.toStringAsFixed(2)}', color: Colors.indigo),
                _Badge(text: 'AI ${result.aiPercent}%', color: Colors.green),
                _Badge(text: 'Quote ${result.impliedPercent}%', color: Colors.deepPurple),
                _Badge(text: 'Edge ${result.edgeLabel}', color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.explanation,
              style: TextStyle(
                color: Colors.grey.shade800,
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
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
