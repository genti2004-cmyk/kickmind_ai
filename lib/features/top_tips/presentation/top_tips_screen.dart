import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/matches/data/mock_matches_repository.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';
import 'package:kickmind_ai/features/matches/presentation/widgets/premium_match_card.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';

class TopTipsScreen extends StatefulWidget {
  const TopTipsScreen({super.key});

  @override
  State<TopTipsScreen> createState() => _TopTipsScreenState();
}

class _TopTipsScreenState extends State<TopTipsScreen> {
  final MockMatchesRepository _repository = MockMatchesRepository();
  final PredictionEngine _engine = const PredictionEngine();

  late Future<List<FootballMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadTopTips();
  }

  Future<List<FootballMatch>> _loadTopTips() async {
    final matches = _repository.getTodayMatches();
    return _engine.rankTopTips(matches, limit: 10);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadTopTips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Tipps'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
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

          final tips = snapshot.data ?? const <FootballMatch>[];

          if (tips.isEmpty) {
            return const Center(child: Text('Keine Top Tipps gefunden'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: tips.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const _TopTipsHeader();
                }

                final rank = index;
                final match = tips[index - 1];

                return PremiumMatchCard(
                  match: match,
                  trailing: _RankBadge(rank: rank, score: match.aiScore),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MatchDetailScreen(match: match),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TopTipsHeader extends StatelessWidget {
  const _TopTipsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [KickMindTheme.primaryDark, KickMindTheme.primary],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Tipps Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sortiert nach AI Score, Risiko und Quote',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final int score;

  const _RankBadge({required this.rank, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = KickMindTheme.scoreColor(score);

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        '#$rank',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
