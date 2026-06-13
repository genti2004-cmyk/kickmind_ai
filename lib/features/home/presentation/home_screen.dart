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
    // Fast Start: Die Startseite darf den ersten Bildschirm nicht durch
    // Wochen-/ESPN-/SportsDB-Abfragen blockieren. Home lädt deshalb nur Heute
    // plus Merkliste. Morgen/3 Tage/Woche bleiben den Fachseiten vorbehalten.
    final results = await Future.wait<dynamic>([
      _repository.getMatches(range: MatchDateRange.today),
      _savedTipsService.loadSavedTips(),
    ]);

    final rawToday = List<FootballMatch>.from(results[0] as List);
    final rawSaved = List<FootballMatch>.from(results[1] as List);

    final today = _prepareDashboardMatches(rawToday, limit: 12);
    final saved = _prepareSavedMatches(rawSaved, limit: 12);

    return _HomeDashboardData(
      today: today,
      tomorrow: const <FootballMatch>[],
      next3Days: const <FootballMatch>[],
      next7Days: const <FootballMatch>[],
      saved: saved,
      todayCount: rawToday.length,
      tomorrowCount: 0,
      next3DaysCount: 0,
      next7DaysCount: 0,
      savedCount: rawSaved.length,
    );
  }

  List<FootballMatch> _matchesForDay(List<FootballMatch> matches, DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return matches.where((match) {
      final kickoffDay = DateTime(
        match.kickoff.year,
        match.kickoff.month,
        match.kickoff.day,
      );
      return kickoffDay == target;
    }).toList(growable: false);
  }

  List<FootballMatch> _matchesForDays(
      List<FootballMatch> matches,
      DateTime start,
      int days,
      ) {
    final from = DateTime(start.year, start.month, start.day);
    final to = from.add(Duration(days: days));
    return matches.where((match) {
      return !match.kickoff.isBefore(from) && match.kickoff.isBefore(to);
    }).toList(growable: false);
  }

  List<FootballMatch> _prepareDashboardMatches(
      List<FootballMatch> source, {
        required int limit,
      }) {
    final seen = <String>{};
    final unique = <FootballMatch>[];

    for (final match in source) {
      if (!_isRealTeamName(match.homeTeam) || !_isRealTeamName(match.awayTeam)) continue;
      final key = _matchDedupeKey(match);
      if (seen.add(key)) unique.add(match);
    }

    unique.sort(_compareByDashboardQuality);
    return unique.take(limit).toList(growable: false);
  }

  List<FootballMatch> _prepareSavedMatches(
      List<FootballMatch> source, {
        required int limit,
      }) {
    final seen = <String>{};
    final unique = <FootballMatch>[];

    for (final match in source) {
      final key = match.id.trim().isEmpty ? _matchDedupeKey(match) : match.id.trim();
      if (seen.add(key)) unique.add(match);
    }

    unique.sort(_compareByFinalScore);
    return unique.take(limit).toList(growable: false);
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

  List<FootballMatch> _bestDashboardMatches(_HomeDashboardData data) {
    final pool = <FootballMatch>[
      ...data.today,
      ...data.tomorrow,
      ...data.next3Days,
    ];

    final seen = <String>{};
    final unique = <FootballMatch>[];
    for (final match in pool) {
      if (!_isRealTeamName(match.homeTeam) || !_isRealTeamName(match.awayTeam)) continue;
      final key = _matchDedupeKey(match);
      if (seen.add(key)) unique.add(match);
    }

    unique.sort(_compareByDashboardQuality);

    final strong = unique.where((match) {
      final decision = _scoreService.decision(match);
      final score = _scoreService.score(match);
      if (decision.type == TopTipDecisionType.noBet) return false;
      if (_isHighRisk(match) && score.finalScore < 70) return false;
      return score.finalScore >= 55;
    }).toList();

    if (strong.isNotEmpty) return strong.take(3).toList();
    return unique.take(3).toList();
  }

  int _compareByDashboardQuality(FootballMatch a, FootballMatch b) {
    final qualityCompare = _dashboardQualityScore(b).compareTo(_dashboardQualityScore(a));
    if (qualityCompare != 0) return qualityCompare;
    return a.kickoff.compareTo(b.kickoff);
  }

  double _dashboardQualityScore(FootballMatch match) {
    final score = _scoreService.score(match);
    final decision = _scoreService.decision(match);
    final decisionBoost = switch (decision.type) {
      TopTipDecisionType.premium => 12.0,
      TopTipDecisionType.value => 8.0,
      TopTipDecisionType.watch => 2.0,
      TopTipDecisionType.noBet => -22.0,
    };
    final sourceBoost = match.id.startsWith('odds_') ? 8.0 : 1.5;
    final riskBoost = _isHighRisk(match) ? -14.0 : 3.0;
    final todayBoost = _kickoffPriorityBoost(match.kickoff);
    return score.finalScore + decisionBoost + sourceBoost + riskBoost + todayBoost;
  }

  double _kickoffPriorityBoost(DateTime kickoff) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDay = DateTime(kickoff.year, kickoff.month, kickoff.day);
    final diff = matchDay.difference(today).inDays;
    if (diff == 0) return 3.0;
    if (diff == 1) return 2.0;
    if (diff >= 2 && diff <= 3) return 1.0;
    return 0.0;
  }

  bool _isHighRisk(FootballMatch match) {
    final risk = match.riskLevel.toLowerCase().trim();
    return risk == 'hoch' || risk == 'high';
  }

  bool _isRealTeamName(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    if (RegExp(r'^(heimteam|auswärtsteam|auswaertsteam)\s*\d+$').hasMatch(lower)) return false;
    if (RegExp(r'^\d+$').hasMatch(text)) return false;
    return true;
  }

  String _matchDedupeKey(FootballMatch match) {
    final home = match.homeTeam.trim().toLowerCase();
    final away = match.awayTeam.trim().toLowerCase();
    final day = DateTime(match.kickoff.year, match.kickoff.month, match.kickoff.day);
    return '$home|$away|${day.toIso8601String()}';
  }

  String _sourceLabel(FootballMatch match) {
    if (match.id.startsWith('odds_')) return 'Echte Quote';
    if (match.id.startsWith('espn_')) return 'ESPN';
    if (match.id.startsWith('sportsdb_')) return 'TheSportsDB';
    if (match.id.startsWith('fixture_')) return 'API-Football';
    return 'Spielplan';
  }

  Color _sourceColor(FootballMatch match) {
    if (match.id.startsWith('odds_')) return KickMindTheme.success;
    if (match.id.startsWith('espn_')) return Colors.deepPurple;
    if (match.id.startsWith('sportsdb_')) return Colors.blueGrey;
    if (match.id.startsWith('fixture_')) return KickMindTheme.primary;
    return Colors.blueGrey;
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
          final bestMatches = _bestDashboardMatches(data);
          final best = bestMatches.isNotEmpty ? bestMatches.first : null;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 156),
              children: [
                _DashboardHero(
                  data: data,
                  bestMatch: best,
                  bestScore: best == null ? null : _scoreService.score(best),
                  bestDecisionLabel: best == null ? null : _scoreService.decision(best).shortLabel,
                  onOpenTopTips: () => _openScreen(const TopTipsScreen()),
                  onOpenMatches: () => _openScreen(const KickMindMatchesScreen()),
                ),
                const SizedBox(height: 14),
                _DashboardMetricGrid(
                  children: [
                    _DashboardMetricCard(
                      label: 'Heute',
                      value: '${data.todayCount}',
                      subtitle: 'Spiele',
                      icon: Icons.today_rounded,
                      color: KickMindTheme.primary,
                      onTap: () => _openScreen(const KickMindMatchesScreen()),
                    ),
                    _DashboardMetricCard(
                      label: 'Morgen',
                      value: '${data.tomorrowCount}',
                      subtitle: 'Spiele',
                      icon: Icons.event_rounded,
                      color: KickMindTheme.success,
                      onTap: () => _openScreen(const KickMindMatchesScreen()),
                    ),
                    _DashboardMetricCard(
                      label: '3 Tage',
                      value: '${data.next3DaysCount}',
                      subtitle: 'Analyse',
                      icon: Icons.view_week_rounded,
                      color: Colors.deepPurple,
                      onTap: () => _openScreen(const AnalysisScreen()),
                    ),
                    _DashboardMetricCard(
                      label: 'Meine Tipps',
                      value: '${data.savedCount}',
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
                  subtitle: 'Nur die besten 1–3 Signale; große Wochenlisten bleiben im Spiele-Bereich.',
                ),
                const SizedBox(height: 10),
                if (bestMatches.isEmpty)
                  _EmptyDashboardCard(onRefresh: _refresh)
                else
                  ...bestMatches.take(3).map(
                        (match) => _BestMatchCard(
                      match: match,
                      score: _scoreService.score(match),
                      decisionLabel: _scoreService.decision(match).shortLabel,
                      decisionType: _scoreService.decision(match).type,
                      rank: bestMatches.indexOf(match) + 1,
                      sourceLabel: _sourceLabel(match),
                      sourceColor: _sourceColor(match),
                      onTap: () => _openMatch(match),
                    ),
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
  final int todayCount;
  final int tomorrowCount;
  final int next3DaysCount;
  final int next7DaysCount;
  final int savedCount;

  const _HomeDashboardData({
    required this.today,
    required this.tomorrow,
    required this.next3Days,
    required this.next7Days,
    required this.saved,
    required this.todayCount,
    required this.tomorrowCount,
    required this.next3DaysCount,
    required this.next7DaysCount,
    required this.savedCount,
  });

  const _HomeDashboardData.empty()
      : today = const <FootballMatch>[],
        tomorrow = const <FootballMatch>[],
        next3Days = const <FootballMatch>[],
        next7Days = const <FootballMatch>[],
        saved = const <FootballMatch>[],
        todayCount = 0,
        tomorrowCount = 0,
        next3DaysCount = 0,
        next7DaysCount = 0,
        savedCount = 0;

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
  final FootballMatch? bestMatch;
  final TopTipScore? bestScore;
  final String? bestDecisionLabel;
  final VoidCallback onOpenTopTips;
  final VoidCallback onOpenMatches;

  const _DashboardHero({
    required this.data,
    required this.bestMatch,
    required this.bestScore,
    required this.bestDecisionLabel,
    required this.onOpenTopTips,
    required this.onOpenMatches,
  });

  @override
  Widget build(BuildContext context) {
    final totalVisible = data.next7DaysCount > 0
        ? data.next7DaysCount
        : data.todayCount + data.tomorrowCount;

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
                      '$totalVisible Spiele im Wochenblick · ${data.savedCount} gespeichert',
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
              _HeroPill(text: '${data.todayCount} Heute'),
              _HeroPill(text: '${data.tomorrowCount} Morgen'),
              _HeroPill(text: '${data.next3DaysCount} 3 Tage'),
              _HeroPill(text: '${data.next7DaysCount} Woche'),
              if (bestScore != null) _HeroPill(text: 'Best ${bestScore!.finalScore.toStringAsFixed(0)}'),
              if (bestDecisionLabel != null) _HeroPill(text: bestDecisionLabel!),
            ],
          ),
          if (bestMatch != null) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: Text(
                'Top Signal: ${bestMatch!.teamsLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
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
  final String decisionLabel;
  final TopTipDecisionType decisionType;
  final int rank;
  final String sourceLabel;
  final Color sourceColor;
  final VoidCallback onTap;

  const _BestMatchCard({
    required this.match,
    required this.score,
    required this.decisionLabel,
    required this.decisionType,
    required this.rank,
    required this.sourceLabel,
    required this.sourceColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);
    final hasQuote = match.id.startsWith('odds_') && match.odds > 1.05;
    final quoteText = hasQuote ? 'Quote ${match.odds.toStringAsFixed(2)}' : 'Keine Quote';
    final quoteColor = hasQuote ? Colors.indigo : Colors.blueGrey;

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
                  text: '#$rank $decisionLabel',
                  color: _decisionColor(decisionType),
                ),
                const SizedBox(width: 6),
                _SmallBadge(
                  text: sourceLabel,
                  color: sourceColor,
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
                _SmallBadge(text: 'Conf ${score.confidence.toStringAsFixed(0)}%', color: KickMindTheme.primary),
                _SmallBadge(text: quoteText, color: quoteColor),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              _dashboardReason(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: KickMindTheme.textMuted,
                fontSize: 12.4,
                height: 1.26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
  String _dashboardReason() {
    switch (decisionType) {
      case TopTipDecisionType.premium:
        return 'Premium-Signal: Score, Risiko und Datenquelle passen aktuell am besten zusammen.';
      case TopTipDecisionType.value:
        return 'Value-Signal: Bewertung und Quote/Marktlogik wirken überdurchschnittlich interessant.';
      case TopTipDecisionType.watch:
        return 'Beobachten: solide Analyse, aber noch kein klares Premium-Signal.';
      case TopTipDecisionType.noBet:
        return 'No Bet: aktuell nicht als Tipp übernehmen, nur zur Analyse öffnen.';
    }
  }

  Color _decisionColor(TopTipDecisionType type) {
    switch (type) {
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
    final hasQuote = match.id.startsWith('odds_') && match.odds > 1.05;
    final quoteText = hasQuote ? 'Quote ${match.odds.toStringAsFixed(2)}' : 'Keine Quote';

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
                    '${match.tipLabel} · AI ${match.aiScore}% · $quoteText',
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
