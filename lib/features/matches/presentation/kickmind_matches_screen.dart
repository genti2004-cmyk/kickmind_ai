import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/filters/presentation/filter_screen.dart';
import 'package:kickmind_ai/features/matches/data/api/football_api_service.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';

enum _DateRangeMode { today, tomorrow, threeDays, week }
enum _ViewMode { list, topTips, analysis }

class KickMindMatchesScreen extends StatefulWidget {
  const KickMindMatchesScreen({super.key});

  @override
  State<KickMindMatchesScreen> createState() => _KickMindMatchesScreenState();
}

class _KickMindMatchesScreenState extends State<KickMindMatchesScreen> {
  final FootballApiService _api = FootballApiService();
  final PredictionEngine _engine = const PredictionEngine();

  late Future<List<FootballMatch>> _future;
  _DateRangeMode _rangeMode = _DateRangeMode.today;
  _ViewMode _viewMode = _ViewMode.list;
  FilterResult? _activeFilter;

  @override
  void initState() {
    super.initState();
    _future = _loadMatches();
  }

  Future<List<FootballMatch>> _loadMatches({bool forceRefresh = false}) {
    switch (_rangeMode) {
      case _DateRangeMode.today:
        return _api.fetchTodayFixtures(forceRefresh: forceRefresh);
      case _DateRangeMode.tomorrow:
        return _api.fetchTomorrowFixtures(forceRefresh: forceRefresh);
      case _DateRangeMode.threeDays:
        return _api.fetchNext3DaysFixtures(forceRefresh: forceRefresh);
      case _DateRangeMode.week:
        return _api.fetchWeekFixtures(forceRefresh: forceRefresh);
    }
  }

  void _reload({bool forceRefresh = false}) {
    setState(() {
      _future = _loadMatches(forceRefresh: forceRefresh);
    });
  }

  void _changeRange(_DateRangeMode mode) {
    if (_rangeMode == mode) return;
    setState(() {
      _rangeMode = mode;
      _future = _loadMatches();
    });
  }

  Future<void> _openFilter(List<FootballMatch> matches) async {
    final leagues = matches.map((m) => m.league).where((e) => e.trim().isNotEmpty).toSet().toList()..sort();

    final result = await Navigator.of(context).push<FilterResult>(
      MaterialPageRoute(
        builder: (_) => FilterScreen(
          leagues: leagues,
          initialFilter: _activeFilter,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _activeFilter = result;
      _viewMode = _ViewMode.list;
    });
  }

  List<FootballMatch> _applyFilter(List<FootballMatch> matches) {
    final filter = _activeFilter;
    if (filter == null || !filter.isActive) return matches;

    return matches.where((m) {
      if (filter.league != null && m.league != filter.league) return false;
      if (filter.risk != null && m.riskLevel != filter.risk) return false;
      if (m.aiScore < filter.minScore) return false;
      return true;
    }).toList();
  }

  String get _rangeTitle {
    switch (_rangeMode) {
      case _DateRangeMode.today:
        return 'Heute';
      case _DateRangeMode.tomorrow:
        return 'Morgen';
      case _DateRangeMode.threeDays:
        return 'Nächste 3 Tage';
      case _DateRangeMode.week:
        return 'Diese Woche';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('KickMind AI'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFF071626),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: () => _reload(forceRefresh: true),
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
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () => _reload(forceRefresh: true),
            );
          }

          final allMatches = snapshot.data ?? const <FootballMatch>[];
          final filteredMatches = _applyFilter(allMatches);
          final topTips = _engine.rankTopTips(filteredMatches, limit: 5);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _ModeBar(
                rangeMode: _rangeMode,
                viewMode: _viewMode,
                filterActive: _activeFilter?.isActive ?? false,
                onRangeChanged: _changeRange,
                onViewChanged: (mode) => setState(() => _viewMode = mode),
                onFilterTap: () => _openFilter(allMatches),
              ),
              const SizedBox(height: 18),
              _HeroHeader(
                title: _rangeTitle,
                subtitle: '${filteredMatches.length} von ${allMatches.length} echten Spielen geladen',
                icon: Icons.sports_soccer_rounded,
              ),
              const SizedBox(height: 18),
              if (_activeFilter?.isActive ?? false) ...[
                _ActiveFilterBanner(
                  filter: _activeFilter!,
                  onClear: () => setState(() => _activeFilter = null),
                ),
                const SizedBox(height: 16),
              ],
              if (allMatches.isEmpty)
                _EmptyCard(
                  title: 'Keine Spiele gefunden',
                  text: 'Für diesen Zeitraum hat die API keine Fußballspiele geliefert. Es werden bewusst keine Dummy-Spiele angezeigt.',
                  onRetry: () => _reload(forceRefresh: true),
                )
              else if (filteredMatches.isEmpty)
                _EmptyCard(
                  title: 'Keine Spiele nach Filter',
                  text: 'Lockere den Filter für Liga, Risiko oder AI-Score.',
                  onRetry: () => setState(() => _activeFilter = null),
                )
              else ...[
                  if (_viewMode == _ViewMode.list) ...[
                    if (topTips.isNotEmpty) ...[
                      const _SectionTitle('🔥 Top Tipps heute'),
                      const SizedBox(height: 10),
                      ...topTips.take(3).map((m) => _TopMiniCard(match: m)),
                      const SizedBox(height: 18),
                    ],
                    const _SectionTitle('Alle Spiele'),
                    const SizedBox(height: 10),
                    ...filteredMatches.map((m) => _MatchCard(match: m)),
                  ] else if (_viewMode == _ViewMode.topTips) ...[
                    const _SectionTitle('Top Tipps nach AI Score'),
                    const SizedBox(height: 10),
                    ...topTips.asMap().entries.map((entry) => _TopTipCard(rank: entry.key + 1, match: entry.value)),
                  ] else ...[
                    _AnalysisPanel(matches: filteredMatches, topTips: topTips),
                  ],
                ],
            ],
          );
        },
      ),
    );
  }
}

