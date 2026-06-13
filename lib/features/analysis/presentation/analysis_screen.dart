import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/scoring/top_tip_score_service.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
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

  Future<void> _refresh() async {
    setState(() => _future = _load());
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
      backgroundColor: KickMindTheme.background,
      appBar: AppBar(
        title: const Text('Analyse'),
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

          if (snapshot.hasError) {
            return _AnalysisMessageState(
              icon: Icons.analytics_outlined,
              title: 'Analyse konnte nicht geladen werden',
              subtitle: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final ranked = [...(snapshot.data ?? <FootballMatch>[])]..sort(_compareByFinalScore);

          if (ranked.isEmpty) {
            return _AnalysisMessageState(
              icon: Icons.search_off_rounded,
              title: 'Keine Analyse verfügbar',
              subtitle: 'Für ${_range.label} wurden keine Spiele gefunden.',
              onRetry: _refresh,
            );
          }

          final buckets = _buildBuckets(ranked);
          final avgFinal = ranked.map(_finalScore).fold<double>(0, (a, b) => a + b) / ranked.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                _AnalysisRangeSelector(
                  selected: _range,
                  onChanged: _setRange,
                ),
                const SizedBox(height: 12),
                _AnalysisHero(
                  rangeLabel: _range.label,
                  matchesCount: ranked.length,
                  premiumCount: buckets.premium.length,
                  valueCount: buckets.value.length,
                  watchCount: buckets.watch.length,
                  noBetCount: buckets.noBet.length,
                  bestMatch: ranked.first,
                  bestFinalScore: _finalScore(ranked.first),
                  bestValueEdge: _valueEdge(ranked.first),
                  avgFinalScore: avgFinal,
                ),
                const SizedBox(height: 12),
                _MetricGrid(
                  children: [
                    _MetricCard(
                      label: 'Premium',
                      value: '${buckets.premium.length}',
                      icon: Icons.workspace_premium_rounded,
                      color: KickMindTheme.primary,
                    ),
                    _MetricCard(
                      label: 'Value',
                      value: '${buckets.value.length}',
                      icon: Icons.trending_up_rounded,
                      color: KickMindTheme.success,
                    ),
                    _MetricCard(
                      label: 'Beobachten',
                      value: '${buckets.watch.length}',
                      icon: Icons.visibility_rounded,
                      color: KickMindTheme.primaryDark,
                    ),
                    _MetricCard(
                      label: 'No Bet',
                      value: '${buckets.noBet.length}',
                      icon: Icons.block_rounded,
                      color: KickMindTheme.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionTitle(
                  icon: Icons.auto_graph_rounded,
                  title: 'Finales Analyse-Ranking',
                  subtitle: 'Echte Quoten zuerst. Spiele ohne Quote bleiben als Beobachtung sichtbar.',
                ),
                const SizedBox(height: 12),
                ...ranked.take(5).map(
                      (match) => _AnalysisTipTile(
                    match: match,
                    rank: ranked.indexOf(match) + 1,
                    finalScore: _finalScore(match),
                    valueEdge: _valueEdge(match),
                    confidence: _confidence(match),
                    statusLabel: _categoryLabel(match),
                    statusColor: _categoryColor(match),
                    sourceLabel: _sourceLabel(match),
                    sourceColor: _sourceColor(match),
                    quoteLabel: _quoteLabel(match),
                    quoteColor: _quoteColor(match),
                    reason: _analysisReason(match),
                    onTap: () => _openDetail(match),
                  ),
                ),
                if (buckets.premium.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _SectionTitle(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Premium Signale mit Quote',
                    subtitle: 'Nur Spiele mit echter Bookmaker-Quote und starkem Score.',
                  ),
                  const SizedBox(height: 12),
                  ...buckets.premium.take(4).map(
                        (match) => _CompactAnalysisTile(
                      match: match,
                      finalScore: _finalScore(match),
                      valueEdge: _valueEdge(match),
                      statusLabel: 'Premium',
                      statusColor: KickMindTheme.primary,
                      sourceLabel: _sourceLabel(match),
                      sourceColor: _sourceColor(match),
                      quoteLabel: _quoteLabel(match),
                      quoteColor: _quoteColor(match),
                      reason: _analysisReason(match),
                      onTap: () => _openDetail(match),
                    ),
                  ),
                ],
                if (buckets.value.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _SectionTitle(
                    icon: Icons.trending_up_rounded,
                    title: 'Value Chancen mit Quote',
                    subtitle: 'Nur mit echter Quote. Keine Spielplan-Quote wird erfunden.',
                  ),
                  const SizedBox(height: 12),
                  ...buckets.value.take(4).map(
                        (match) => _CompactAnalysisTile(
                      match: match,
                      finalScore: _finalScore(match),
                      valueEdge: _valueEdge(match),
                      statusLabel: 'Value',
                      statusColor: KickMindTheme.success,
                      sourceLabel: _sourceLabel(match),
                      sourceColor: _sourceColor(match),
                      quoteLabel: _quoteLabel(match),
                      quoteColor: _quoteColor(match),
                      reason: _analysisReason(match),
                      onTap: () => _openDetail(match),
                    ),
                  ),
                ],
                if (buckets.watch.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _SectionTitle(
                    icon: Icons.visibility_rounded,
                    title: 'Beobachten / ohne Quote',
                    subtitle: 'Solide Spielplan-Signale, aber noch kein echter Wett-Tipp.',
                  ),
                  const SizedBox(height: 12),
                  ...buckets.watch.take(4).map(
                        (match) => _CompactAnalysisTile(
                      match: match,
                      finalScore: _finalScore(match),
                      valueEdge: _valueEdge(match),
                      statusLabel: 'Watch',
                      statusColor: KickMindTheme.primaryDark,
                      sourceLabel: _sourceLabel(match),
                      sourceColor: _sourceColor(match),
                      quoteLabel: _quoteLabel(match),
                      quoteColor: _quoteColor(match),
                      reason: _analysisReason(match),
                      onTap: () => _openDetail(match),
                    ),
                  ),
                ],
                if (buckets.noBet.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _SectionTitle(
                    icon: Icons.block_rounded,
                    title: 'No Bet / Risiko-Warnung',
                    subtitle: 'Aktuell kein klares Value-Signal.',
                  ),
                  const SizedBox(height: 12),
                  ...buckets.noBet.take(5).map(
                        (match) => _RiskWarningTile(
                      match: match,
                      finalScore: _finalScore(match),
                      quoteLabel: _quoteLabel(match),
                      quoteColor: _quoteColor(match),
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

  _AnalysisBuckets _buildBuckets(List<FootballMatch> ranked) {
    final premium = <FootballMatch>[];
    final value = <FootballMatch>[];
    final watch = <FootballMatch>[];
    final noBet = <FootballMatch>[];

    for (final match in ranked) {
      final decision = _scoreService.decision(match);

      // Wichtig: Analyse darf Spielplan-Spiele ohne echte Quote anzeigen,
      // aber nicht als Premium/Value-Wett-Tipp verkaufen.
      // Ohne echte Bookmaker-Quote ist ein Match maximal Beobachtung.
      if (!_hasUsableQuote(match)) {
        if (decision.type == TopTipDecisionType.noBet) {
          noBet.add(match);
        } else {
          watch.add(match);
        }
        continue;
      }

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

    return _AnalysisBuckets(
      premium: premium.take(7).toList(),
      value: value.take(5).toList(),
      watch: watch.take(10).toList(),
      noBet: noBet,
    );
  }

  String _categoryLabel(FootballMatch match) {
    return _scoreService.decision(match).shortLabel;
  }

  Color _categoryColor(FootballMatch match) {
    switch (_scoreService.decision(match).type) {
      case TopTipDecisionType.premium:
        return KickMindTheme.primary;
      case TopTipDecisionType.value:
        return KickMindTheme.success;
      case TopTipDecisionType.watch:
        return KickMindTheme.primaryDark;
      case TopTipDecisionType.noBet:
        return KickMindTheme.danger;
    }
  }

  bool _hasRealBookmakerOdds(FootballMatch match) {
    return match.id.startsWith('odds_');
  }

  String _sourceLabel(FootballMatch match) {
    return _hasRealBookmakerOdds(match) ? 'Echte Quote' : 'Spielplan';
  }

  Color _sourceColor(FootballMatch match) {
    return _hasRealBookmakerOdds(match) ? KickMindTheme.success : Colors.blueGrey;
  }

  bool _hasUsableQuote(FootballMatch match) {
    return match.odds > 1.05 && _hasRealBookmakerOdds(match);
  }

  String _quoteLabel(FootballMatch match) {
    if (_hasUsableQuote(match)) {
      return 'Quote ${match.odds.toStringAsFixed(2)}';
    }
    return 'Keine echte Quote';
  }

  Color _quoteColor(FootballMatch match) {
    return _hasUsableQuote(match) ? Colors.indigo : Colors.blueGrey;
  }

  String _analysisReason(FootballMatch match) {
    final decision = _scoreService.decision(match);
    final score = _scoreService.score(match);
    final source = _hasRealBookmakerOdds(match) ? 'echte Bookmaker-Quote' : 'echte Spielplan-Daten ohne bestätigte Quote';
    final valueText = score.valueEdge >= 0
        ? '+${score.valueEdge.toStringAsFixed(1)}%'
        : '${score.valueEdge.toStringAsFixed(1)}%';

    String tipContext;
    switch (match.tipType) {
      case TipType.homeWin:
        tipContext = 'Heimsieg-Signal';
        break;
      case TipType.draw:
        tipContext = 'Remis-Signal';
        break;
      case TipType.awayWin:
        tipContext = 'Auswärtssieg-Signal';
        break;
      case TipType.over25:
        tipContext = 'Tor-Markt Ü2.5';
        break;
      case TipType.under25:
        tipContext = 'Tor-Markt U2.5';
        break;
      case TipType.btts:
        tipContext = 'BTTS-Signal';
        break;
    }

    switch (decision.type) {
      case TopTipDecisionType.premium:
        return 'Premium: $tipContext mit $source, Final ${score.finalScore.toStringAsFixed(1)}, Value $valueText und kontrolliertem Risiko.';
      case TopTipDecisionType.value:
        if (!_hasUsableQuote(match)) {
          return 'Beobachtung: $tipContext basiert auf Spielplan-Daten ohne echte Quote. Kein Value-Tipp.';
        }
        return 'Value: $tipContext wirkt im Verhältnis zur echten Quote interessant. Edge $valueText, Confidence ${score.confidence.toStringAsFixed(0)}%.';
      case TopTipDecisionType.watch:
        return _hasUsableQuote(match)
            ? 'Beobachten: $tipContext ist solide, aber noch kein Premium-Signal. Risiko ${match.riskLevel}, Final ${score.finalScore.toStringAsFixed(1)}.'
            : 'Beobachten: $tipContext ist solide, aber ohne echte Quote noch kein Wett-Tipp. Risiko ${match.riskLevel}, Final ${score.finalScore.toStringAsFixed(1)}.';
      case TopTipDecisionType.noBet:
        return 'No Bet: aktuell kein klares Signal. Risiko/Quote/Confidence passen noch nicht stabil zusammen.';
    }
  }

  void _openDetail(FootballMatch match) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
    );
  }

  int _compareByFinalScore(FootballMatch a, FootballMatch b) {
    final qualityCompare = _analysisQualityScore(b).compareTo(_analysisQualityScore(a));
    if (qualityCompare != 0) return qualityCompare;

    final scoreCompare = _scoreService.compareByFinalScore(a, b);
    if (scoreCompare != 0) return scoreCompare;

    return a.kickoff.compareTo(b.kickoff);
  }

  double _analysisQualityScore(FootballMatch match) {
    final score = _scoreService.score(match);
    final decision = _scoreService.decision(match);

    final quoteBoost = _hasUsableQuote(match) ? 14.0 : -7.0;
    final decisionBoost = switch (decision.type) {
      TopTipDecisionType.premium => 12.0,
      TopTipDecisionType.value => 8.0,
      TopTipDecisionType.watch => 2.0,
      TopTipDecisionType.noBet => -18.0,
    };

    final risk = match.riskLevel.toLowerCase().trim();
    final riskBoost = risk == 'hoch' || risk == 'high'
        ? -12.0
        : risk.contains('niedrig') || risk.contains('low')
        ? 4.0
        : 1.0;

    final valueBoost = _hasUsableQuote(match)
        ? score.valueEdge.clamp(-8.0, 10.0).toDouble() * 0.35
        : 0.0;

    return score.finalScore + quoteBoost + decisionBoost + riskBoost + valueBoost;
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


class _AnalysisBuckets {
  final List<FootballMatch> premium;
  final List<FootballMatch> value;
  final List<FootballMatch> watch;
  final List<FootballMatch> noBet;

  const _AnalysisBuckets({
    required this.premium,
    required this.value,
    required this.watch,
    required this.noBet,
  });
}

class _AnalysisRangeSelector extends StatelessWidget {
  final MatchDateRange selected;
  final ValueChanged<MatchDateRange> onChanged;

  const _AnalysisRangeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: MatchDateRange.values.map((range) {
          final isSelected = selected == range;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? KickMindTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    range.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : KickMindTheme.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AnalysisHero extends StatelessWidget {
  final String rangeLabel;
  final int matchesCount;
  final int premiumCount;
  final int valueCount;
  final int watchCount;
  final int noBetCount;
  final FootballMatch bestMatch;
  final double bestFinalScore;
  final double bestValueEdge;
  final double avgFinalScore;

  const _AnalysisHero({
    required this.rangeLabel,
    required this.matchesCount,
    required this.premiumCount,
    required this.valueCount,
    required this.watchCount,
    required this.noBetCount,
    required this.bestMatch,
    required this.bestFinalScore,
    required this.bestValueEdge,
    required this.avgFinalScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KickMindTheme.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: KickMindTheme.primary.withOpacity(0.20),
            blurRadius: 22,
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KI Analyse · $rangeLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$matchesCount Spiele · $premiumCount Premium · $valueCount Value · $watchCount Watch · $noBetCount No Bet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bestMatch.teamsLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(label: 'Final ${bestFinalScore.toStringAsFixed(1)}'),
              _HeroPill(label: 'AI ${bestMatch.aiScore}%'),
              _HeroPill(label: 'Value ${bestValueEdge >= 0 ? '+' : ''}${bestValueEdge.toStringAsFixed(1)}%'),
              _HeroPill(label: 'Ø Final ${avgFinalScore.toStringAsFixed(1)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;

  const _HeroPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _MetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.95,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: KickMindTheme.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: KickMindTheme.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: KickMindTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: KickMindTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: KickMindTheme.textDark,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: KickMindTheme.textMuted,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalysisTipTile extends StatelessWidget {
  final FootballMatch match;
  final int rank;
  final double finalScore;
  final double valueEdge;
  final double confidence;
  final String statusLabel;
  final Color statusColor;
  final String sourceLabel;
  final Color sourceColor;
  final String quoteLabel;
  final Color quoteColor;
  final String reason;
  final VoidCallback onTap;

  const _AnalysisTipTile({
    required this.match,
    required this.rank,
    required this.finalScore,
    required this.valueEdge,
    required this.confidence,
    required this.statusLabel,
    required this.statusColor,
    required this.sourceLabel,
    required this.sourceColor,
    required this.quoteLabel,
    required this.quoteColor,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final riskColor = KickMindTheme.riskColor(match.riskLevel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: rank == 1
                  ? KickMindTheme.primary.withOpacity(0.28)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank == 1 ? KickMindTheme.primary : KickMindTheme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank == 1 ? Colors.white : KickMindTheme.primary,
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
                          match.league,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KickMindTheme.textMuted,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          match.teamsLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KickMindTheme.textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: KickMindTheme.textMuted),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallPill(label: statusLabel, color: statusColor),
                  _SmallPill(label: sourceLabel, color: sourceColor),
                  _SmallPill(label: match.tipLabel, color: KickMindTheme.primary),
                  _SmallPill(label: 'Final ${finalScore.toStringAsFixed(1)}', color: KickMindTheme.primaryDark),
                  _SmallPill(label: 'AI ${match.aiScore}%', color: KickMindTheme.warning),
                  _SmallPill(label: 'Value ${valueEdge >= 0 ? '+' : ''}${valueEdge.toStringAsFixed(1)}%', color: KickMindTheme.success),
                  _SmallPill(label: 'Risk ${match.riskLevel}', color: riskColor),
                  _SmallPill(label: quoteLabel, color: quoteColor),
                  _SmallPill(label: 'Conf ${confidence.toStringAsFixed(0)}%', color: KickMindTheme.primary),
                ],
              ),
              const SizedBox(height: 10),
              _AnalysisReasonBox(
                text: reason,
                color: statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactAnalysisTile extends StatelessWidget {
  final FootballMatch match;
  final double finalScore;
  final double valueEdge;
  final String statusLabel;
  final Color statusColor;
  final String sourceLabel;
  final Color sourceColor;
  final String quoteLabel;
  final Color quoteColor;
  final String reason;
  final VoidCallback onTap;

  const _CompactAnalysisTile({
    required this.match,
    required this.finalScore,
    required this.valueEdge,
    required this.statusLabel,
    required this.statusColor,
    required this.sourceLabel,
    required this.sourceColor,
    required this.quoteLabel,
    required this.quoteColor,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SimpleInfoTile(
      icon: statusLabel == 'Watch' ? Icons.visibility_rounded : Icons.trending_up_rounded,
      iconColor: statusColor,
      title: match.teamsLabel,
      subtitle: '$statusLabel · $sourceLabel · $quoteLabel · ${match.tipLabel} · Final ${finalScore.toStringAsFixed(1)} · Value ${valueEdge >= 0 ? '+' : ''}${valueEdge.toStringAsFixed(1)}%',
      onTap: onTap,
    );
  }
}

class _RiskWarningTile extends StatelessWidget {
  final FootballMatch match;
  final double finalScore;
  final String quoteLabel;
  final Color quoteColor;
  final VoidCallback onTap;

  const _RiskWarningTile({
    required this.match,
    required this.finalScore,
    required this.quoteLabel,
    required this.quoteColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SimpleInfoTile(
      icon: Icons.warning_amber_rounded,
      iconColor: KickMindTheme.danger,
      title: match.teamsLabel,
      subtitle: '${match.riskLevel} · Final ${finalScore.toStringAsFixed(1)} · $quoteLabel',
      onTap: onTap,
    );
  }
}

class _SimpleInfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SimpleInfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: iconColor.withOpacity(0.16)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KickMindTheme.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KickMindTheme.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: KickMindTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisReasonBox extends StatelessWidget {
  final String text;
  final Color color;

  const _AnalysisReasonBox({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.psychology_alt_rounded, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: KickMindTheme.textDark,
                fontSize: 12.4,
                height: 1.28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AnalysisMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onRetry;

  const _AnalysisMessageState({
    required this.icon,
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: KickMindTheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 34, color: KickMindTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KickMindTheme.textDark,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KickMindTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Erneut laden'),
            ),
          ],
        ),
      ),
    );
  }
}
