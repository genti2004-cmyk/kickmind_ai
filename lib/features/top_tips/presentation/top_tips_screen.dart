import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/scoring/odds_score_service.dart';
import 'package:kickmind_ai/core/scoring/top_tip_score_service.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/matches/data/repositories/match_repository_impl.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/domain/match_date_range.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';
import 'package:kickmind_ai/features/odds/data/live_odds_service.dart';
import 'package:kickmind_ai/features/odds/domain/live_odds.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';
import 'package:kickmind_ai/features/saved_tips/data/saved_tips_service.dart';


bool _kmHasRealBookmakerOdds(FootballMatch match) {
  return match.odds > 1.05 &&
      (match.hasPlayableOdds || match.hasRealOdds || match.id.startsWith('odds_'));
}

String _kmQuoteLabel(FootballMatch match) {
  return _kmHasRealBookmakerOdds(match)
      ? 'Quote ${match.odds.toStringAsFixed(2)}'
      : 'Keine echte Quote';
}

String _kmSourceLabel(FootballMatch match) {
  if (_kmHasRealBookmakerOdds(match)) {
    final bookmaker = match.realOddsBookmaker?.trim();
    if (bookmaker != null && bookmaker.isNotEmpty) return 'Echte Quote · $bookmaker';
    return 'Echte Quote';
  }
  return 'Beobachtung';
}

Color _kmSourceColor(FootballMatch match) {
  return _kmHasRealBookmakerOdds(match) ? KickMindTheme.success : Colors.blueGrey;
}

class TopTipsScreen extends StatefulWidget {
  const TopTipsScreen({super.key});

  @override
  State<TopTipsScreen> createState() => _TopTipsScreenState();
}

class _TopTipsScreenState extends State<TopTipsScreen> {
  final MatchRepositoryImpl _repository = MatchRepositoryImpl();
  final TopTipScoreService _scoreService = TopTipScoreService.instance;
  final SavedTipsService _savedTipsService = SavedTipsService();
  final LiveOddsService _liveOddsService = LiveOddsService();
  final PredictionEngine _predictionEngine = const PredictionEngine();

