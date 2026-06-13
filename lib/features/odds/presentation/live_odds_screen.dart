import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/scoring/odds_score_service.dart';
import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/odds/data/live_odds_service.dart';
import 'package:kickmind_ai/features/odds/domain/live_odds.dart';

class LiveOddsScreen extends StatefulWidget {
  const LiveOddsScreen({super.key});

  @override
  State<LiveOddsScreen> createState() => _LiveOddsScreenState();
}

class _LiveOddsScreenState extends State<LiveOddsScreen> {
  final LiveOddsService _oddsService = LiveOddsService();
  final MatchRepositoryImpl _matchRepository = MatchRepositoryImpl();

  late Future<List<LiveOdds>> _future;
  late Future<_FixtureSourceSummary> _fixtureSourceFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _fixtureSourceFuture = _loadFixtureSourceSummary();
  }

  bool _lastLoadFailed = false;
  LiveOddsFetchDiagnostics? _lastDiagnostics;

  Future<List<LiveOdds>> _load({bool forceRefresh = false}) async {
    try {
      final odds = await _oddsService.fetchLiveOdds(forceRefresh: forceRefresh);
      _lastDiagnostics = _oddsService.lastDiagnostics;
      _lastLoadFailed = false;
      return odds;
    } catch (_) {
      _lastDiagnostics = _oddsService.lastDiagnostics;
      _lastLoadFailed = true;
      return <LiveOdds>[];
    }
  }

  Future<_FixtureSourceSummary> _loadFixtureSourceSummary() async {
    try {
      // Performance: Live-Odds darf beim Öffnen nicht zusätzlich Morgen/3 Tage/Woche
      // aus der Match-Quelle laden. Diese Seite prüft Quoten; der Spielplan bleibt
      // in Spiele/Analyse. Für die Leerseite reicht Heute als echte Vergleichsquelle.
      final today = await _matchRepository.getMatches(range: MatchDateRange.today);

      return _FixtureSourceSummary(
        todayMatches: today,
        tomorrowMatches: const <FootballMatch>[],
        next3DaysMatches: const <FootballMatch>[],
        next7DaysMatches: const <FootballMatch>[],
      );
    } catch (_) {
      return const _FixtureSourceSummary.empty();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(forceRefresh: true);
      _fixtureSourceFuture = _loadFixtureSourceSummary();
    });
  }

  List<LiveOdds> _dedupeByMatch(List<LiveOdds> source) {
    final unique = <String, LiveOdds>{};

    for (final item in source) {
      final key = item.matchId.trim().isEmpty
          ? '${item.homeTeam}_${item.awayTeam}_${item.updatedAt.toIso8601String()}'
          : item.matchId.trim();

      final current = unique[key];
      if (current == null || _marketCount(item) > _marketCount(current)) {
        unique[key] = item;
      }
    }

    final values = unique.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return values;
  }

  int _marketCount(LiveOdds item) {
    var count = 3; // 1 / X / 2
    if (item.over25 != null) count++;
    if (item.under25 != null) count++;
    if (item.bttsYes != null) count++;
    return count;
  }

  List<LiveOdds> _preferCompleteTeamNames(List<LiveOdds> source) {
    final complete = source.where((item) => !_hasFallbackTeamNames(item)).toList();
    if (complete.isEmpty) {
      return source;
    }
    return complete;
  }

  bool _hasFallbackTeamNames(LiveOdds value) {
    final home = value.homeTeam.trim().toLowerCase();
    final away = value.awayTeam.trim().toLowerCase();

    return home.isEmpty ||
        away.isEmpty ||
        home.startsWith('heimteam') ||
        away.startsWith('auswärtsteam') ||
        away.startsWith('auswaertsteam') ||
        home == away;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Live Quoten'),
        backgroundColor: const Color(0xFF071D2F),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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

            final allOdds = _dedupeByMatch(snapshot.data ?? <LiveOdds>[]);
            final odds = _preferCompleteTeamNames(allOdds);
            final hiddenFallbackCount = allOdds.length - odds.length;
            final diagnostics = _lastDiagnostics;
            final foundOddsDate = diagnostics?.foundOddsDate;

            if (odds.isEmpty) {
              return _LiveOddsEmptyState(
                onRefresh: _refresh,
                loadFailed: snapshot.hasError || _lastLoadFailed,
                diagnostics: _lastDiagnostics,
                fixtureSourceFuture: _fixtureSourceFuture,
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 118),
              itemCount: odds.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _LiveOddsHeader(
                    matchCount: odds.length,
                    bookmakerCount: odds.map((item) => item.bookmaker).toSet().length,
                    hiddenFallbackCount: hiddenFallbackCount,
                    foundOddsDate: foundOddsDate,
                    diagnostics: diagnostics,
                  );
                }

                return _LiveOddsCard(odds: odds[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _LiveOddsHeader extends StatelessWidget {
  final int matchCount;
  final int bookmakerCount;
  final int hiddenFallbackCount;
  final String? foundOddsDate;
  final LiveOddsFetchDiagnostics? diagnostics;

  const _LiveOddsHeader({
    required this.matchCount,
    required this.bookmakerCount,
    required this.hiddenFallbackCount,
    required this.foundOddsDate,
    required this.diagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final infoText = hiddenFallbackCount > 0
        ? '$hiddenFallbackCount unvollständige Teamdatensätze ausgeblendet.'
        : 'Ein Spiel wird nur einmal angezeigt.';
    final rangeText = diagnostics?.checkedDateRange ?? '-';
    final checkedDaysText = diagnostics == null
        ? '-'
        : '${diagnostics!.checkedDatesCount}/${diagnostics!.requestedDays}';
    final foundText = foundOddsDate ?? 'kein Datum';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B4EA2), Color(0xFF1685F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B4EA2).withOpacity(0.22),
            blurRadius: 24,
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.casino_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Quoten Radar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      foundOddsDate == null
                          ? '$matchCount Spiele · $bookmakerCount Bookmaker'
                          : '$matchCount Spiele · $bookmakerCount Bookmaker · $foundOddsDate',
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderInfoPill(
                icon: Icons.calendar_month_rounded,
                label: 'Geprüft',
                value: rangeText,
              ),
              _HeaderInfoPill(
                icon: Icons.search_rounded,
                label: 'Tage',
                value: checkedDaysText,
              ),
              _HeaderInfoPill(
                icon: Icons.check_circle_rounded,
                label: 'Gefunden',
                value: foundText,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$infoText Die wichtigsten Märkte stehen kompakt in derselben Karte.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}


class _HeaderInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderInfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveOddsEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final bool loadFailed;
  final LiveOddsFetchDiagnostics? diagnostics;
  final Future<_FixtureSourceSummary> fixtureSourceFuture;

  const _LiveOddsEmptyState({
    required this.onRefresh,
    required this.loadFailed,
    required this.diagnostics,
    required this.fixtureSourceFuture,
  });

  @override
  Widget build(BuildContext context) {
    final title = loadFailed
        ? 'Quoten konnten nicht geladen werden'
        : 'Keine echten Live-Odds verfügbar';

    final message = loadFailed
        ? 'Die Quoten-API konnte nicht gelesen werden. Bitte später erneut prüfen.'
        : 'API-Football liefert aktuell keine Odds-Rohdaten. Analyse-Spiele bleiben sichtbar, aber ohne Fake-Quoten.';

    final icon = loadFailed ? Icons.cloud_off_rounded : Icons.radar_rounded;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 118),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE3ECF7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      size: 30,
                      color: const Color(0xFF176CC7),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            height: 1.32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LiveOddsEmptySummary(future: fixtureSourceFuture),
              const SizedBox(height: 12),
              _FixtureSourceComparisonCard(future: fixtureSourceFuture),
              const SizedBox(height: 12),
              _AnalysisFixtureFallbackList(future: fixtureSourceFuture),
              if (diagnostics != null) ...[
                const SizedBox(height: 12),
                _LiveOddsDiagnosticsBox(diagnostics: diagnostics!),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Erneut prüfen'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _LiveOddsEmptySummary extends StatelessWidget {
  final Future<_FixtureSourceSummary> future;

  const _LiveOddsEmptySummary({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FixtureSourceSummary>(
      future: future,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? const _FixtureSourceSummary.empty();
        final fallbackCount = summary.bestFallbackMatches.length;
        final label = summary.bestFallbackLabel;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B4EA2), Color(0xFF1685F8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B4EA2).withOpacity(0.16),
                blurRadius: 18,
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.sports_soccer_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Analyse-Spiele verfügbar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          snapshot.connectionState == ConnectionState.waiting
                              ? 'Spielequelle wird geprüft ...'
                              : fallbackCount > 0
                              ? '$label · $fallbackCount Spiele gefunden'
                              : 'Keine Analyse-Spiele gefunden',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _WhiteStatusPill(icon: Icons.verified_rounded, text: 'echte Daten'),
                  _WhiteStatusPill(icon: Icons.money_off_rounded, text: 'keine Live-Odds'),
                  _WhiteStatusPill(icon: Icons.block_rounded, text: 'keine Fake-Quoten'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WhiteStatusPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WhiteStatusPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FixtureSourceSummary {
  final List<FootballMatch> todayMatches;
  final List<FootballMatch> tomorrowMatches;
  final List<FootballMatch> next3DaysMatches;
  final List<FootballMatch> next7DaysMatches;

  const _FixtureSourceSummary({
    required this.todayMatches,
    required this.tomorrowMatches,
    required this.next3DaysMatches,
    required this.next7DaysMatches,
  });

  const _FixtureSourceSummary.empty()
      : todayMatches = const <FootballMatch>[],
        tomorrowMatches = const <FootballMatch>[],
        next3DaysMatches = const <FootballMatch>[],
        next7DaysMatches = const <FootballMatch>[];

  int get today => todayMatches.length;
  int get tomorrow => tomorrowMatches.length;
  int get next3Days => next3DaysMatches.length;
  int get next7Days => next7DaysMatches.length;

  bool get hasMatches => today > 0 || tomorrow > 0 || next3Days > 0 || next7Days > 0;

  List<FootballMatch> get bestFallbackMatches {
    if (next7DaysMatches.isNotEmpty) return next7DaysMatches;
    if (next3DaysMatches.isNotEmpty) return next3DaysMatches;
    if (tomorrowMatches.isNotEmpty) return tomorrowMatches;
    return todayMatches;
  }

  String get bestFallbackLabel {
    if (next7DaysMatches.isNotEmpty) return 'Woche';
    if (next3DaysMatches.isNotEmpty) return '3 Tage';
    if (tomorrowMatches.isNotEmpty) return 'Morgen';
    if (todayMatches.isNotEmpty) return 'Heute';
    return '-';
  }
}

class _FixtureSourceComparisonCard extends StatelessWidget {
  final Future<_FixtureSourceSummary> future;

  const _FixtureSourceComparisonCard({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FixtureSourceSummary>(
      future: future,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? const _FixtureSourceSummary.empty();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    size: 18,
                    color: Color(0xFF176CC7),
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Datenquellen-Vergleich',
                    style: TextStyle(
                      color: Color(0xFF0B4EA2),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Text(
                  'Prüfe Spielequelle ...',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w800,
                  ),
                )
              else ...[
                _DiagnosticLine(label: 'Heute', value: '${summary.today} Spiele'),
                _DiagnosticLine(label: 'Morgen', value: '${summary.tomorrow} Spiele'),
                _DiagnosticLine(label: '3 Tage', value: '${summary.next3Days} Spiele'),
                _DiagnosticLine(label: 'Woche', value: '${summary.next7Days} Spiele'),
                const SizedBox(height: 8),
                Text(
                  summary.hasMatches
                      ? 'Diese Spiele kommen aus der Match-/Analyse-Quelle. Live Quoten nutzt separat den API-Football-Odds-Endpunkt. Deshalb können Spiele sichtbar sein, obwohl Live-Odds leer sind.'
                      : 'Auch die Match-/Analyse-Quelle liefert aktuell keine sichtbaren Spiele.',
                  style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AnalysisFixtureFallbackList extends StatelessWidget {
  final Future<_FixtureSourceSummary> future;

  const _AnalysisFixtureFallbackList({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FixtureSourceSummary>(
      future: future,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? const _FixtureSourceSummary.empty();
        final matches = summary.bestFallbackMatches.take(8).toList();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3ECF7)),
            ),
            child: const Text(
              'Lade Analyse-Spiele ...',
              style: TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

        if (matches.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3ECF7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.sports_soccer_rounded,
                      size: 18,
                      color: Color(0xFF176CC7),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Analyse-Spiele ohne Live-Odds',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${summary.bestFallbackLabel} · ${summary.bestFallbackMatches.length} Spiele gefunden',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Diese Liste nutzt die vorhandene Match-/Analyse-Quelle. Es werden keine künstlichen Live-Quoten erzeugt.',
                style: TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              ...matches.map((match) => _AnalysisFixtureCard(match)),
              if (summary.bestFallbackMatches.length > matches.length) ...[
                const SizedBox(height: 8),
                Text(
                  '+${summary.bestFallbackMatches.length - matches.length} weitere Spiele in der Analyse-Quelle.',
                  style: const TextStyle(
                    color: Color(0xFF176CC7),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AnalysisFixtureCard extends StatelessWidget {
  final FootballMatch match;

  const _AnalysisFixtureCard(this.match);

  @override
  Widget build(BuildContext context) {
    final kickoffText = _formatKickoff(match.kickoff);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            match.league,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${match.homeTeam} vs ${match.awayTeam}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SmallInfoChip(
                icon: Icons.schedule_rounded,
                text: kickoffText,
              ),
              _SmallInfoChip(
                icon: Icons.auto_graph_rounded,
                text: 'KI ${match.aiScore}',
              ),
              _SmallInfoChip(
                icon: Icons.shield_rounded,
                text: 'Risiko ${match.riskLevel}',
              ),
              const _SmallInfoChip(
                icon: Icons.money_off_rounded,
                text: 'keine Live-Odds',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatKickoff(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute';
  }
}

class _SmallInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallInfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF176CC7)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveOddsDiagnosticsBox extends StatelessWidget {
  final LiveOddsFetchDiagnostics diagnostics;

  const _LiveOddsDiagnosticsBox({required this.diagnostics});

  @override
  Widget build(BuildContext context) {
    final statusText = diagnostics.httpStatusCode?.toString() ?? '-';
    final cacheText = diagnostics.usedCache ? 'Ja' : 'Nein';
    final refreshText = diagnostics.forceRefresh ? 'Ja' : 'Nein';
    final keyText = diagnostics.hasApiKey ? 'Ja' : 'Nein';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(
            Icons.bug_report_rounded,
            size: 18,
            color: Color(0xFFB45309),
          ),
          title: const Text(
            'API-Diagnose',
            style: TextStyle(
              color: Color(0xFF92400E),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            'Status $statusText · ${diagnostics.checkedDatesCount} Tage · Rohdaten ${diagnostics.rawResponseCount}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF78350F),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          children: [
            _DiagnosticLine(label: 'Zeit', value: diagnostics.checkedAtText),
            _DiagnosticLine(label: 'Zeitraum', value: diagnostics.checkedDateRange),
            _DiagnosticLine(label: 'Geprüfte Tage', value: diagnostics.checkedDatesCount.toString()),
            _DiagnosticLine(label: 'Gefunden', value: diagnostics.foundOddsDate ?? '-'),
            _DiagnosticLine(label: 'Status', value: statusText),
            _DiagnosticLine(label: 'Rohdaten', value: diagnostics.rawResponseCount.toString()),
            _DiagnosticLine(label: 'Verwendbar', value: diagnostics.parsedOddsCount.toString()),
            _DiagnosticLine(label: 'Sichtbar', value: diagnostics.visibleOddsCount.toString()),
            _DiagnosticLine(label: 'Cache', value: cacheText),
            _DiagnosticLine(label: 'Refresh', value: refreshText),
            _DiagnosticLine(label: 'API-Key', value: keyText),
            const SizedBox(height: 8),
            Text(
              diagnostics.message,
              style: const TextStyle(
                color: Color(0xFF78350F),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticLine extends StatelessWidget {
  final String label;
  final String value;

  const _DiagnosticLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveOddsCard extends StatelessWidget {
  final LiveOdds odds;

  const _LiveOddsCard({required this.odds});

  @override
  Widget build(BuildContext context) {
    final hasFallbackNames = _hasFallbackTeamNames(odds);
    final subtitle = hasFallbackNames
        ? 'Quoten vorhanden · Fixture ${odds.matchId}'
        : 'Aktualisiert ${_formatDateTime(odds.updatedAt)}';
    final relevance = _bestMarketRelevance(odds);
    final explanation = _buildOddsExplanation(relevance, hasFallbackNames);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasFallbackNames ? const Color(0xFFFFFBEB) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasFallbackNames ? const Color(0xFFFDE68A) : const Color(0xFFE3ECF7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: hasFallbackNames
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  hasFallbackNames
                      ? Icons.hourglass_empty_rounded
                      : Icons.sports_soccer_rounded,
                  color: hasFallbackNames
                      ? const Color(0xFFB45309)
                      : const Color(0xFF176CC7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TeamTitle(
                      homeTeam: odds.homeTeam,
                      awayTeam: odds.awayTeam,
                      isFallback: hasFallbackNames,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Badge(text: odds.bookmaker, color: Colors.indigo),
            ],
          ),
          const SizedBox(height: 14),
          _AiRelevancePanel(relevance: relevance),
          const SizedBox(height: 10),
          _LiveOddsReasonPanel(
            relevance: relevance,
            explanation: explanation,
            hasFallbackNames: hasFallbackNames,
          ),
          const SizedBox(height: 14),
          const Text(
            'Märkte',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OddsBadge(label: '1', description: 'Heim', value: odds.homeWin),
              _OddsBadge(label: 'X', description: 'Remis', value: odds.draw),
              _OddsBadge(label: '2', description: 'Auswärts', value: odds.awayWin),
              if (odds.over25 != null)
                _OddsBadge(label: 'Ü2.5', description: 'Tore', value: odds.over25!),
              if (odds.under25 != null)
                _OddsBadge(label: 'U2.5', description: 'Tore', value: odds.under25!),
              if (odds.bttsYes != null)
                _OddsBadge(label: 'BTTS', description: 'Ja', value: odds.bttsYes!),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasFallbackTeamNames(LiveOdds value) {
    final home = value.homeTeam.trim().toLowerCase();
    final away = value.awayTeam.trim().toLowerCase();

    return home.isEmpty ||
        away.isEmpty ||
        home.startsWith('heimteam') ||
        away.startsWith('auswärtsteam') ||
        away.startsWith('auswaertsteam') ||
        home == away;
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute';
  }

  String _buildOddsExplanation(
      _OddsRelevance relevance,
      bool hasFallbackNames,
      ) {
    final market = '${relevance.label} ${relevance.name}';
    final oddsText = relevance.oddsValue.toStringAsFixed(2);
    final sourceText = hasFallbackNames
        ? 'Die Quote ist echt, aber die Teamnamen fehlen noch im Odds-Datensatz.'
        : 'Die Quote ist mit echten Teamnamen verknüpft.';

    switch (relevance.decision.type) {
      case OddsMarketDecisionType.premium:
        return '$sourceText Bester Markt: $market bei Quote $oddsText. Score, Value und Risiko sprechen aktuell für ein starkes Signal.';
      case OddsMarketDecisionType.value:
        return '$sourceText Bester Markt: $market bei Quote $oddsText. Die Quote wirkt interessant, bleibt aber unter Premium-Niveau.';
      case OddsMarketDecisionType.stable:
        return '$sourceText Bester Markt: $market bei Quote $oddsText. Solide Quote, eher Beobachtung als aggressiver Tipp.';
      case OddsMarketDecisionType.noBet:
        return '$sourceText Bester Markt: $market bei Quote $oddsText. Aktuell kein klares Value-Signal, daher vorsichtig behandeln.';
    }
  }
}


_OddsRelevance _bestMarketRelevance(LiveOdds odds) {
  final margin = _mainMarketMargin(odds);
  final candidates = <_OddsRelevance>[
    _evaluateMarket(
      label: '1',
      name: 'Heimsieg',
      value: odds.homeWin,
      marketType: OddsMarketType.home,
      margin: margin,
    ),
    _evaluateMarket(
      label: 'X',
      name: 'Remis',
      value: odds.draw,
      marketType: OddsMarketType.draw,
      margin: margin,
    ),
    _evaluateMarket(
      label: '2',
      name: 'Auswärtssieg',
      value: odds.awayWin,
      marketType: OddsMarketType.away,
      margin: margin,
    ),
    if (odds.over25 != null)
      _evaluateMarket(
        label: 'Ü2.5',
        name: 'Über 2.5 Tore',
        value: odds.over25!,
        marketType: OddsMarketType.over25,
        margin: margin,
      ),
    if (odds.under25 != null)
      _evaluateMarket(
        label: 'U2.5',
        name: 'Unter 2.5 Tore',
        value: odds.under25!,
        marketType: OddsMarketType.under25,
        margin: margin,
      ),
    if (odds.bttsYes != null)
      _evaluateMarket(
        label: 'BTTS',
        name: 'Beide treffen',
        value: odds.bttsYes!,
        marketType: OddsMarketType.btts,
        margin: margin,
      ),
  ];

  candidates.sort((a, b) => b.score.finalScore.compareTo(a.score.finalScore));
  return candidates.first;
}

_OddsRelevance _evaluateMarket({
  required String label,
  required String name,
  required double value,
  required OddsMarketType marketType,
  required double margin,
}) {
  final score = OddsScoreService.instance.evaluate(
    oddsValue: value,
    margin: margin,
    marketType: marketType,
  );
  final decision = OddsScoreService.instance.decisionFor(
    finalScore: score.finalScore,
    valueEdge: score.valueEdge,
    confidence: score.confidence,
    riskLevel: score.riskLevel,
    oddsValue: value,
  );

  return _OddsRelevance(
    label: label,
    name: name,
    oddsValue: value,
    score: score,
    decision: decision,
  );
}

double _mainMarketMargin(LiveOdds odds) {
  final home = odds.homeWin > 1 ? 1 / odds.homeWin : 0.0;
  final draw = odds.draw > 1 ? 1 / odds.draw : 0.0;
  final away = odds.awayWin > 1 ? 1 / odds.awayWin : 0.0;
  return (home + draw + away - 1).clamp(0.0, 0.22).toDouble();
}


class _TeamTitle extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final bool isFallback;

  const _TeamTitle({
    required this.homeTeam,
    required this.awayTeam,
    required this.isFallback,
  });

  @override
  Widget build(BuildContext context) {
    if (isFallback) {
      return const Text(
        'Teamdaten werden geladen',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Color(0xFF111827),
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homeTeam,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 17,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'vs',
                style: TextStyle(
                  color: Color(0xFF176CC7),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                awayTeam,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OddsRelevance {
  final String label;
  final String name;
  final double oddsValue;
  final OddsMarketScore score;
  final OddsMarketDecision decision;

  const _OddsRelevance({
    required this.label,
    required this.name,
    required this.oddsValue,
    required this.score,
    required this.decision,
  });
}


class _LiveOddsReasonPanel extends StatelessWidget {
  final _OddsRelevance relevance;
  final String explanation;
  final bool hasFallbackNames;

  const _LiveOddsReasonPanel({
    required this.relevance,
    required this.explanation,
    required this.hasFallbackNames,
  });

  @override
  Widget build(BuildContext context) {
    final color = hasFallbackNames ? const Color(0xFFB45309) : const Color(0xFF176CC7);
    final sourceLabel = hasFallbackNames ? 'Teamdaten fehlen' : 'echte Teamnamen';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasFallbackNames ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasFallbackNames ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFallbackNames ? Icons.info_outline_rounded : Icons.fact_check_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Quoten-Einschätzung',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MiniScorePill(text: sourceLabel, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _SmallInfoChip(
                icon: Icons.track_changes_rounded,
                text: '${relevance.label} ${relevance.name}',
              ),
              _SmallInfoChip(
                icon: Icons.payments_rounded,
                text: relevance.oddsValue.toStringAsFixed(2),
              ),
              _SmallInfoChip(
                icon: Icons.shield_rounded,
                text: relevance.score.riskLevel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiRelevancePanel extends StatelessWidget {
  final _OddsRelevance relevance;

  const _AiRelevancePanel({required this.relevance});

  @override
  Widget build(BuildContext context) {
    final color = _decisionColor(relevance.decision.type);
    final scoreText = relevance.score.finalScore.toStringAsFixed(0);
    final valueText = relevance.score.valueEdge >= 0
        ? '+${relevance.score.valueEdge.toStringAsFixed(1)}'
        : relevance.score.valueEdge.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'KI-Relevanz · ${relevance.decision.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MiniScorePill(text: 'Score $scoreText', color: color),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                label: 'Markt',
                value: '${relevance.label} · ${relevance.name}',
              ),
              _InfoPill(
                label: 'Quote',
                value: relevance.oddsValue.toStringAsFixed(2),
              ),
              _InfoPill(
                label: 'Risiko',
                value: relevance.score.riskLevel,
              ),
              _InfoPill(
                label: 'Value',
                value: valueText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _decisionColor(OddsMarketDecisionType type) {
    switch (type) {
      case OddsMarketDecisionType.premium:
        return const Color(0xFF047857);
      case OddsMarketDecisionType.value:
        return const Color(0xFF0B4EA2);
      case OddsMarketDecisionType.stable:
        return const Color(0xFF6D5BD0);
      case OddsMarketDecisionType.noBet:
        return const Color(0xFFB45309);
    }
  }
}

class _MiniScorePill extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniScorePill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}


class _OddsBadge extends StatelessWidget {
  final String label;
  final String description;
  final double value;

  const _OddsBadge({
    required this.label,
    required this.description,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF176CC7),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
