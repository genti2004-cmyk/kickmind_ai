import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/scoring/odds_score_service.dart';
import 'package:kickmind_ai/features/odds/data/live_odds_service.dart';
import 'package:kickmind_ai/features/odds/domain/live_odds.dart';

class LiveOddsScreen extends StatefulWidget {
  const LiveOddsScreen({super.key});

  @override
  State<LiveOddsScreen> createState() => _LiveOddsScreenState();
}

enum _OddsFilter {
  all('Alle'),
  value('Value'),
  safe('Stabil'),
  risk('Risiko');

  final String label;

  const _OddsFilter(this.label);
}


enum _OddsDecision {
  premium('Premium Value', 'starker Markt mit Score, Value und Risiko im grünen Bereich'),
  value('Value Chance', 'positive Value-Kante, aber nicht ganz Premium'),
  stable('Stabil beobachten', 'solide Quote, aber noch kein klarer Value-Markt'),
  noBet('No Bet', 'Risiko oder Value passt aktuell nicht');

  final String label;
  final String explanation;

  const _OddsDecision(this.label, this.explanation);
}

class _LiveOddsScreenState extends State<LiveOddsScreen> {
  final LiveOddsService _oddsService = LiveOddsService();

  late Future<List<LiveOdds>> _future;
  _OddsFilter _filter = _OddsFilter.all;

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

  List<_OddsOpportunity> _buildOpportunities(List<LiveOdds> odds) {
    final result = <_OddsOpportunity>[];

    for (final item in odds) {
      final h2hMargin = _bookMargin([
        item.homeWin,
        item.draw,
        item.awayWin,
      ]);

      result.add(
        _OddsOpportunity.from(
          odds: item,
          marketLabel: '1',
          tipLabel: 'Heimsieg',
          value: item.homeWin,
          margin: h2hMargin,
          marketType: OddsMarketType.home,
        ),
      );

      result.add(
        _OddsOpportunity.from(
          odds: item,
          marketLabel: 'X',
          tipLabel: 'Unentschieden',
          value: item.draw,
          margin: h2hMargin,
          marketType: OddsMarketType.draw,
        ),
      );

      result.add(
        _OddsOpportunity.from(
          odds: item,
          marketLabel: '2',
          tipLabel: 'Auswärtssieg',
          value: item.awayWin,
          margin: h2hMargin,
          marketType: OddsMarketType.away,
        ),
      );

      if (item.over25 != null && item.under25 != null) {
        final totalMargin = _bookMargin([item.over25!, item.under25!]);

        result.add(
          _OddsOpportunity.from(
            odds: item,
            marketLabel: 'Ü2.5',
            tipLabel: 'Über 2.5 Tore',
            value: item.over25!,
            margin: totalMargin,
            marketType: OddsMarketType.over25,
          ),
        );

        result.add(
          _OddsOpportunity.from(
            odds: item,
            marketLabel: 'U2.5',
            tipLabel: 'Unter 2.5 Tore',
            value: item.under25!,
            margin: totalMargin,
            marketType: OddsMarketType.under25,
          ),
        );
      }

      if (item.bttsYes != null) {
        result.add(
          _OddsOpportunity.from(
            odds: item,
            marketLabel: 'BTTS',
            tipLabel: 'Beide Teams treffen',
            value: item.bttsYes!,
            margin: 0.07,
            marketType: OddsMarketType.btts,
          ),
        );
      }
    }

    result.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    return result;
  }

  List<_OddsOpportunity> _filterOpportunities(List<_OddsOpportunity> items) {
    switch (_filter) {
      case _OddsFilter.all:
        return items;
      case _OddsFilter.value:
        return items
            .where(
              (item) => item.decision == _OddsDecision.premium || item.decision == _OddsDecision.value,
        )
            .toList();
      case _OddsFilter.safe:
        return items
            .where(
              (item) => item.decision == _OddsDecision.stable ||
              (item.riskLevel == 'Niedrig' && item.decision != _OddsDecision.noBet),
        )
            .toList();
      case _OddsFilter.risk:
        return items.where((item) => item.decision == _OddsDecision.noBet).toList();
    }
  }