  MatchDateRange _range = MatchDateRange.today;
  late Future<List<FootballMatch>> _future;
  Set<String> _savedMatchIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadSavedIds();
  }

  Future<List<FootballMatch>> _load({bool forceRefresh = false}) async {
    final oddsMatches = await _loadRealOddsTopTips(forceRefresh: forceRefresh);

    // Fallback auf exakt dieselbe echte Spielquelle wie Analyse/Spiele.
    // Wichtig: Top Tips darf nicht leer bleiben, nur weil API-Football keine
    // Teamnamen oder keine verwertbare Quote liefert. Es werden hier keine
    // Fake-Spiele erzeugt; es werden nur echte Repository-Spiele bewertet.
    final repositoryMatches = await _loadRepositoryFallbackMatches();

    if (oddsMatches.isEmpty) {
      return repositoryMatches;
    }

    // Wenn API-Football Odds ohne echte Teamnamen liefert, entstehen sonst
    // Karten wie „Heimteam 1492911 vs Auswärtsteam 1492911“. Diese werden
    // nicht angezeigt. Stattdessen füllen wir mit echten Repository-Spielen
    // auf, damit Top Tips lesbar bleibt und keine ID-Namen zeigt.
    final merged = <FootballMatch>[];
    final seen = <String>{};

    void addMatch(FootballMatch match) {
      final key = _matchDedupeKey(match);
      if (seen.add(key)) merged.add(match);
    }

    for (final match in oddsMatches) {
      addMatch(match);
    }

    if (merged.length < 5) {
      for (final match in repositoryMatches) {
        addMatch(match);
        if (merged.length >= 5) break;
      }
    }

    merged.sort(_compareByTopTipQuality);
    return merged;
  }

  Future<List<FootballMatch>> _loadRepositoryFallbackMatches() async {
    final matches = await _repository.getMatches(range: _range);
    final normalized = matches
        .where((match) =>
    _isRealTeamName(match.homeTeam) &&
        _isRealTeamName(match.awayTeam))
        .map(_ensurePlayableTopTip)
        .toList();

    normalized.sort(_compareByTopTipQuality);
    return normalized;
  }

  Future<List<FootballMatch>> _loadRealOddsTopTips({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final start = _range.startDate(now);
    final days = _range.durationDays.clamp(1, 7).toInt();

    final odds = await _liveOddsService.fetchLiveOddsForRange(
      start: start,
      days: days,
      forceRefresh: forceRefresh,
    );

    final matches = <FootballMatch>[];
    for (final item in odds) {
      final match = _matchFromLiveOdds(item, fallbackKickoff: start);
      if (match != null) matches.add(match);
    }

    matches.sort(_compareByTopTipQuality);
    return matches;
  }

  FootballMatch? _matchFromLiveOdds(
      LiveOdds odds, {
        required DateTime fallbackKickoff,
      }) {
    final market = _selectBestMarket(odds);
    if (market == null) return null;

    final fixtureId = odds.matchId.trim();
    final home = _safeTeamName(
      odds.homeTeam,
      fallback: fixtureId.isEmpty ? 'Heimteam' : 'Heimteam $fixtureId',
    );
    final away = _safeTeamName(
      odds.awayTeam,
      fallback: fixtureId.isEmpty ? 'Auswärtsteam' : 'Auswärtsteam $fixtureId',
    );

    if (!_isRealTeamName(home) || !_isRealTeamName(away)) {
      return null;
    }

    return _predictionEngine.buildMatch(
      id: 'odds_${fixtureId}_${market.tipType.name}',
      fixtureId: int.tryParse(fixtureId),
      league: odds.bookmaker,
      home: home,
      away: away,
      kickoff: DateTime(
        fallbackKickoff.year,
        fallbackKickoff.month,
        fallbackKickoff.day,
        12,
      ),
      tipType: market.tipType,
      odds: market.odds,
    );
  }

  FootballMatch _ensurePlayableTopTip(FootballMatch match) {
    if (match.odds > 1.05 && match.aiScore > 0) return match;

    return _predictionEngine.buildMatch(
      id: match.id,
      fixtureId: match.fixtureId,
      season: match.season,
      league: match.league,
      home: match.homeTeam,
      away: match.awayTeam,
      kickoff: match.kickoff,
      tipType: match.tipType,
      odds: match.odds > 1.05 ? match.odds : null,
      homeFormScore: match.homeFormScore,
      awayFormScore: match.awayFormScore,
      goalsScore: match.goalsScore,
    );
  }

  String _safeTeamName(String value, {required String fallback}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    return trimmed;
  }

  bool _isRealTeamName(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    if (RegExp(r'^(heimteam|auswärtsteam|auswaertsteam)\s*\d+$').hasMatch(lower)) {
      return false;
    }
    if (RegExp(r'^\d+$').hasMatch(text)) return false;
    return true;
  }

  String _matchDedupeKey(FootballMatch match) {
    final home = match.homeTeam.trim().toLowerCase();
    final away = match.awayTeam.trim().toLowerCase();
    final date = DateTime(match.kickoff.year, match.kickoff.month, match.kickoff.day);
    return '$home|$away|${date.toIso8601String()}';
  }

  _OddsMarket? _selectBestMarket(LiveOdds odds) {
    final markets = <_OddsMarket>[
      _OddsMarket(TipType.homeWin, odds.homeWin),
      _OddsMarket(TipType.awayWin, odds.awayWin),
      if (odds.over25 != null) _OddsMarket(TipType.over25, odds.over25!),
      if (odds.bttsYes != null) _OddsMarket(TipType.btts, odds.bttsYes!),
      if (odds.under25 != null) _OddsMarket(TipType.under25, odds.under25!),
      _OddsMarket(TipType.draw, odds.draw),
    ].where((market) => market.odds > 1.05).toList();

    if (markets.isEmpty) return null;

    int marketRank(_OddsMarket market) {
      if (market.odds >= 1.35 && market.odds <= 2.35) return 0;
      if (market.odds > 2.35 && market.odds <= 3.10) return 1;
      if (market.odds > 1.05 && market.odds < 1.35) return 2;
      return 3;
    }

    markets.sort((a, b) {
      final rankCompare = marketRank(a).compareTo(marketRank(b));
      if (rankCompare != 0) return rankCompare;
      return (a.odds - 1.85).abs().compareTo((b.odds - 1.85).abs());
    });

    return markets.first;
  }

  void _setRange(MatchDateRange range) {
    if (_range == range) return;

    setState(() {
      _range = range;
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    setState(() => _future = _load(forceRefresh: true));
    _loadSavedIds();
    await _future;
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
        backgroundColor: KickMindTheme.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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

          final ranked = matches..sort(_compareByTopTipQuality);

          final premiumCandidates = ranked.where(_isSmartTopTipCandidate).toList();
          final fallbackCandidates = ranked
              .where((match) => !premiumCandidates.contains(match))
              .where(_isDisplayRecommendedTip)
              .toList();

          final safeVisibleTopTips = <FootballMatch>[
            ...premiumCandidates.take(5),
          ];

          if (safeVisibleTopTips.length < 3) {
            for (final match in fallbackCandidates) {
              if (safeVisibleTopTips.contains(match)) continue;
              safeVisibleTopTips.add(match);
              if (safeVisibleTopTips.length >= 3) break;
            }
          }

          if (safeVisibleTopTips.isEmpty) {
            safeVisibleTopTips.addAll(ranked.take(3));
          }

          final valueBets = ranked
              .where((match) => !safeVisibleTopTips.contains(match))
              .where((match) => _isValueBet(match) && _hasUsableOdds(match))
              .take(4)
              .toList();
          final watchList = ranked
              .where((match) => !safeVisibleTopTips.contains(match))
              .where((match) => !valueBets.contains(match))
              .where(_isSmartWatchCandidate)
              .take(7)
              .toList();
          final noBetCount = ranked.where(_isNoBetCandidate).length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 150),
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
                  realOddsCount: matches.where(_hasRealBookmakerOdds).length,
                  recommendedCount: safeVisibleTopTips.length,
                  valueCount: valueBets.length,
                  noBetCount: noBetCount,
                  bestScore: _finalScore(ranked.first),
                  bestAiScore: ranked.first.aiScore,
                ),
                const SizedBox(height: 18),
                const _SectionTitle(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Beste Auswahl',
                  subtitle: 'Nur die stärksten 3–5 Signale. Schwächere Spiele wandern in Beobachten oder No Bet.',
                ),
                const SizedBox(height: 12),
                ...safeVisibleTopTips.take(8).map(
                      (match) => _TopTipCard(
                    match: match,
                    rank: safeVisibleTopTips.indexOf(match) + 1,
                    finalScore: _finalScore(match),
                    valueEdge: _valueEdge(match),
                    confidence: _confidence(match),
                    isSaved: _savedMatchIds.contains(match.id),
                    onSaveTap: () => _toggleSavedTip(match),
                    onTap: () => _openDetail(match),
                  ),
                ),
                if (valueBets.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    icon: Icons.trending_up_rounded,
                    title: 'Value Chancen',
                    subtitle: 'Quoten mit positivem Edge gegen die AI-Bewertung.',
                  ),
                  const SizedBox(height: 12),
                  ...valueBets.map(
                        (match) => _CompactTipCard(
                      match: match,
                      finalScore: _finalScore(match),
                      isSaved: _savedMatchIds.contains(match.id),
                      onSaveTap: () => _toggleSavedTip(match),
                      onTap: () => _openDetail(match),
                    ),
                  ),
                ],
                if (watchList.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    icon: Icons.visibility_rounded,
                    title: 'Beobachten',
                    subtitle: 'Solide Ansätze, aber noch kein Premium-Signal.',
                  ),
                  const SizedBox(height: 12),
                  ...watchList.map(
                        (match) => _CompactTipCard(
                      match: match,
                      finalScore: _finalScore(match),
                      isSaved: _savedMatchIds.contains(match.id),
                      onSaveTap: () => _toggleSavedTip(match),
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
    ).then((_) => _loadSavedIds());
  }


  bool _isValueBet(FootballMatch match) {
    return _scoreService.isValueBet(match);
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

  bool _isDisplayRecommendedTip(FootballMatch match) {
    final score = _scoreService.score(match);
    if (score.finalScore < 50) return false;
    if (_isHighRisk(match) && score.finalScore < 70) return false;
    return score.isRecommended || score.isValueBet || score.finalScore >= 60;
  }

  bool _isSmartTopTipCandidate(FootballMatch match) {
    final score = _scoreService.score(match);
    if (_isHighRisk(match) && score.finalScore < 76) return false;
    if (!_isRealTeamName(match.homeTeam) || !_isRealTeamName(match.awayTeam)) return false;

    final hasRealOdds = _hasRealBookmakerOdds(match);
    final hasUsableOdds = _hasUsableOdds(match);

    if (hasRealOdds && hasUsableOdds) {
      return score.finalScore >= 62 || score.isValueBet || score.isRecommended;
    }

    // Ohne echte Bookmaker-Quote nicht als Top-Tipp verkaufen.
    // Diese Spiele bleiben weiter in Beobachten sichtbar.
    return false;
  }

  bool _isSmartWatchCandidate(FootballMatch match) {
    final score = _scoreService.score(match);
    if (_isHighRisk(match) && score.finalScore < 72) return false;
    if (!_isRealTeamName(match.homeTeam) || !_isRealTeamName(match.awayTeam)) return false;
    return score.finalScore >= 52 || match.aiScore >= 55;
  }

  bool _isNoBetCandidate(FootballMatch match) {
    final score = _scoreService.score(match);
    if (_isHighRisk(match) && score.finalScore < 72) return true;
    if (score.finalScore < 52 && match.aiScore < 55) return true;
    return false;
  }

  bool _hasRealBookmakerOdds(FootballMatch match) => _kmHasRealBookmakerOdds(match);

  bool _hasUsableOdds(FootballMatch match) {
    return _hasRealBookmakerOdds(match) && match.odds >= 1.18 && match.odds <= 4.50;
  }

  bool _isHighRisk(FootballMatch match) {
    final risk = match.riskLevel.toLowerCase().trim();
    return risk == 'hoch' || risk == 'high';
  }

  int _compareByTopTipQuality(FootballMatch a, FootballMatch b) {
    final qualityCompare = _topTipQualityScore(b).compareTo(_topTipQualityScore(a));
    if (qualityCompare != 0) return qualityCompare;

    final finalScoreCompare = _finalScore(b).compareTo(_finalScore(a));
    if (finalScoreCompare != 0) return finalScoreCompare;

    final aiCompare = b.aiScore.compareTo(a.aiScore);
    if (aiCompare != 0) return aiCompare;

    return a.kickoff.compareTo(b.kickoff);
  }

  double _topTipQualityScore(FootballMatch match) {
    final score = _scoreService.score(match);
    final realOddsBoost = _hasRealBookmakerOdds(match) ? 8.0 : 0.0;
    final oddsRangeBoost = _hasUsableOdds(match) ? 4.0 : -6.0;
    final riskBoost = _isHighRisk(match)
        ? -12.0
        : match.riskLevel.toLowerCase().contains('niedrig') ||
        match.riskLevel.toLowerCase().contains('low')
        ? 5.0
        : 1.5;
    final valueBoost = score.valueEdge.clamp(-8.0, 12.0).toDouble() * 0.45;
    final kickoffBoost = _kickoffPriorityBoost(match.kickoff);

    return score.finalScore + realOddsBoost + oddsRangeBoost + riskBoost + valueBoost + kickoffBoost;
  }

  double _kickoffPriorityBoost(DateTime kickoff) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDay = DateTime(kickoff.year, kickoff.month, kickoff.day);
    final diff = matchDay.difference(today).inDays;
    if (diff == 0) return 2.0;
    if (diff == 1) return 1.2;
    if (diff >= 2 && diff <= 7) return 0.4;
    return 0.0;
  }

}