class _ModeBar extends StatelessWidget {
  final _DateRangeMode rangeMode;
  final _ViewMode viewMode;
  final bool filterActive;
  final ValueChanged<_DateRangeMode> onRangeChanged;
  final ValueChanged<_ViewMode> onViewChanged;
  final VoidCallback onFilterTap;

  const _ModeBar({
    required this.rangeMode,
    required this.viewMode,
    required this.filterActive,
    required this.onRangeChanged,
    required this.onViewChanged,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PillButton(label: 'Heute', icon: Icons.sports_soccer_rounded, selected: rangeMode == _DateRangeMode.today, onTap: () => onRangeChanged(_DateRangeMode.today)),
          _PillButton(label: 'Morgen', icon: Icons.today_rounded, selected: rangeMode == _DateRangeMode.tomorrow, onTap: () => onRangeChanged(_DateRangeMode.tomorrow)),
          _PillButton(label: '3 Tage', icon: Icons.date_range_rounded, selected: rangeMode == _DateRangeMode.threeDays, onTap: () => onRangeChanged(_DateRangeMode.threeDays)),
          _PillButton(label: 'Woche', icon: Icons.calendar_month_rounded, selected: rangeMode == _DateRangeMode.week, onTap: () => onRangeChanged(_DateRangeMode.week)),
          _PillButton(label: 'Top Tipps', icon: Icons.local_fire_department_rounded, selected: viewMode == _ViewMode.topTips, onTap: () => onViewChanged(_ViewMode.topTips)),
          _PillButton(label: 'Analyse', icon: Icons.analytics_rounded, selected: viewMode == _ViewMode.analysis, onTap: () => onViewChanged(_ViewMode.analysis)),
          _PillButton(label: filterActive ? 'Filter aktiv' : 'Filter', icon: Icons.filter_alt_rounded, selected: filterActive, onTap: onFilterTap),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1565C0) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? const Color(0xFF1565C0) : const Color(0xFFD8E1EE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: selected ? Colors.white : const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF1565C0),
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

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HeroHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E9AF0)]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.20), blurRadius: 22, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFilterBanner extends StatelessWidget {
  final FilterResult filter;
  final VoidCallback onClear;

  const _ActiveFilterBanner({
    required this.filter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (filter.league != null) parts.add(filter.league!);
    if (filter.risk != null) parts.add('Risiko ${filter.risk}');
    if (filter.minScore > 50) parts.add('AI ab ${filter.minScore}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filter: ${parts.join(' · ')}',
              style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('Löschen')),
        ],
      ),
    );
  }
}

class _TopMiniCard extends StatelessWidget {
  final FootballMatch match;

  const _TopMiniCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(match.aiScore);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                match.teamsLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF172033), fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${match.tipLabel} · AI ${match.aiScore}',
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final FootballMatch match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(match.aiScore);
    final riskColor = _riskColor(match.riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.league,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  Text(match.kickoffLabel, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                match.teamsLabel,
                style: const TextStyle(color: Color(0xFF172033), fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(text: match.tipLabel, color: const Color(0xFF1565C0)),
                  _Badge(text: 'AI ${match.aiScore}', color: scoreColor),
                  _Badge(text: '${match.riskEmoji} ${match.riskLevel}', color: riskColor),
                  _Badge(text: 'Quote ${match.odds.toStringAsFixed(2)}', color: const Color(0xFF4F46E5)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                match.shortReason,
                style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w700, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTipCard extends StatelessWidget {
  final int rank;
  final FootballMatch match;

  const _TopTipCard({required this.rank, required this.match});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(match.aiScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.22)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                foregroundColor: color,
                child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.teamsLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF172033), fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(text: match.tipLabel, color: const Color(0xFF1565C0)),
                        _Badge(text: 'AI ${match.aiScore}', color: color),
                        _Badge(text: match.riskLevel, color: _riskColor(match.riskLevel)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisPanel extends StatelessWidget {
  final List<FootballMatch> matches;
  final List<FootballMatch> topTips;

  const _AnalysisPanel({
    required this.matches,
    required this.topTips,
  });

  @override
  Widget build(BuildContext context) {
    final avgAi = matches.isEmpty ? 0 : matches.map((m) => m.aiScore).fold<int>(0, (a, b) => a + b) / matches.length;
    final strong = matches.where((m) => m.isStrongTip).length;
    final lowRisk = matches.where((m) => m.riskLevel == 'Niedrig').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 18),
        const _SectionTitle('Top 3 Analyse'),
        const SizedBox(height: 10),
        ...topTips.take(3).map((m) => _MatchCard(match: m)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1565C0))),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF172033), fontSize: 20, fontWeight: FontWeight.w900),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String text;
  final VoidCallback onRetry;

  const _EmptyCard({
    required this.title,
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.black54, height: 1.35, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFF1565C0)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Erneut laden')),
          ],
        ),
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 82) return const Color(0xFF16A34A);
  if (score >= 70) return const Color(0xFFF59E0B);
  return const Color(0xFFDC2626);
}

Color _riskColor(String risk) {
  final value = risk.toLowerCase();
  if (value.contains('niedrig') || value.contains('low')) return const Color(0xFF16A34A);
  if (value.contains('mittel') || value.contains('medium')) return const Color(0xFFF59E0B);
  return const Color(0xFFDC2626);
}
