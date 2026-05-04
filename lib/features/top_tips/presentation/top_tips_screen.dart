import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';
import 'package:kickmind_ai/features/matches/presentation/widgets/match_card.dart';

class TopTipsScreen extends StatefulWidget {
  const TopTipsScreen({super.key});

  @override
  State<TopTipsScreen> createState() => _TopTipsScreenState();
}

class _TopTipsScreenState extends State<TopTipsScreen> {
  final MatchRepositoryImpl _repository = MatchRepositoryImpl();
  MatchDateRange _range = MatchDateRange.today;
  late Future<List<FootballMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FootballMatch>> _load() {
    return _repository.getMatches(range: _range);
  }

  void _setRange(MatchDateRange range) {
    if (_range == range) return;
    setState(() {
      _range = range;
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Tipps'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<FootballMatch>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final matches = [...(snapshot.data ?? <FootballMatch>[])];

          if (matches.isEmpty) {
            return _EmptyState(onRefresh: _refresh);
          }

          final valueBets = matches.where(_isValueBet).toList()
            ..sort((a, b) => _valueEdge(b).compareTo(_valueEdge(a)));

          final topTips = matches.where((m) => m.aiScore >= 65).toList()
            ..sort((a, b) {
              final valueCompare = _valueEdge(b).compareTo(_valueEdge(a));
              if (valueCompare != 0) return valueCompare;
              return b.aiScore.compareTo(a.aiScore);
            });

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _RangeSelector(
                  selected: _range,
                  onChanged: _setRange,
                ),
                const SizedBox(height: 16),
                if (valueBets.isNotEmpty) ...[
                  const _SectionTitle(
                    title: '💰 Value Bets',
                    subtitle: 'AI-Wahrscheinlichkeit liegt über der impliziten Quote.',
                  ),
                  const SizedBox(height: 12),
                  ...valueBets.take(3).map(
                        (match) => MatchCard(
                      match: match,
                      badge: '💰 VALUE BET +${_valueEdge(match).toStringAsFixed(1)}%',
                      onTap: () => _openDetail(match),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                const _SectionTitle(
                  title: '🔥 Top Tipps',
                  subtitle: 'Sortiert nach Value, AI-Score und Risiko.',
                ),
                const SizedBox(height: 12),
                ...topTips.map(
                      (match) => MatchCard(
                    match: match,
                    badge: match.aiScore >= 85
                        ? '💎 PRO TIPP'
                        : match.aiScore >= 78
                        ? '🔥 STARKER TIPP'
                        : null,
                    onTap: () => _openDetail(match),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openDetail(FootballMatch match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(match: match),
      ),
    );
  }

  bool _isValueBet(FootballMatch match) {
    return match.aiScore >= 70 && _valueEdge(match) >= 5.0;
  }

  double _valueEdge(FootballMatch match) {
    if (match.odds <= 1.0) return 0;
    final aiProbability = (match.aiScore / 100).clamp(0.0, 1.0);
    final impliedProbability = (1 / match.odds).clamp(0.0, 1.0);
    return (aiProbability - impliedProbability) * 100;
  }
}

class _RangeSelector extends StatelessWidget {
  final MatchDateRange selected;
  final ValueChanged<MatchDateRange> onChanged;

  const _RangeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _RangeChip(label: 'Heute', range: MatchDateRange.today, selected: selected, onChanged: onChanged),
          _RangeChip(label: 'Morgen', range: MatchDateRange.tomorrow, selected: selected, onChanged: onChanged),
          _RangeChip(label: '3 Tage', range: MatchDateRange.next3Days, selected: selected, onChanged: onChanged),
          _RangeChip(label: 'Woche', range: MatchDateRange.next7Days, selected: selected, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final MatchDateRange range;
  final MatchDateRange selected;
  final ValueChanged<MatchDateRange> onChanged;

  const _RangeChip({
    required this.label,
    required this.range,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == range;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => onChanged(range),
        selectedColor: KickMindTheme.primary.withOpacity(0.14),
        labelStyle: TextStyle(
          color: isSelected ? KickMindTheme.primary : KickMindTheme.textDark,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: KickMindTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KickMindTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_soccer_rounded, size: 46, color: KickMindTheme.textMuted),
            const SizedBox(height: 12),
            const Text(
              'Keine Top Tipps gefunden',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Prüfe später erneut oder wechsle den Zeitraum.',
              textAlign: TextAlign.center,
              style: TextStyle(color: KickMindTheme.textMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Aktualisieren'),
            ),
          ],
        ),
      ),
    );
  }
}