class _OddsMarket {
  final TipType tipType;
  final double odds;

  const _OddsMarket(this.tipType, this.odds);
}

class _TopTipsSummaryStrip extends StatelessWidget {
  final String rangeLabel;
  final int matchesCount;
  final int realOddsCount;
  final int recommendedCount;
  final int valueCount;
  final int noBetCount;
  final double bestScore;
  final int bestAiScore;

  const _TopTipsSummaryStrip({
    required this.rangeLabel,
    required this.matchesCount,
    required this.realOddsCount,
    required this.recommendedCount,
    required this.valueCount,
    required this.noBetCount,
    required this.bestScore,
    required this.bestAiScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KickMindTheme.primary.withOpacity(0.075),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KickMindTheme.primary.withOpacity(0.12)),
      ),
      child: Row(
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
                  '$rangeLabel · $matchesCount Spiele',
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
                  'Top $recommendedCount · Beobachten/Value $valueCount · No Bet $noBetCount · Quote $realOddsCount',
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

class _TopTipCard extends StatelessWidget {
  final FootballMatch match;
  final int rank;
  final double finalScore;
  final double valueEdge;
  final double confidence;
  final bool isSaved;
  final VoidCallback onSaveTap;
  final VoidCallback onTap;

  const _TopTipCard({
    required this.match,
    required this.rank,
    required this.finalScore,
    required this.valueEdge,
    required this.confidence,
    required this.isSaved,
    required this.onSaveTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);
    final riskColor = KickMindTheme.riskColor(match.riskLevel);
    final cardReason = _buildCardReason();
    final oddsRelevance = _TopTipOddsRelevance.fromMatch(match);
    final primaryBorder = rank == 1
        ? KickMindTheme.primary.withOpacity(0.34)
        : Colors.black.withOpacity(0.055);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: KickMindTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(rank == 1 ? 0.095 : 0.055),
              blurRadius: rank == 1 ? 24 : 16,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.league,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: KickMindTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              match.kickoffLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: KickMindTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _SourceBadge(text: _dataSourceLabel(), color: _dataSourceColor()),
                const SizedBox(width: 6),
                _SaveCircleButton(
                  isSaved: isSaved,
                  onTap: onSaveTap,
                ),
              ],
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: KickMindTheme.primary.withOpacity(0.055),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: KickMindTheme.primary.withOpacity(0.10)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: KickMindTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      match.tipLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KickMindTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Empfohlener Tipp',
                          style: TextStyle(
                            color: KickMindTheme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cardReason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KickMindTheme.textDark,
                            height: 1.18,
                            fontSize: 13.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Final',
                    value: finalScore.toStringAsFixed(1),
                    color: KickMindTheme.primaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'AI',
                    value: '${match.aiScore}%',
                    color: scoreColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Quote',
                    value: _quoteMetricValue(),
                    color: _hasRealBookmakerOdds() ? Colors.indigo : Colors.blueGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Risiko',
                    value: '${match.riskEmoji} ${match.riskLevel}',
                    color: riskColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Value',
                    value: valueEdge >= 0
                        ? '+${valueEdge.toStringAsFixed(1)}%'
                        : '${valueEdge.toStringAsFixed(1)}%',
                    color: valueEdge > 0 ? KickMindTheme.success : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ScoreBar(
              label: 'Confidence',
              value: confidence,
              color: scoreColor,
            ),
            const SizedBox(height: 11),
            _TopTipOddsPanel(relevance: oddsRelevance),
            const SizedBox(height: 10),
            _TopTipReasonPanel(
              match: match,
              finalScore: finalScore,
              valueEdge: valueEdge,
              confidence: confidence,
              hasRealBookmakerOdds: _hasRealBookmakerOdds(),
            ),
          ],
        ),
      ),
    );
  }

  String _buildCardReason() {
    final valueText = valueEdge >= 0
        ? '+${valueEdge.toStringAsFixed(1)}%'
        : '${valueEdge.toStringAsFixed(1)}%';
    final sourceText = _hasRealBookmakerOdds() ? 'echte Bookmaker-Quote' : 'Spielplan-Analyse';
    final riskOk = !_isHighRisk();

    if (finalScore >= 74 && valueEdge >= 8 && riskOk) {
      return 'Premium-Signal · $sourceText · Value $valueText · Risiko kontrolliert';
    }

    if (valueEdge >= 8 && riskOk) {
      return 'Value-Signal · $sourceText · Marktwert stärker als Risiko';
    }

    if (finalScore >= 65 && confidence >= 62 && riskOk) {
      return 'Stabiler Tipp · $sourceText · AI und Confidence passen zusammen';
    }

    if (finalScore >= 58 && riskOk) {
      return 'Solide Auswahl · $sourceText · Beobachten mit leichter Tendenz';
    }

    if (finalScore >= 50) {
      return 'Beobachten · $sourceText · noch kein klares Premium-Signal';
    }

    return 'No Bet · Datenlage aktuell zu schwach';
  }

  bool _hasRealBookmakerOdds() => _kmHasRealBookmakerOdds(match);

  String _quoteMetricValue() {
    return _hasRealBookmakerOdds() ? match.odds.toStringAsFixed(2) : 'Keine';
  }

  bool _isHighRisk() {
    final risk = match.riskLevel.toLowerCase().trim();
    return risk == 'hoch' || risk == 'high';
  }

  String _dataSourceLabel() => _kmSourceLabel(match);

  Color _dataSourceColor() => _kmSourceColor(match);
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _SourceBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SaveCircleButton extends StatelessWidget {
  final bool isSaved;
  final VoidCallback onTap;

  const _SaveCircleButton({required this.isSaved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSaved
          ? KickMindTheme.primary.withOpacity(0.12)
          : Colors.black.withOpacity(0.035),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: isSaved ? KickMindTheme.primary : KickMindTheme.textMuted,
            size: 22,
          ),
        ),
      ),
    );
  }
}


