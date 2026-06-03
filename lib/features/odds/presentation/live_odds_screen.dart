import 'dart:math' as math;

import 'package:flutter/material.dart';
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

class _LiveOddsScreenState extends State<LiveOddsScreen> {
  final LiveOddsService _oddsService = const LiveOddsService();

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
          marketType: _MarketType.home,
        ),
      );

      result.add(
        _OddsOpportunity.from(
          odds: item,
          marketLabel: 'X',
          tipLabel: 'Unentschieden',
          value: item.draw,
          margin: h2hMargin,
          marketType: _MarketType.draw,
        ),
      );

      result.add(
        _OddsOpportunity.from(
          odds: item,
          marketLabel: '2',
          tipLabel: 'Auswärtssieg',
          value: item.awayWin,
          margin: h2hMargin,
          marketType: _MarketType.away,
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
            marketType: _MarketType.over25,
          ),
        );

        result.add(
          _OddsOpportunity.from(
            odds: item,
            marketLabel: 'U2.5',
            tipLabel: 'Unter 2.5 Tore',
            value: item.under25!,
            margin: totalMargin,
            marketType: _MarketType.under25,
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
            marketType: _MarketType.btts,
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
        return items.where((item) => item.valueEdge >= 3.0).toList();
      case _OddsFilter.safe:
        return items.where((item) => item.riskLevel == 'Niedrig').toList();
      case _OddsFilter.risk:
        return items.where((item) => item.riskLevel == 'Hoch').toList();
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

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  sliver: SliverToBoxAdapter(
                    child: _OddsRadarHeader(
                      matchCount: odds.length,
                      opportunityCount: opportunities.length,
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
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 120),
      children: [
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
              Text(
                'Die Quoten-Seite ist bereit. Sobald dein Odds-API-Key aktiv ist, werden hier Value, Risiko und Final Score automatisch berechnet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
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
  final _OddsOpportunity? best;

  const _OddsRadarHeader({
    required this.matchCount,
    required this.opportunityCount,
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
                      '${bestItem.marketLabel} · ${bestItem.odds.homeTeam} vs ${bestItem.odds.awayTeam}',
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

  Color get _accent {
    if (item.finalScore >= 72) return const Color(0xFF16A34A);
    if (item.finalScore >= 62) return const Color(0xFF2563EB);
    if (item.riskLevel == 'Hoch') return const Color(0xFFEA580C);
    return const Color(0xFF64748B);
  }

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
            item.reason,
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

enum _MarketType {
  home,
  draw,
  away,
  over25,
  under25,
  btts,
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
  final String reason;

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
    required this.reason,
  });

  factory _OddsOpportunity.from({
    required LiveOdds odds,
    required String marketLabel,
    required String tipLabel,
    required double value,
    required double margin,
    required _MarketType marketType,
  }) {
    final implied = value > 1 ? (1 / value) * 100 : 0.0;
    final oddsQuality = _oddsQuality(value);
    final marketBias = _marketBias(marketType);
    final marginPenalty = math.min(10.0, margin * 100 * 0.65);
    final aiScore = (implied + oddsQuality + marketBias - marginPenalty)
        .clamp(18.0, 92.0)
        .toDouble();
    final valueEdge = aiScore - implied;
    final riskPenalty = _riskPenalty(value);
    final finalScore = (aiScore + (valueEdge * 1.25) - riskPenalty)
        .clamp(0.0, 99.0)
        .toDouble();
    final confidence = ((aiScore * 0.72) + (finalScore * 0.28))
        .clamp(0.0, 99.0)
        .toDouble();

    final risk = _riskLabel(value);
    final color = _riskColor(risk);
    final reason = _reason(
      value: value,
      finalScore: finalScore,
      valueEdge: valueEdge,
      risk: risk,
      margin: margin,
    );

    return _OddsOpportunity(
      odds: odds,
      marketLabel: marketLabel,
      tipLabel: tipLabel,
      value: value,
      aiScore: aiScore,
      finalScore: finalScore,
      valueEdge: valueEdge,
      confidence: confidence,
      riskLevel: risk,
      riskColor: color,
      reason: reason,
    );
  }

  static double _oddsQuality(double value) {
    if (value >= 1.55 && value <= 2.25) return 10;
    if (value > 2.25 && value <= 3.20) return 5;
    if (value >= 1.30 && value < 1.55) return 3;
    if (value > 3.20) return -5;
    return -7;
  }

  static double _marketBias(_MarketType type) {
    switch (type) {
      case _MarketType.home:
        return 4;
      case _MarketType.away:
        return 1;
      case _MarketType.draw:
        return -4;
      case _MarketType.over25:
        return 3;
      case _MarketType.under25:
        return 1;
      case _MarketType.btts:
        return 2;
    }
  }

  static double _riskPenalty(double value) {
    if (value <= 1.70) return 3;
    if (value <= 2.30) return 6;
    if (value <= 3.10) return 12;
    return 20;
  }

  static String _riskLabel(double value) {
    if (value <= 1.75) return 'Niedrig';
    if (value <= 2.65) return 'Mittel';
    return 'Hoch';
  }

  static Color _riskColor(String label) {
    if (label == 'Niedrig') return const Color(0xFF16A34A);
    if (label == 'Mittel') return const Color(0xFF2563EB);
    return const Color(0xFFEA580C);
  }

  static String _reason({
    required double value,
    required double finalScore,
    required double valueEdge,
    required String risk,
    required double margin,
  }) {
    final edgeText = valueEdge >= 0
        ? 'positiver Value Edge'
        : 'kein klarer Value Edge';
    final marginText = margin <= 0.08
        ? 'faire Markt-Marge'
        : 'erhöhte Buchmacher-Marge';

    if (finalScore >= 72) {
      return 'Starker Quoten-Kandidat: $edgeText, $marginText und Risiko $risk bei Quote ${value.toStringAsFixed(2)}.';
    }

    if (finalScore >= 60) {
      return 'Beobachten: solide Quote mit brauchbarer Bewertung, aber nicht als Blind-Tipp spielen.';
    }

    return 'Nur prüfen: Die Quote ist aktuell nicht stark genug für eine klare Top-Tipp-Empfehlung.';
  }
}
