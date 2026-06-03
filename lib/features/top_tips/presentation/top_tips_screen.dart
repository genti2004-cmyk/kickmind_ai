import 'package:flutter/material.dart';
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

          final recommended = ranked.where(_isRecommendedTip).toList();
          final visibleTopTips = recommended.isNotEmpty
              ? recommended
              : ranked.take(5).toList();

          final valueBets = ranked.where(_isValueBet).take(4).toList();
          final watchList = ranked
              .where((match) => !visibleTopTips.contains(match))
              .where((match) => _finalScore(match) >= 58)
              .take(6)
              .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _TopTipsHeader(
                  rangeLabel: _range.label,
                  matchesCount: matches.length,
                  bestScore: _finalScore(ranked.first),
                  bestAiScore: ranked.first.aiScore,
                ),
                const SizedBox(height: 14),
                _RangeSelector(
                  selected: _range,
                  onChanged: _setRange,
                ),
                const SizedBox(height: 18),
                const _SectionTitle(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Beste Auswahl',
                  subtitle: 'AI-Score, Value-Edge, Risiko und Quote kombiniert.',
                ),
                const SizedBox(height: 12),
                ...visibleTopTips.take(8).map(
                      (match) => _TopTipCard(
                    match: match,
                    rank: visibleTopTips.indexOf(match) + 1,
                    finalScore: _finalScore(match),
                    valueEdge: _valueEdge(match),
                    confidence: _confidence(match),
                    onTap: () => _openDetail(match),
                  ),
                ),
                if (valueBets.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    icon: Icons.trending_up_rounded,
                    title: 'Value Chancen',
                    subtitle: 'AI-Wahrscheinlichkeit liegt über der impliziten Quote.',
                  ),
                  const SizedBox(height: 12),
                  ...valueBets.map(
                        (match) => _CompactTipCard(
                      match: match,
                      finalScore: _finalScore(match),
                      valueEdge: _valueEdge(match),
                      onTap: () => _openDetail(match),
                    ),
                  ),
                ],
                if (watchList.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    icon: Icons.visibility_rounded,
                    title: 'Beobachten',
                    subtitle: 'Interessant, aber noch kein klarer Premium-Tipp.',
                  ),
                  const SizedBox(height: 12),
                  ...watchList.map(
                        (match) => _CompactTipCard(
                      match: match,
                      finalScore: _finalScore(match),
                      valueEdge: _valueEdge(match),
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

  void _openDetail(FootballMatch match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(match: match),
      ),
    );
  }

  int _compareByFinalScore(FootballMatch a, FootballMatch b) {
    final finalCompare = _finalScore(b).compareTo(_finalScore(a));
    if (finalCompare != 0) return finalCompare;

    final aiCompare = b.aiScore.compareTo(a.aiScore);
    if (aiCompare != 0) return aiCompare;

    final valueCompare = _valueEdge(b).compareTo(_valueEdge(a));
    if (valueCompare != 0) return valueCompare;

    return a.odds.compareTo(b.odds);
  }

  bool _isRecommendedTip(FootballMatch match) {
    if (match.aiScore < 68) return false;
    if (_isHighRisk(match) && match.aiScore < 82) return false;
    return _finalScore(match) >= 67;
  }

  bool _isValueBet(FootballMatch match) {
    return match.aiScore >= 70 && _valueEdge(match) >= 4.5;
  }

  bool _isHighRisk(FootballMatch match) {
    final risk = match.riskLevel.toLowerCase();
    return risk.contains('hoch') || risk.contains('high');
  }

  double _finalScore(FootballMatch match) {
    final ai = match.aiScore.toDouble();
    final value = _valueEdge(match).clamp(-15.0, 18.0).toDouble();
    final riskBonus = _riskBonus(match);
    final oddsBonus = _oddsBonus(match.odds);
    final formBoost = _formBoost(match);

    return (ai * 0.62 + value * 0.95 + riskBonus + oddsBonus + formBoost)
        .clamp(1.0, 99.0)
        .toDouble();
  }

  double _confidence(FootballMatch match) {
    final risk = _riskBonus(match);
    final score = match.aiScore + risk + _formBoost(match) + _oddsBonus(match.odds);
    return score.clamp(1.0, 99.0).toDouble();
  }

  double _valueEdge(FootballMatch match) {
    if (match.odds <= 1.0) return 0.0;

    final aiProbability = (match.aiScore / 100.0).clamp(0.0, 1.0).toDouble();
    final impliedProbability = (1.0 / match.odds).clamp(0.0, 1.0).toDouble();

    return (aiProbability - impliedProbability) * 100.0;
  }

  double _riskBonus(FootballMatch match) {
    final risk = match.riskLevel.toLowerCase();

    if (risk.contains('niedrig') || risk.contains('low')) return 8.0;
    if (risk.contains('mittel') || risk.contains('medium')) return 2.0;
    return -10.0;
  }

  double _oddsBonus(double odds) {
    if (odds >= 1.45 && odds <= 2.05) return 5.0;
    if (odds > 2.05 && odds <= 2.45) return 1.0;
    if (odds < 1.25 || odds > 3.10) return -5.0;
    return 0.0;
  }

  double _formBoost(FootballMatch match) {
    final strongestForm = match.homeFormScore > match.awayFormScore
        ? match.homeFormScore
        : match.awayFormScore;

    if (strongestForm >= 84) return 5.0;
    if (strongestForm >= 76) return 2.5;
    if (strongestForm < 58) return -4.0;
    return 0.0;
  }
}

class _TopTipsHeader extends StatelessWidget {
  final String rangeLabel;
  final int matchesCount;
  final double bestScore;
  final int bestAiScore;

  const _TopTipsHeader({
    required this.rangeLabel,
    required this.matchesCount,
    required this.bestScore,
    required this.bestAiScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            KickMindTheme.primaryDark,
            KickMindTheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: KickMindTheme.primary.withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KickMind AI Ranking',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$rangeLabel · $matchesCount Spiele analysiert',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: 'Final Score',
                  value: bestScore.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Bester AI',
                  value: '$bestAiScore%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: MatchDateRange.values.map((range) {
          return _RangeChip(
            label: range.label,
            range: range,
            selected: selected,
            onChanged: onChanged,
          );
        }).toList(),
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
        backgroundColor: KickMindTheme.surface,
        side: BorderSide(
          color: isSelected
              ? KickMindTheme.primary.withOpacity(0.35)
              : Colors.black.withOpacity(0.06),
        ),
        labelStyle: TextStyle(
          color: isSelected ? KickMindTheme.primary : KickMindTheme.textDark,
          fontWeight: FontWeight.w900,
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

class _TopTipCard extends StatelessWidget {
  final FootballMatch match;
  final int rank;
  final double finalScore;
  final double valueEdge;
  final double confidence;
  final VoidCallback onTap;

  const _TopTipCard({
    required this.match,
    required this.rank,
    required this.finalScore,
    required this.valueEdge,
    required this.confidence,
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
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(16),
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
                fontSize: 18,
                height: 1.14,
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
  final VoidCallback onTap;

  const _CompactTipCard({
    required this.match,
    required this.finalScore,
    required this.valueEdge,
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
              width: 42,
              height: 42,
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
                    '${match.tipLabel} · Final ${finalScore.toStringAsFixed(1)} · Value ${valueEdge.toStringAsFixed(1)}%',
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
                  fontSize: 12,
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
          padding: const EdgeInsets.all(24),
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
