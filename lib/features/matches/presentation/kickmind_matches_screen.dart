import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/scoring/top_tip_score_service.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/filters/presentation/filter_screen.dart';
import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/presentation/widgets/match_card.dart';
import 'package:kickmind_ai/features/top_tips/presentation/top_tips_screen.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';
import 'package:kickmind_ai/features/saved_tips/data/saved_tips_service.dart';

class KickMindMatchesScreen extends StatefulWidget {
  const KickMindMatchesScreen({super.key});

  @override
  State<KickMindMatchesScreen> createState() => _KickMindMatchesScreenState();
}

class _KickMindMatchesScreenState extends State<KickMindMatchesScreen> {
  final MatchRepositoryImpl _repo = MatchRepositoryImpl();
  final TopTipScoreService _scoreService = TopTipScoreService.instance;
  final SavedTipsService _savedTipsService = SavedTipsService();

  MatchDateRange _range = MatchDateRange.today;
  FilterResult? _activeFilter;
  late Future<List<FootballMatch>> _future;
  Set<String> _savedMatchIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _repo.getMatches(range: _range);
    _loadSavedIds();
  }

  void _reload() {
    setState(() {
      _future = _repo.getMatches(range: _range);
    });
    _loadSavedIds();
  }

  void _changeRange(MatchDateRange range) {
    if (_range == range) return;
    setState(() {
      _range = range;
      _future = _repo.getMatches(range: _range);
    });
  }

  Future<void> _openFilter(List<FootballMatch> matches) async {
    final leagues = matches.map((m) => m.league).where((e) => e.trim().isNotEmpty).toSet().toList()..sort();

    final result = await Navigator.push<FilterResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FilterScreen(
          availableLeagues: leagues,
          initialFilter: _activeFilter,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() => _activeFilter = result);
    }
  }

  void _resetFilter() {
    setState(() => _activeFilter = null);
  }

  List<FootballMatch> _applyFilter(List<FootballMatch> matches) {
    final filter = _activeFilter;
    if (filter == null) return matches;

    return matches.where((m) {
      if (filter.league != null && filter.league!.isNotEmpty && m.league != filter.league) {
        return false;
      }

      if (filter.risk != null && filter.risk!.isNotEmpty && m.riskLevel != filter.risk) {
        return false;
      }

      if (m.aiScore < filter.minScore) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _loadSavedIds() async {
    final saved = await _savedTipsService.loadSavedTips();
    if (!mounted) return;
    setState(() {
      _savedMatchIds = saved.map((m) => m.id).toSet();
    });
  }

  Future<void> _toggleSavedTip(FootballMatch match) async {
    final isSaved = _savedMatchIds.contains(match.id);

    if (isSaved) {
      await _savedTipsService.removeTip(match.id);
    } else {
      await _savedTipsService.saveTip(match);
    }

    if (!mounted) return;
    setState(() {
      if (isSaved) {
        _savedMatchIds.remove(match.id);
      } else {
        _savedMatchIds.add(match.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSaved ? 'Tipp entfernt' : 'Tipp gespeichert'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KickMindTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF061B2E),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 78,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KickMind AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_range.label} · AI Radar',
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x1FFFFFFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: IconButton(
                tooltip: 'Aktualisieren',
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<FootballMatch>>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final rawMatches = snapshot.data ?? <FootballMatch>[];
            final matches = _applyFilter(rawMatches);
            final rankedMatches = [...matches]..sort(_scoreService.compareByFinalScore);
            final premiumTips = rankedMatches.where((m) => _scoreService.score(m).isRecommended).toList();
            final valueTips = rankedMatches.where((m) {
              final score = _scoreService.score(m);
              return score.isValueBet && !score.isRecommended && !score.isNoBet;
            }).toList();
            final visibleTopTips = rankedMatches.where((m) => !_scoreService.score(m).isNoBet).take(5).toList();
            final topPick = premiumTips.isNotEmpty ? premiumTips.first : null;
            final valuePick = valueTips.isNotEmpty ? valueTips.first : _bestValuePick(matches);
            final strongCount = premiumTips.length;
            final valueCount = rankedMatches.where((m) => _scoreService.score(m).isValueBet).length;
            final avgFinal = matches.isEmpty
                ? 0
                : (matches.fold<double>(0, (sum, m) => sum + _scoreService.score(m).finalScore) / matches.length).round();

            if (loading) {
              return const _LoadingState();
            }

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
                children: [
                  _StartHero(
                    rangeLabel: _range.label,
                    matchCount: matches.length,
                    avgFinal: avgFinal,
                    strongCount: strongCount,
                    valueCount: valueCount,
                    onFilterTap: () => _openFilter(rawMatches),
                    onTopTipsTap: _openTopTips,
                  ),
                  const SizedBox(height: 10),

                  _RangeSelector(
                    selected: _range,
                    onChanged: _changeRange,
                  ),
                  const SizedBox(height: 10),

                  if (_activeFilter != null)
                    _ActiveFilterBanner(
                      filter: _activeFilter!,
                      onReset: _resetFilter,
                    ),

                  if (topPick != null) ...[
                    _SectionHeader(
                      title: '🔥 Premium Top Pick',
                      subtitle: 'Final-Score Empfehlung',
                      actionLabel: 'Details',
                      onActionTap: () => _openDetail(topPick),
                    ),
                    const SizedBox(height: 10),
                    _HighlightCard(
                      match: topPick,
                      icon: Icons.local_fire_department_rounded,
                      title: 'Top Pick',
                      accentColor: KickMindTheme.scoreColor(topPick.aiScore),
                      badgeText: _decisionLabel(topPick),
                      footerText: _decisionReason(topPick),
                      isSaved: _savedMatchIds.contains(topPick.id),
                      onSaveTap: () => _toggleSavedTip(topPick),
                      onTap: () => _openDetail(topPick),
                    ),
                    const SizedBox(height: 18),
                  ],

                  if (valuePick != null) ...[
                    _SectionHeader(
                      title: '💰 Beste Value Bet',
                      subtitle: 'Quote gegen AI-Wahrscheinlichkeit',
                      actionLabel: 'Öffnen',
                      onActionTap: () => _openDetail(valuePick),
                    ),
                    const SizedBox(height: 10),
                    _HighlightCard(
                      match: valuePick,
                      icon: Icons.attach_money_rounded,
                      title: 'Value Chance',
                      accentColor: KickMindTheme.success,
                      badgeText: _decisionLabel(valuePick),
                      footerText: _decisionReason(valuePick),
                      isSaved: _savedMatchIds.contains(valuePick.id),
                      onSaveTap: () => _toggleSavedTip(valuePick),
                      onTap: () => _openDetail(valuePick),
                    ),
                    const SizedBox(height: 18),
                  ],

                  _QuickStatsGrid(
                    matchCount: matches.length,
                    strongCount: strongCount,
                    valueCount: valueCount,
                  ),
                  const SizedBox(height: 18),

                  if (visibleTopTips.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Top 3 Premium-Auswahl',
                      subtitle: 'Beste Signale aus Final-Score',
                      actionLabel: 'Alle',
                      onActionTap: _openTopTips,
                    ),
                    const SizedBox(height: 10),
                    ...visibleTopTips.take(3).map(
                          (m) => _TopTipMiniCard(
                        match: m,
                        score: _scoreService.score(m),
                        isSaved: _savedMatchIds.contains(m.id),
                        onSaveTap: () => _toggleSavedTip(m),
                        onTap: () => _openDetail(m),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  _SectionHeader(
                    title: _range.label,
                    subtitle: '${matches.length} Spiele gefunden',
                    actionLabel: _activeFilter == null ? 'Filter' : 'Reset',
                    onActionTap: _activeFilter == null ? () => _openFilter(rawMatches) : _resetFilter,
                  ),
                  const SizedBox(height: 10),

                  if (matches.isEmpty)
                    const _EmptyState()
                  else
                    ...matches.map(
                          (match) => MatchCard(
                        match: match,
                        onTap: () => _openDetail(match),
                        trailing: _SaveTipChip(
                          isSaved: _savedMatchIds.contains(match.id),
                          isValueBet: _scoreService.score(match).isValueBet,
                          onTap: () => _toggleSavedTip(match),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDetail(FootballMatch match) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
    ).then((_) => _loadSavedIds());
  }

  void _openTopTips() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TopTipsScreen()),
    );
  }

  FootballMatch? _bestValuePick(List<FootballMatch> matches) {
    final candidates = matches.where(_isValueCandidate).toList()
      ..sort((a, b) => _valueEdge(b).compareTo(_valueEdge(a)));
    return candidates.isEmpty ? null : candidates.first;
  }

  bool _isValueCandidate(FootballMatch match) {
    return _scoreService.score(match).isValueBet;
  }

  double _valueEdge(FootballMatch match) {
    return _scoreService.calculateValueEdge(match);
  }

  String _decisionLabel(FootballMatch match) {
    final score = _scoreService.score(match);
    return '${score.recommendationLabel} · Final ${score.finalScore.toStringAsFixed(0)}';
  }

  String _decisionReason(FootballMatch match) {
    final score = _scoreService.score(match);
    final edgeText = score.valueEdge >= 0
        ? '+${score.valueEdge.toStringAsFixed(1)}%'
        : '${score.valueEdge.toStringAsFixed(1)}%';
    return '${score.recommendationLabel} · AI ${match.aiScore}% · Edge $edgeText · Risiko ${match.riskLevel} · Quote ${match.odds.toStringAsFixed(2)}';
  }
}

class _StartHero extends StatelessWidget {
  final String rangeLabel;
  final int matchCount;
  final int avgFinal;
  final int strongCount;
  final int valueCount;
  final VoidCallback onFilterTap;
  final VoidCallback onTopTipsTap;

  const _StartHero({
    required this.rangeLabel,
    required this.matchCount,
    required this.avgFinal,
    required this.strongCount,
    required this.valueCount,
    required this.onFilterTap,
    required this.onTopTipsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF00A676)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KickMindTheme.primary.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
                child: const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KickMind AI Radar',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$rangeLabel · $matchCount Spiele · Ø Final $avgFinal',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onFilterTap,
                icon: const Icon(Icons.filter_alt_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.16),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _HeroMetric(label: 'Premium', value: '$strongCount')),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: 'Value', value: '$valueCount')),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: 'Ø Final', value: '$avgFinal')),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTopTipsTap,
              icon: const Icon(Icons.emoji_events_rounded),
              label: const Text('Alle Top Tipps öffnen'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: KickMindTheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
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
        children: MatchDateRange.values.map((range) {
          final active = range == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              label: Text(range.label),
              onSelected: (_) => onChanged(range),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActiveFilterBanner extends StatelessWidget {
  final FilterResult filter;
  final VoidCallback onReset;

  const _ActiveFilterBanner({required this.filter, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (filter.league != null) 'Liga: ${filter.league}',
      if (filter.risk != null) 'Risiko: ${filter.risk}',
      'AI ≥ ${filter.minScore}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KickMindTheme.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KickMindTheme.warning.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: KickMindTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filter aktiv: ${parts.join(' • ')}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: onReset, child: const Text('Reset')),
        ],
      ),
    );
  }
}

class _QuickStatsGrid extends StatelessWidget {
  final int matchCount;
  final int strongCount;
  final int valueCount;

  const _QuickStatsGrid({
    required this.matchCount,
    required this.strongCount,
    required this.valueCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Spiele', value: '$matchCount', icon: Icons.sports_soccer_rounded, color: KickMindTheme.primary)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Premium', value: '$strongCount', icon: Icons.emoji_events_rounded, color: KickMindTheme.accent)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Value', value: '$valueCount', icon: Icons.attach_money_rounded, color: KickMindTheme.success)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KickMindTheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: KickMindTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final FootballMatch match;
  final IconData icon;
  final String title;
  final Color accentColor;
  final String badgeText;
  final String footerText;
  final bool isSaved;
  final VoidCallback onSaveTap;
  final VoidCallback onTap;

  const _HighlightCard({
    required this.match,
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.badgeText,
    required this.footerText,
    required this.isSaved,
    required this.onSaveTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KickMindTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withOpacity(0.18)),
          boxShadow: [BoxShadow(color: accentColor.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 9))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(15)),
                  child: Icon(icon, color: accentColor, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(match.teamsLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isSaved ? 'Tipp entfernen' : 'Tipp speichern',
                  onPressed: onSaveTap,
                  icon: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isSaved ? KickMindTheme.primary : KickMindTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Badge(text: badgeText, color: accentColor),
                _Badge(text: '${match.riskEmoji} ${match.riskLevel}', color: KickMindTheme.riskColor(match.riskLevel)),
                _Badge(text: 'Quote ${match.odds.toStringAsFixed(2)}', color: Colors.indigo),
              ],
            ),
            if (footerText.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(footerText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KickMindTheme.textMuted, height: 1.35, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopTipMiniCard extends StatelessWidget {
  final FootballMatch match;
  final TopTipScore score;
  final bool isSaved;
  final VoidCallback onSaveTap;
  final VoidCallback onTap;

  const _TopTipMiniCard({required this.match, required this.score, required this.isSaved, required this.onSaveTap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(score);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${score.isValueBet ? '💰 ' : ''}${match.teamsLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(score.recommendationLabel, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Final ${score.finalScore.toStringAsFixed(0)}', style: const TextStyle(color: KickMindTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: isSaved ? 'Tipp entfernen' : 'Tipp speichern',
              onPressed: onSaveTap,
              icon: Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isSaved ? KickMindTheme.primary : KickMindTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(TopTipScore score) {
    if (score.isRecommended) return KickMindTheme.success;
    if (score.isValueBet) return KickMindTheme.accent;
    if (score.isNoBet) return KickMindTheme.danger;
    return KickMindTheme.warning;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _SectionHeader({required this.title, required this.subtitle, this.actionLabel, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          TextButton(onPressed: onActionTap, child: Text(actionLabel!)),
      ],
    );
  }
}


class _SaveTipChip extends StatelessWidget {
  final bool isSaved;
  final bool isValueBet;
  final VoidCallback onTap;

  const _SaveTipChip({
    required this.isSaved,
    required this.isValueBet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (isValueBet) const _MiniValueBadge(),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isSaved ? KickMindTheme.primary : KickMindTheme.textMuted).withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: (isSaved ? KickMindTheme.primary : KickMindTheme.textMuted).withOpacity(0.20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 15,
                  color: isSaved ? KickMindTheme.primary : KickMindTheme.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  isSaved ? 'Gespeichert' : 'Speichern',
                  style: TextStyle(
                    color: isSaved ? KickMindTheme.primary : KickMindTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniValueBadge extends StatelessWidget {
  const _MiniValueBadge();

  @override
  Widget build(BuildContext context) {
    return const _Badge(text: '💰 Value', color: KickMindTheme.success);
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: KickMindTheme.surface, borderRadius: BorderRadius.circular(18)),
      child: const Column(
        children: [
          Icon(Icons.sports_soccer_rounded, size: 42),
          SizedBox(height: 12),
          Text('Keine Spiele gefunden', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          SizedBox(height: 6),
          Text('Ändere den Zeitraum oder setze den Filter zurück.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
      children: const [
        _SkeletonBox(height: 132),
        SizedBox(height: 14),
        _SkeletonBox(height: 44),
        SizedBox(height: 14),
        _SkeletonBox(height: 104),
        SizedBox(height: 12),
        _SkeletonBox(height: 104),
        SizedBox(height: 12),
        _SkeletonBox(height: 104),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;

  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 8))],
      ),
    );
  }
}
