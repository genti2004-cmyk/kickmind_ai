import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/scoring/top_tip_score_service.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/analysis/presentation/analysis_screen.dart';
import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/presentation/kickmind_matches_screen.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';
import 'package:kickmind_ai/features/odds/presentation/live_odds_screen.dart';
import 'package:kickmind_ai/features/saved_tips/data/saved_tips_service.dart';
import 'package:kickmind_ai/features/saved_tips/presentation/saved_tips_screen.dart';
import 'package:kickmind_ai/features/top_tips/presentation/top_tips_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MatchRepositoryImpl _repository = MatchRepositoryImpl();
  final SavedTipsService _savedTipsService = SavedTipsService();
  final TopTipScoreService _scoreService = TopTipScoreService.instance;

  late Future<_HomeDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeDashboardData> _load() async {
    final results = await Future.wait<dynamic>([
      _repository.getMatches(range: MatchDateRange.today),
      _repository.getMatches(range: MatchDateRange.tomorrow),
      _repository.getMatches(range: MatchDateRange.next3Days),
      _repository.getMatches(range: MatchDateRange.next7Days),
      _savedTipsService.loadSavedTips(),
    ]);

    final today = List<FootballMatch>.from(results[0] as List);
    final tomorrow = List<FootballMatch>.from(results[1] as List);
    final next3Days = List<FootballMatch>.from(results[2] as List);
    final next7Days = List<FootballMatch>.from(results[3] as List);
    final saved = List<FootballMatch>.from(results[4] as List);

    today.sort(_compareByFinalScore);
    tomorrow.sort(_compareByFinalScore);
    next3Days.sort(_compareByFinalScore);
    next7Days.sort(_compareByFinalScore);
    saved.sort(_compareByFinalScore);

    return _HomeDashboardData(
      today: today,
      tomorrow: tomorrow,
      next3Days: next3Days,
      next7Days: next7Days,
      saved: saved,
    );
  }

  int _compareByFinalScore(FootballMatch a, FootballMatch b) {
    final scoreCompare = _scoreService.compareByFinalScore(a, b);
    if (scoreCompare != 0) return scoreCompare;
    return a.kickoff.compareTo(b.kickoff);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _openScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  void _openMatch(FootballMatch match) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
    ).then((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KickMindTheme.background,
      appBar: AppBar(
        title: const Text('KickMind AI'),
        backgroundColor: KickMindTheme.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_HomeDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _HomeStateMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Dashboard konnte nicht geladen werden',
              subtitle: 'Bitte prüfe die Verbindung und lade erneut.',
              onRefresh: _refresh,
            );
          }

          final data = snapshot.data ?? const _HomeDashboardData.empty();
          final best = data.bestMatch;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 156),
              children: [
                _DashboardHero(
                  data: data,
                  onOpenTopTips: () => _openScreen(const TopTipsScreen()),
                  onOpenMatches: () => _openScreen(const KickMindMatchesScreen()),
                ),
                const SizedBox(height: 14),
                _DashboardMetricGrid(
                  children: [
                    _DashboardMetricCard(
                      label: 'Heute',
                      value: '${data.today.length}',
                      subtitle: 'Spiele',
                      icon: Icons.today_rounded,
                      color: KickMindTheme.primary,
                      onTap: () => _openScreen(const KickMindMatchesScreen()),
                    ),
                    _DashboardMetricCard(
                      label: 'Morgen',
                      value: '${data.tomorrow.length}',
                      subtitle: 'Spiele',
                      icon: Icons.event_rounded,
                      color: KickMindTheme.success,
                      onTap: () => _openScreen(const KickMindMatchesScreen()),
                    ),
                    _DashboardMetricCard(
                      label: '3 Tage',
                      value: '${data.next3Days.length}',
                      subtitle: 'Analyse',
                      icon: Icons.view_week_rounded,
                      color: Colors.deepPurple,
                      onTap: () => _openScreen(const AnalysisScreen()),
                    ),
                    _DashboardMetricCard(
                      label: 'Meine Tipps',
                      value: '${data.saved.length}',
                      subtitle: 'gespeichert',
                      icon: Icons.bookmark_rounded,
                      color: Colors.indigo,
                      onTap: () => _openScreen(const SavedTipsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _HomeSectionTitle(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Schnellzugriff',
                  subtitle: 'Direkt zu den wichtigsten Bereichen.',
                ),
                const SizedBox(height: 10),
                _QuickActionRow(
                  actions: [
                    _QuickAction(
                      icon: Icons.sports_soccer_rounded,
                      label: 'Spiele',
                      color: KickMindTheme.primary,
                      onTap: () => _openScreen(const KickMindMatchesScreen()),
                    ),
                    _QuickAction(
                      icon: Icons.auto_graph_rounded,
                      label: 'Top Tipps',
                      color: KickMindTheme.success,
                      onTap: () => _openScreen(const TopTipsScreen()),
                    ),
                    _QuickAction(
                      icon: Icons.analytics_rounded,
                      label: 'Analyse',
                      color: Colors.deepPurple,
                      onTap: () => _openScreen(const AnalysisScreen()),
                    ),
                    _QuickAction(
                      icon: Icons.casino_rounded,
                      label: 'Quoten',
                      color: Colors.indigo,
                      onTap: () => _openScreen(const LiveOddsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _HomeSectionTitle(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Beste aktuelle Auswahl',
                  subtitle: 'Aus echten Matchdaten sortiert nach Final Score.',
                ),
                const SizedBox(height: 10),
                if (best == null)
                  _EmptyDashboardCard(onRefresh: _refresh)
                else
                  _BestMatchCard(
                    match: best,
                    score: _scoreService.score(best),
                    onTap: () => _openMatch(best),
                  ),
                const SizedBox(height: 16),
                const _HomeSectionTitle(
                  icon: Icons.bookmark_rounded,
                  title: 'Zuletzt gespeichert',
                  subtitle: 'Deine wichtigsten gespeicherten Tipps.',
                ),
                const SizedBox(height: 10),
                if (data.saved.isEmpty)
                  _SavedEmptyCard(onOpenTopTips: () => _openScreen(const TopTipsScreen()))
                else
                  ...data.saved.take(3).map(
                        (match) => _SavedMiniCard(
                      match: match,
                      score: _scoreService.score(match),
                      onTap: () => _openMatch(match),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeDashboardData {
  final List<FootballMatch> today;
  final List<FootballMatch> tomorrow;
  final List<FootballMatch> next3Days;
  final List<FootballMatch> next7Days;
  final List<FootballMatch> saved;

  const _HomeDashboardData({
    required this.today,
    required this.tomorrow,
    required this.next3Days,
    required this.next7Days,
    required this.saved,
  });

  const _HomeDashboardData.empty()
      : today = const <FootballMatch>[],
        tomorrow = const <FootballMatch>[],
        next3Days = const <FootballMatch>[],
        next7Days = const <FootballMatch>[],
        saved = const <FootballMatch>[];

  List<FootballMatch> get rankingSource {
    if (today.isNotEmpty) return today;
    if (tomorrow.isNotEmpty) return tomorrow;
    if (next3Days.isNotEmpty) return next3Days;
    return next7Days;
  }

  FootballMatch? get bestMatch => rankingSource.isEmpty ? null : rankingSource.first;
}

class _DashboardHero extends StatelessWidget {
  final _HomeDashboardData data;
  final VoidCallback onOpenTopTips;
  final VoidCallback onOpenMatches;

  const _DashboardHero({
    required this.data,
    required this.onOpenTopTips,
    required this.onOpenMatches,
  });

  @override
  Widget build(BuildContext context) {
    final totalVisible = data.next7Days.isNotEmpty
        ? data.next7Days.length
        : data.today.length + data.tomorrow.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071D2F), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: KickMindTheme.primary.withOpacity(0.22),
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.sports_soccer_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KickMind Radar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalVisible Spiele im Wochenblick · ${data.saved.length} gespeichert',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(text: '${data.today.length} Heute'),
              _HeroPill(text: '${data.tomorrow.length} Morgen'),
              _HeroPill(text: '${data.next3Days.length} 3 Tage'),
              _HeroPill(text: '${data.next7Days.length} Woche'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroButton(
                  label: 'Top Tipps',
                  icon: Icons.auto_awesome_rounded,
                  onTap: onOpenTopTips,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroButton(
                  label: 'Spiele öffnen',
                  icon: Icons.arrow_forward_rounded,
                  onTap: onOpenMatches,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String text;

  const _HeroPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _DashboardMetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.42,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: KickMindTheme.textMuted),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$label · $subtitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: KickMindTheme.textMuted,
                fontSize: 11.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HomeSectionTitle({
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
              const SizedBox(height: 3),
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

class _QuickActionRow extends StatelessWidget {
  final List<_QuickAction> actions;

  const _QuickActionRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: actions
          .map(
            (action) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: action == actions.last ? 0 : 8),
            child: action,
          ),
        ),
      )
          .toList(),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.14)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: KickMindTheme.textDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestMatchCard extends StatelessWidget {
  final FootballMatch match;
  final TopTipScore score;
  final VoidCallback onTap;

  const _BestMatchCard({
    required this.match,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);
    final isRealOdds = match.id.startsWith('odds_');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: KickMindTheme.primary.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.055),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SmallBadge(
                  text: isRealOdds ? 'Echte Quote' : 'Spielplan',
                  color: isRealOdds ? KickMindTheme.success : Colors.blueGrey,
                ),
                const Spacer(),
                Text(
                  match.kickoffLabel,
                  style: const TextStyle(
                    color: KickMindTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              match.teamsLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: KickMindTheme.textDark,
                fontSize: 18,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _SmallBadge(text: match.tipLabel, color: KickMindTheme.primary),
                _SmallBadge(text: 'Final ${score.finalScore.toStringAsFixed(1)}', color: KickMindTheme.primaryDark),
                _SmallBadge(text: 'AI ${match.aiScore}%', color: scoreColor),
                _SmallBadge(text: 'Quote ${match.odds.toStringAsFixed(2)}', color: Colors.indigo),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedMiniCard extends StatelessWidget {
  final FootballMatch match;
  final TopTipScore score;
  final VoidCallback onTap;

  const _SavedMiniCard({
    required this.match,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
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
                color: KickMindTheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                score.finalScore.toStringAsFixed(0),
                style: const TextStyle(
                  color: KickMindTheme.primary,
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${match.tipLabel} · AI ${match.aiScore}% · Quote ${match.odds.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KickMindTheme.textMuted,
                      fontSize: 12,
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
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
    );
  }
}

class _SavedEmptyCard extends StatelessWidget {
  final VoidCallback onOpenTopTips;

  const _SavedEmptyCard({required this.onOpenTopTips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.045)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KickMindTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.bookmark_border_rounded, color: KickMindTheme.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Noch keine gespeicherten Tipps. Öffne Top Tipps und speichere deine Auswahl.',
              style: TextStyle(
                color: KickMindTheme.textMuted,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
          IconButton(
            onPressed: onOpenTopTips,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyDashboardCard extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyDashboardCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.045)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_off_rounded, color: KickMindTheme.textMuted),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Aktuell keine Spiele im Dashboard.',
              style: TextStyle(
                color: KickMindTheme.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onRefresh,
            child: const Text('Laden'),
          ),
        ],
      ),
    );
  }
}

class _HomeStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;

  const _HomeStateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: KickMindTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KickMindTheme.textDark,
                fontSize: 18,
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Neu laden'),
            ),
          ],
        ),
      ),
    );
  }
}