  double _bookMargin(List<double> values) {
    final implied = values
        .where((value) => value > 1.0)
        .map((value) => 1 / value)
        .fold<double>(0, (sum, value) => sum + value);

    return math.max(0, implied - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Live Quoten'),
        backgroundColor: const Color(0xFFF6F8FC),
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
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
              return _LiveOddsEmptyState(onRefresh: _refresh);
            }

            final opportunities = _buildOpportunities(odds);
            final filtered = _filterOpportunities(opportunities);
            final best = opportunities.isEmpty ? null : opportunities.first;
            final premiumCount = opportunities.where((item) => item.decision == _OddsDecision.premium).length;
            final valueCount = opportunities.where((item) => item.decision == _OddsDecision.value).length;
            final noBetCount = opportunities.where((item) => item.decision == _OddsDecision.noBet).length;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  sliver: SliverToBoxAdapter(
                    child: _OddsRadarHeader(
                      matchCount: odds.length,
                      opportunityCount: opportunities.length,
                      premiumCount: premiumCount,
                      valueCount: valueCount,
                      noBetCount: noBetCount,
                      best: best,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  sliver: SliverToBoxAdapter(
                    child: _FilterBar(
                      selected: _filter,
                      onChanged: (value) {
                        setState(() => _filter = value);
                      },
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Für diesen Filter gibt es aktuell keine passenden Quoten.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _OpportunityCard(
                          item: item,
                          rank: index + 1,
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LiveOddsEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _LiveOddsEmptyState({
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      children: [
        const Text(
          'Live Quoten',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Value, Risiko und Final Score werden automatisch berechnet, sobald Live-Odds verfügbar sind.',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.casino_rounded,
                  size: 34,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Keine Live-Quoten gefunden',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Die Quoten-Seite ist bereit. Sobald dein Odds-API-Key aktiv ist, werden hier Value, Risiko und Final Score automatisch berechnet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
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

class _OddsRadarHeader extends StatelessWidget {
  final int matchCount;
  final int opportunityCount;
  final int premiumCount;
  final int valueCount;
  final int noBetCount;
  final _OddsOpportunity? best;

  const _OddsRadarHeader({
    required this.matchCount,
    required this.opportunityCount,
    required this.premiumCount,
    required this.valueCount,
    required this.noBetCount,
    required this.best,
  });

  @override
  Widget build(BuildContext context) {
    final bestItem = best;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quoten Radar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$matchCount Spiele · $opportunityCount Märkte analysiert',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderMiniPill(label: 'Premium', value: premiumCount),
              _HeaderMiniPill(label: 'Value', value: valueCount),
              _HeaderMiniPill(label: 'No Bet', value: noBetCount),
            ],
          ),
          if (bestItem != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${bestItem.decision.label} · ${bestItem.marketLabel} · ${bestItem.odds.homeTeam} vs ${bestItem.odds.awayTeam}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeaderScore(value: bestItem.finalScore),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderMiniPill extends StatelessWidget {
  final String label;
  final int value;

  const _HeaderMiniPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeaderScore extends StatelessWidget {
  final double value;

  const _HeaderScore({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        value.toStringAsFixed(0),
        style: const TextStyle(
          color: Color(0xFF1E3A8A),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _OddsFilter selected;
  final ValueChanged<_OddsFilter> onChanged;

  const _FilterBar({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _OddsFilter.values.map((filter) {
        final active = selected == filter;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF1D4ED8) : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF1D4ED8)
                        : Colors.black.withOpacity(0.06),
                  ),
                  boxShadow: active
                      ? [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withOpacity(0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  filter.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF334155),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final _OddsOpportunity item;
  final int rank;

  const _OpportunityCard({
    required this.item,
    required this.rank,
  });

  Color get _accent => item.decisionColor;

  @override
  Widget build(BuildContext context) {
    final accent = _accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RankBadge(rank: rank, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${item.odds.homeTeam} vs ${item.odds.awayTeam}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _BookmakerBadge(text: item.odds.bookmaker),
            ],
          ),
          const SizedBox(height: 10),
          _DecisionBadge(
            label: item.decision.label,
            color: item.decisionColor,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MarketBox(
                label: item.marketLabel,
                value: item.value.toStringAsFixed(2),
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.tipLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Final',
                  value: item.finalScore.toStringAsFixed(0),
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  label: 'AI',
                  value: '${item.aiScore.toStringAsFixed(0)}%',
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  label: 'Value',
                  value: '${item.valueEdge >= 0 ? '+' : ''}${item.valueEdge.toStringAsFixed(1)}',
                  color: item.valueEdge >= 0
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Pill(
                text: 'Risiko: ${item.riskLevel}',
                color: item.riskColor,
              ),
              const SizedBox(width: 8),
              _Pill(
                text: 'Konf. ${item.confidence.toStringAsFixed(0)}%',
                color: const Color(0xFF475569),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.finalReason,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Aktualisiert: ${_formatDateTime(item.odds.updatedAt)}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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

class _DecisionBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DecisionBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final Color color;

  const _RankBadge({
    required this.rank,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        '#$rank',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _BookmakerBadge extends StatelessWidget {
  final String text;

  const _BookmakerBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.indigo,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MarketBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MarketBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.90),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}


class _OddsOpportunity {
  final LiveOdds odds;
  final String marketLabel;
  final String tipLabel;
  final double value;
  final double aiScore;
  final double finalScore;
  final double valueEdge;
  final double confidence;
  final String riskLevel;
  final Color riskColor;
  final _OddsDecision decision;
  final Color decisionColor;
  final String reason;
  final String finalReason;

  const _OddsOpportunity({
    required this.odds,
    required this.marketLabel,
    required this.tipLabel,
    required this.value,
    required this.aiScore,
    required this.finalScore,
    required this.valueEdge,
    required this.confidence,
    required this.riskLevel,
    required this.riskColor,
    required this.decision,
    required this.decisionColor,
    required this.reason,
    required this.finalReason,
  });

  factory _OddsOpportunity.from({
    required LiveOdds odds,
    required String marketLabel,
    required String tipLabel,
    required double value,
    required double margin,
    required OddsMarketType marketType,
  }) {
    final score = OddsScoreService.instance.evaluate(
      oddsValue: value,
      margin: margin,
      marketType: marketType,
    );
    final risk = score.riskLevel;
    final decision = _decisionFor(
      finalScore: score.finalScore,
      valueEdge: score.valueEdge,
      confidence: score.confidence,
      riskLevel: risk,
      oddsValue: value,
    );
    final color = _riskColor(risk);
    final decisionColor = _decisionColor(decision);
    final finalReason = _buildFinalReason(
      baseReason: score.reason,
      finalScore: score.finalScore,
      valueEdge: score.valueEdge,
      confidence: score.confidence,
      riskLevel: risk,
      oddsValue: value,
    );

    return _OddsOpportunity(
      odds: odds,
      marketLabel: marketLabel,
      tipLabel: tipLabel,
      value: value,
      aiScore: score.aiScore,
      finalScore: score.finalScore,
      valueEdge: score.valueEdge,
      confidence: score.confidence,
      riskLevel: risk,
      riskColor: color,
      decision: decision,
      decisionColor: decisionColor,
      reason: score.reason,
      finalReason: finalReason,
    );
  }

  static _OddsDecision _decisionFor({
    required double finalScore,
    required double valueEdge,
    required double confidence,
    required String riskLevel,
    required double oddsValue,
  }) {
    final decision = OddsScoreService.instance.decisionFor(
      finalScore: finalScore,
      valueEdge: valueEdge,
      confidence: confidence,
      riskLevel: riskLevel,
      oddsValue: oddsValue,
    );

    switch (decision.type) {
      case OddsMarketDecisionType.premium:
        return _OddsDecision.premium;
      case OddsMarketDecisionType.value:
        return _OddsDecision.value;
      case OddsMarketDecisionType.stable:
        return _OddsDecision.stable;
      case OddsMarketDecisionType.noBet:
        return _OddsDecision.noBet;
    }
  }

  static Color _decisionColor(_OddsDecision decision) {
    switch (decision) {
      case _OddsDecision.premium:
        return const Color(0xFF16A34A);
      case _OddsDecision.value:
        return const Color(0xFF2563EB);
      case _OddsDecision.stable:
        return const Color(0xFF64748B);
      case _OddsDecision.noBet:
        return const Color(0xFFEA580C);
    }
  }

  static String _buildFinalReason({
    required String baseReason,
    required double finalScore,
    required double valueEdge,
    required double confidence,
    required String riskLevel,
    required double oddsValue,
  }) {
    final coreDecision = OddsScoreService.instance.decisionFor(
      finalScore: finalScore,
      valueEdge: valueEdge,
      confidence: confidence,
      riskLevel: riskLevel,
      oddsValue: oddsValue,
    );

    return OddsScoreService.instance.finalReason(
      decision: coreDecision,
      baseReason: baseReason,
      finalScore: finalScore,
      valueEdge: valueEdge,
      confidence: confidence,
      riskLevel: riskLevel,
      oddsValue: oddsValue,
    );
  }

  static Color _riskColor(String label) {
    if (label == 'Niedrig') return const Color(0xFF16A34A);
    if (label == 'Mittel') return const Color(0xFF2563EB);
    return const Color(0xFFEA580C);
  }

}