class _TopTipReasonPanel extends StatelessWidget {
  final FootballMatch match;
  final double finalScore;
  final double valueEdge;
  final double confidence;
  final bool hasRealBookmakerOdds;

  const _TopTipReasonPanel({
    required this.match,
    required this.finalScore,
    required this.valueEdge,
    required this.confidence,
    required this.hasRealBookmakerOdds,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final points = _reasonPoints();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_rounded, size: 17, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _statusTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...points.map(
                (point) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      height: 1.24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      point,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KickMindTheme.textMuted,
                        fontSize: 12.2,
                        height: 1.24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusTitle() {
    if (_isHighRisk() && finalScore < 70) {
      return 'Begründung · vorsichtig bewerten';
    }
    if (hasRealBookmakerOdds && valueEdge >= 8 && finalScore >= 70) {
      return 'Begründung · starkes Value-Signal';
    }
    if (hasRealBookmakerOdds) {
      return 'Begründung · echte Quote vorhanden';
    }
    return 'Begründung · Spielplan-Tipp ohne echte Quote';
  }

  List<String> _reasonPoints() {
    final points = <String>[];

    points.add(
      hasRealBookmakerOdds
          ? 'Echte Bookmaker-Quote erkannt; Tipp basiert nicht auf einer erfundenen Quote.'
          : 'Keine passende Bookmaker-Quote erkannt; Bewertung läuft nur über Spielplan und AI-Score.',
    );

    if (match.tipType == TipType.homeWin) {
      points.add('Tendenz auf Heimsieg: AI bewertet das Heimteam im aktuellen Modell stärker.');
    } else if (match.tipType == TipType.awayWin) {
      points.add('Tendenz auf Auswärtssieg: AI sieht den Gast im Modell mit Vorteil.');
    } else if (match.tipType == TipType.draw) {
      points.add('Remis-Tipp: das Modell sieht kein klares Übergewicht für eine Seite.');
    } else if (match.tipType == TipType.over25) {
      points.add('Tore-Tipp Ü2.5: die Tor-/Dynamik-Bewertung spricht eher für ein offenes Spiel.');
    } else if (match.tipType == TipType.under25) {
      points.add('Tore-Tipp U2.5: die Bewertung spricht eher für ein kontrolliertes Spiel.');
    } else if (match.tipType == TipType.btts) {
      points.add('BTTS-Tipp: beide Teams werden offensiv als relevant eingestuft.');
    }

    if (valueEdge >= 8) {
      points.add('Value Edge ist positiv: Quote und AI-Bewertung passen überdurchschnittlich gut zusammen.');
    } else if (valueEdge >= 0) {
      points.add('Value ist leicht positiv: kein Premium-Signal, aber als Auswahl beobachtbar.');
    } else {
      points.add('Value ist schwach: eher beobachten als blind übernehmen.');
    }

    if (_isHighRisk()) {
      points.add('Risiko ist hoch: nur mit kleinerem Einsatz oder als Watchlist-Tipp betrachten.');
    } else if (confidence >= 70) {
      points.add('Confidence ist stark: die Datenlage ist für diesen Tipp vergleichsweise stabil.');
    } else if (confidence >= 55) {
      points.add('Confidence ist solide: Signal ist brauchbar, aber nicht maximal stark.');
    } else {
      points.add('Confidence ist niedrig: Tipp sollte zurückhaltend bewertet werden.');
    }

    return points.take(4).toList();
  }

  Color _statusColor() {
    if (_isHighRisk() && finalScore < 70) return Colors.orange.shade800;
    if (hasRealBookmakerOdds && valueEdge >= 8 && finalScore >= 70) {
      return KickMindTheme.success;
    }
    if (hasRealBookmakerOdds) return KickMindTheme.primary;
    return Colors.blueGrey;
  }

  bool _isHighRisk() {
    final risk = match.riskLevel.toLowerCase().trim();
    return risk == 'hoch' || risk == 'high';
  }
}


class _TopTipOddsRelevance {
  final String marketLabel;
  final double oddsValue;
  final OddsMarketScore score;
  final OddsMarketDecision decision;
  final bool hasRealOdds;

  const _TopTipOddsRelevance({
    required this.marketLabel,
    required this.oddsValue,
    required this.score,
    required this.decision,
    required this.hasRealOdds,
  });

  factory _TopTipOddsRelevance.fromMatch(FootballMatch match) {
    final marketType = _marketTypeForTip(match.tipType);
    final margin = _estimatedMarginFor(match.odds);
    final score = OddsScoreService.instance.evaluate(
      oddsValue: match.odds,
      margin: margin,
      marketType: marketType,
    );
    final decision = OddsScoreService.instance.decisionFor(
      finalScore: score.finalScore,
      valueEdge: score.valueEdge,
      confidence: score.confidence,
      riskLevel: score.riskLevel,
      oddsValue: match.odds,
    );

    return _TopTipOddsRelevance(
      marketLabel: _marketLabelFor(match),
      oddsValue: match.odds,
      score: score,
      decision: decision,
      hasRealOdds: _kmHasRealBookmakerOdds(match),
    );
  }

  static OddsMarketType _marketTypeForTip(TipType tipType) {
    switch (tipType) {
      case TipType.homeWin:
        return OddsMarketType.home;
      case TipType.draw:
        return OddsMarketType.draw;
      case TipType.awayWin:
        return OddsMarketType.away;
      case TipType.over25:
        return OddsMarketType.over25;
      case TipType.under25:
        return OddsMarketType.under25;
      case TipType.btts:
        return OddsMarketType.btts;
    }
  }

  static String _marketLabelFor(FootballMatch match) {
    switch (match.tipType) {
      case TipType.homeWin:
        return '1 · Heimsieg';
      case TipType.draw:
        return 'X · Remis';
      case TipType.awayWin:
        return '2 · Auswärtssieg';
      case TipType.over25:
        return 'Ü2.5 · Tore';
      case TipType.under25:
        return 'U2.5 · Tore';
      case TipType.btts:
        return 'BTTS · Ja';
    }
  }

  static double _estimatedMarginFor(double odds) {
    if (odds <= 1.0) return 0.10;
    if (odds < 1.35 || odds >= 4.50) return 0.12;
    if (odds <= 2.40) return 0.06;
    return 0.08;
  }
}

class _TopTipOddsPanel extends StatelessWidget {
  final _TopTipOddsRelevance relevance;

  const _TopTipOddsPanel({required this.relevance});

  @override
  Widget build(BuildContext context) {
    final color = relevance.hasRealOdds
        ? _decisionColor(relevance.decision.type)
        : Colors.blueGrey;
    final valueText = relevance.score.valueEdge >= 0
        ? '+${relevance.score.valueEdge.toStringAsFixed(1)}'
        : relevance.score.valueEdge.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.query_stats_rounded, size: 17, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  relevance.hasRealOdds ? relevance.decision.label : 'Beobachtung ohne Quote',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MiniScorePill(
                text: relevance.hasRealOdds ? 'Q ${relevance.score.finalScore.toStringAsFixed(0)}' : 'Info',
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            relevance.hasRealOdds
                ? '${relevance.marketLabel} · Quote ${relevance.oddsValue.toStringAsFixed(2)} · Risiko ${relevance.score.riskLevel} · Value $valueText'
                : '${relevance.marketLabel} · Keine echte Quote · nur Beobachtung',
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
    );
  }

  Color _decisionColor(OddsMarketDecisionType type) {
    switch (type) {
      case OddsMarketDecisionType.premium:
        return KickMindTheme.success;
      case OddsMarketDecisionType.value:
        return KickMindTheme.primary;
      case OddsMarketDecisionType.stable:
        return Colors.deepPurple;
      case OddsMarketDecisionType.noBet:
        return Colors.orange.shade800;
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

class _CompactTipCard extends StatelessWidget {
  final FootballMatch match;
  final double finalScore;
  final bool isSaved;
  final VoidCallback onSaveTap;
  final VoidCallback onTap;

  const _CompactTipCard({
    required this.match,
    required this.finalScore,
    required this.isSaved,
    required this.onSaveTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);
    final oddsRelevance = _TopTipOddsRelevance.fromMatch(match);
    final isRealOdds = _kmHasRealBookmakerOdds(match);
    final sourceLabel = _kmSourceLabel(match);
    final sourceColor = _kmSourceColor(match);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: KickMindTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.045)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    finalScore.toStringAsFixed(0),
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Final',
                    style: TextStyle(
                      color: scoreColor.withOpacity(0.85),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
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
                      fontSize: 14.7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _MiniScorePill(text: sourceLabel, color: sourceColor),
                      _MiniScorePill(text: match.tipLabel, color: KickMindTheme.primary),
                      _MiniScorePill(
                        text: isRealOdds
                            ? 'Q ${oddsRelevance.score.finalScore.toStringAsFixed(0)}'
                            : 'Info',
                        color: isRealOdds ? scoreColor : Colors.blueGrey,
                      ),
                      _MiniScorePill(
                        text: isRealOdds ? match.odds.toStringAsFixed(2) : 'Keine Quote',
                        color: isRealOdds ? Colors.indigo : Colors.blueGrey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 118),
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
