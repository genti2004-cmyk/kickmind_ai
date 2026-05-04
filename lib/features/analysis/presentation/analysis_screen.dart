import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/presentation/widgets/match_card.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final MatchRepositoryImpl _repo = MatchRepositoryImpl();
  final PredictionEngine _engine = const PredictionEngine();

  MatchDateRange _range = MatchDateRange.today;
  late Future<List<FootballMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FootballMatch>> _load() {
    return _repo.getMatches(range: _range);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _setRange(MatchDateRange range) {
    if (_range == range) return;
    setState(() {
      _range = range;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                scrollDirection: Axis.horizontal,
                children: MatchDateRange.values.map((range) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(range.label),
                      selected: _range == range,
                      onSelected: (_) => _setRange(range),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<FootballMatch>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _MessageView(
                      title: 'Analyse konnte nicht geladen werden',
                      subtitle: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  final matches = snapshot.data ?? const <FootballMatch>[];

                  if (matches.isEmpty) {
                    return _MessageView(
                      title: 'Keine Analyse verfügbar',
                      subtitle: 'Für ${_range.label} wurden keine Spiele gefunden.',
                      onRetry: _refresh,
                    );
                  }

                  final avgAi = matches.map((m) => m.aiScore).fold<int>(0, (a, b) => a + b) / matches.length;
                  final strong = matches.where((m) => m.isStrongTip).length;
                  final lowRisk = matches.where((m) {
                    final risk = m.riskLevel.toLowerCase();
                    return risk == 'niedrig' || risk == 'low';
                  }).length;
                  final top = _engine.rankTopTips(matches, limit: 3);

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        const Text(
                          'KI-Übersicht',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _MetricCard(label: 'Spiele', value: '${matches.length}')),
                            const SizedBox(width: 10),
                            Expanded(child: _MetricCard(label: 'Ø AI', value: avgAi.toStringAsFixed(0))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _MetricCard(label: 'Starke Tipps', value: '$strong')),
                            const SizedBox(width: 10),
                            Expanded(child: _MetricCard(label: 'Niedrig Risiko', value: '$lowRisk')),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Top 3',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        ...top.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MatchCard(match: m),
                        )),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final String title;
  final String subtitle;
  final Future<void> Function() onRetry;

  const _MessageView({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Erneut laden'),
            ),
          ],
        ),
      ),
    );
  }
}
