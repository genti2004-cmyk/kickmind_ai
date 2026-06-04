import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/scoring/top_tip_score_service.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';

class TopTipsScreen extends StatefulWidget {
  const TopTipsScreen({super.key});

  @override
  State<TopTipsScreen> createState() => _TopTipsScreenState();
}

class _TopTipsScreenState extends State<TopTipsScreen> {
  final MatchRepositoryImpl _repository = MatchRepositoryImpl();
  final TopTipScoreService _scoreService = TopTipScoreService.instance;

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
      backgroundColor: KickMindTheme.background,
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
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _TopTipsErrorState(
              onRefresh: _refresh,
              message: 'Top Tipps konnten nicht geladen werden.',
            );
          }

          final matches = [...(snapshot.data ?? <FootballMatch>[])];

          if (matches.isEmpty) {
            return _TopTipsEmptyState(onRefresh: _refresh);
          }

          final ranked = matches..sort(_compareByFinalScore);
          final buckets = _buildBuckets(ranked);
          final best = ranked.first;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 126),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _RangeSelector(
                  selected: _range,
                  onChanged: _setRange,
                ),
                const SizedBox(height: 14),
                _TopTipsSummaryStrip(
                  rangeLabel: _range.label,
                  matchesCount: matches.length,
                  topTipsCount: buckets.premium.length,
                  valueCount: buckets.value.length,
                  noBetCount: buckets.noBet.length,
                  bestScore: _finalScore(best),
                  bestAiScore: best.aiScore,
                ),
                const SizedBox(height: 18),
                const _SectionTitle(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Premium Top Tipps',
                  subtitle: 'Nur Tipps mit starker Kombination aus AI, Final Score, Value und Risiko.',
                ),
                const SizedBox(height: 12),
                if (buckets.premium.isEmpty)
                  _NoPremiumTipNotice(
                    message: 'Aktuell kein Tipp stark genug für Premium. Die besten Kandidaten liegen unten unter Beobachten.',
                  )
                else
                  ...buckets.premium.map(
                        (match) => _TopTipCard(
                      match: match,
                      rank: buckets.premium.indexOf(match) + 1,
                      finalScore: _finalScore(match),
                      valueEdge: _valueEdge(match),
                      confidence: _confidence(match),
                      statusLabel: _statusLabel(match),
                      onTap: () => _openDetail(match),
                    ),
                  ),
                if (buckets.value.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    icon: Icons.trending_up_rounded,
                    title: 'Value Chancen',
                    subtitle: 'Interessante Quote, aber nicht automatisch ein sicherer Tipp.',
                  ),
                  const SizedBox(height: 12),
                  ...buckets.value.map(
                        (match) => _CompactTipCard(
                      match: match,
                      finalScore: _finalScore(match),
                      valueEdge: _valueEdge(match),
                      statusLabel: 'Value',
                      statusColor: KickMindTheme.success,
                      onTap: () => _openDetail(match),
                    ),
                  ),
                ],
                if (buckets.watch.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    icon: Icons.visibility_rounded,
                    title: 'Beobachten',
                    subtitle: 'Solide Ansätze, aber Final Score oder Risiko noch nicht stark genug.',
                  ),
                  const SizedBox(height: 12),
                  ...buckets.watch.map(
                        (match) => _CompactTipCard(
                      match: match,
                      finalScore: _finalScore(match),
                      valueEdge: _valueEdge(match),
                      statusLabel: 'Watch',
                      statusColor: KickMindTheme.primary,
                      onTap: () => _openDetail(match),
                    ),
                  ),
                ],
                if (buckets.noBet.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    icon: Icons.block_rounded,
                    title: 'No Bet',
                    subtitle: 'Zu wenig Edge, zu hohes Risiko oder zu schwacher Final Score.',
                  ),
                  const SizedBox(height: 12),
                  ...buckets.noBet.take(6).map(
                        (match) => _CompactTipCard(
                      match: match,
                      finalScore: _finalScore(match),
                      valueEdge: _valueEdge(match),
                      statusLabel: 'No Bet',
                      statusColor: Colors.redAccent,
                      onTap: () => _openDetail(match),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  _TopTipBuckets _buildBuckets(List<FootballMatch> ranked) {
    final premium = <FootballMatch>[];
    final value = <FootballMatch>[];
    final watch = <FootballMatch>[];
    final noBet = <FootballMatch>[];

    for (final match in ranked) {
      final decision = _scoreService.decision(match);

      switch (decision.type) {
        case TopTipDecisionType.premium:
          premium.add(match);
          break;
        case TopTipDecisionType.value:
          value.add(match);
          break;
        case TopTipDecisionType.watch:
          watch.add(match);
          break;
        case TopTipDecisionType.noBet:
          noBet.add(match);
          break;
      }
    }

    return _TopTipBuckets(
      premium: premium.take(7).toList(),
      value: value.take(5).toList(),
      watch: watch.take(7).toList(),
      noBet: noBet,
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

  int _compareByFinalScore(FootballMatch a, FootballMatch b) {
    return _scoreService.compareByFinalScore(a, b);
  }

  String _statusLabel(FootballMatch match) {
    final decision = _scoreService.decision(match);
    if (decision.type == TopTipDecisionType.premium) return 'Top Tipp';
    if (decision.type == TopTipDecisionType.value) return 'Value Tipp';
    if (decision.type == TopTipDecisionType.watch) return 'Stabil';
    return 'No Bet';
  }

  double _finalScore(FootballMatch match) {
    return _scoreService.score(match).finalScore;
  }

  double _confidence(FootballMatch match) {
    return _scoreService.score(match).confidence;
  }

  double _valueEdge(FootballMatch match) {
    return _scoreService.score(match).valueEdge;
  }
}

class _TopTipBuckets {
  final List<FootballMatch> premium;
  final List<FootballMatch> value;
  final List<FootballMatch> watch;
  final List<FootballMatch> noBet;

  const _TopTipBuckets({
    required this.premium,
    required this.value,
    required this.watch,
    required this.noBet,
  });
}

class _TopTipsSummaryStrip extends StatelessWidget {
  final String rangeLabel;
  final int matchesCount;
  final int topTipsCount;
  final int valueCount;
  final int noBetCount;
  final double bestScore;
  final int bestAiScore;

  const _TopTipsSummaryStrip({
    required this.rangeLabel,
    required this.matchesCount,
    required this.topTipsCount,
    required this.valueCount,
    required this.noBetCount,
    required this.bestScore,
    required this.bestAiScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KickMindTheme.primary.withOpacity(0.075),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KickMindTheme.primary.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KickMindTheme.primary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$rangeLabel · $matchesCount Spiele analysiert',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KickMindTheme.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bester Final ${bestScore.toStringAsFixed(1)} · AI $bestAiScore%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KickMindTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMiniMetric(
                  label: 'Premium',
                  value: '$topTipsCount',
                  color: KickMindTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMiniMetric(
                  label: 'Value',
                  value: '$valueCount',
                  color: KickMindTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMiniMetric(
                  label: 'No Bet',
                  value: '$noBetCount',
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KickMindTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
    return Row(
      children: MatchDateRange.values.map((range) {
        final index = MatchDateRange.values.indexOf(range);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == MatchDateRange.values.length - 1 ? 0 : 8,
            ),
            child: _RangeChip(
              label: range.label,
              range: range,
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        );
      }).toList(),
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

    return InkWell(
      onTap: () => onChanged(range),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? KickMindTheme.primaryDark : KickMindTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? KickMindTheme.primary.withOpacity(0.55)
                : Colors.black.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.10 : 0.035),
              blurRadius: isSelected ? 12 : 7,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? Colors.white : KickMindTheme.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: KickMindTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: KickMindTheme.primary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
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
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: KickMindTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoPremiumTipNotice extends StatelessWidget {
  final String message;

  const _NoPremiumTipNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: KickMindTheme.textDark,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTipCard extends StatelessWidget {
  final FootballMatch match;
  final int rank;
  final double finalScore;
  final double valueEdge;
  final double confidence;
  final String statusLabel;
  final VoidCallback onTap;

  const _TopTipCard({
    required this.match,
    required this.rank,
    required this.finalScore,
    required this.valueEdge,
    required this.confidence,
    required this.statusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);
    final riskColor = KickMindTheme.riskColor(match.riskLevel);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
        decoration: BoxDecoration(
          color: KickMindTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: rank == 1
                ? KickMindTheme.primary.withOpacity(0.28)
                : Colors.black.withOpacity(0.045),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(rank == 1 ? 0.085 : 0.055),
              blurRadius: rank == 1 ? 22 : 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RankBadge(rank: rank),
                const SizedBox(width: 10),
                _StatusBadge(text: statusLabel, color: KickMindTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    match.league,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KickMindTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.schedule_rounded, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  match.kickoffLabel,
                  style: const TextStyle(
                    color: KickMindTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              match.teamsLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: KickMindTheme.textDark,
                fontSize: 18.5,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TipPill(text: match.tipLabel, color: KickMindTheme.primary),
                _TipPill(text: 'AI ${match.aiScore}%', color: scoreColor),
                _TipPill(text: 'Final ${finalScore.toStringAsFixed(1)}', color: KickMindTheme.primaryDark),
                _TipPill(text: '${match.riskEmoji} ${match.riskLevel}', color: riskColor),
                _TipPill(text: 'Quote ${match.odds.toStringAsFixed(2)}', color: Colors.indigo),
                if (valueEdge > 0)
                  _TipPill(
                    text: 'Value +${valueEdge.toStringAsFixed(1)}%',
                    color: KickMindTheme.success,
                  ),
              ],
            ),
            const SizedBox(height: 13),
            _ScoreBar(
              label: 'Confidence',
              value: confidence,
              color: scoreColor,
            ),
            if (match.shortReason.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                match.shortReason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  height: 1.34,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactTipCard extends StatelessWidget {
  final FootballMatch match;
  final double finalScore;
  final double valueEdge;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  const _CompactTipCard({
    required this.match,
    required this.finalScore,
    required this.valueEdge,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KickMindTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.045)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${match.aiScore}',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusBadge(text: statusLabel, color: statusColor),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          match.league,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KickMindTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    match.teamsLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KickMindTheme.textDark,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${match.tipLabel} · Final ${finalScore.toStringAsFixed(1)} · Value ${valueEdge.toStringAsFixed(1)}% · Quote ${match.odds.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KickMindTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: KickMindTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;

    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isTop
            ? KickMindTheme.primary
            : KickMindTheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '#$rank',
        style: TextStyle(
          color: isTop ? Colors.white : KickMindTheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TipPill extends StatelessWidget {
  final String text;
  final Color color;

  const _TipPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.115),
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

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ScoreBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 100.0).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: KickMindTheme.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: normalized,
            backgroundColor: color.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _TopTipsEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _TopTipsEmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.sports_soccer_rounded,
      title: 'Keine Top Tipps gefunden',
      message: 'Prüfe später erneut oder wechsle den Zeitraum.',
      onRefresh: onRefresh,
    );
  }
}

class _TopTipsErrorState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final String message;

  const _TopTipsErrorState({
    required this.onRefresh,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.wifi_off_rounded,
      title: 'Daten nicht verfügbar',
      message: message,
      onRefresh: onRefresh,
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onRefresh;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 126),
          children: [
            Icon(icon, size: 48, color: KickMindTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: KickMindTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KickMindTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Aktualisieren'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
