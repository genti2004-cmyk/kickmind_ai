import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/presentation/match_detail_screen.dart';
import 'package:kickmind_ai/features/saved_tips/data/saved_tips_service.dart';

class SavedTipsScreen extends StatefulWidget {
  const SavedTipsScreen({super.key});

  @override
  State<SavedTipsScreen> createState() => _SavedTipsScreenState();
}

class _SavedTipsScreenState extends State<SavedTipsScreen> {
  final SavedTipsService _service = SavedTipsService();
  late Future<List<FootballMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FootballMatch>> _load() async {
    final tips = await _service.loadSavedTips();
    tips.sort((a, b) {
      final scoreCompare = _TopTipScore.fromMatch(b)
          .finalScore
          .compareTo(_TopTipScore.fromMatch(a).finalScore);
      if (scoreCompare != 0) return scoreCompare;
      return b.kickoff.compareTo(a.kickoff);
    });
    return tips;
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _removeTip(FootballMatch match) async {
    await _service.removeTip(match.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${match.teamsLabel} entfernt')),
    );

    await _reload();
  }

  Future<void> _clearAll(List<FootballMatch> tips) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Tipps löschen?'),
        content: Text(
          '${tips.length} gespeicherte ${tips.length == 1 ? 'Tipp' : 'Tipps'} werden entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _service.clearSavedTips();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gespeicherte Tipps gelöscht')),
    );

    await _reload();
  }

  void _openDetail(FootballMatch match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(match: match),
      ),
    ).then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KickMindTheme.background,
      appBar: AppBar(
        title: const Text('Meine Tipps'),
        actions: [
          FutureBuilder<List<FootballMatch>>(
            future: _future,
            builder: (context, snapshot) {
              final tips = snapshot.data ?? const <FootballMatch>[];
              if (tips.isEmpty) return const SizedBox.shrink();

              return IconButton(
                tooltip: 'Alle löschen',
                onPressed: () => _clearAll(tips),
                icon: const Icon(Icons.delete_sweep_rounded),
              );
            },
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
            return _StateMessage(
              icon: Icons.warning_amber_rounded,
              title: 'Tipps konnten nicht geladen werden',
              subtitle: 'Bitte versuche es erneut.',
              actionLabel: 'Neu laden',
              onPressed: () => _reload(),
            );
          }

          final tips = snapshot.data ?? const <FootballMatch>[];

          if (tips.isEmpty) {
            return _StateMessage(
              icon: Icons.bookmark_border_rounded,
              title: 'Noch keine gespeicherten Tipps',
              subtitle:
              'Öffne einen Top Tipp und speichere ihn über das Bookmark-Symbol.',
              actionLabel: 'Aktualisieren',
              onPressed: () => _reload(),
            );
          }

          final stats = _SavedTipsStats.fromTips(tips);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 118),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _SavedSummary(stats: stats),
                const SizedBox(height: 18),
                const _SectionTitle(
                  icon: Icons.bookmark_rounded,
                  title: 'Gespeicherte Top Tipps',
                  subtitle: 'Sortiert nach Final Score und Kickoff.',
                ),
                const SizedBox(height: 12),
                ...tips.map(
                      (match) => _SavedTipCard(
                    match: match,
                    score: _TopTipScore.fromMatch(match),
                    value: _ValueInfo.fromMatch(match),
                    onTap: () => _openDetail(match),
                    onRemove: () => _removeTip(match),
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

class _SavedSummary extends StatelessWidget {
  final _SavedTipsStats stats;

  const _SavedSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2540), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: KickMindTheme.primary.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gespeicherte Auswahl',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
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
                child: _SummaryTile(
                  label: 'Tipps',
                  value: '${stats.count}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  label: 'Ø AI',
                  value: '${stats.averageAi.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  label: 'Ø Final',
                  value: stats.averageFinal.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Value',
                  value: '${stats.valueCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  label: 'Ø Quote',
                  value: stats.averageOdds.toStringAsFixed(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  label: 'Top',
                  value: stats.bestFinal.toStringAsFixed(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedTipCard extends StatelessWidget {
  final FootballMatch match;
  final _TopTipScore score;
  final _ValueInfo value;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedTipCard({
    required this.match,
    required this.score,
    required this.value,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);
    final riskColor = KickMindTheme.riskColor(match.riskLevel);

    return Dismissible(
      key: ValueKey(match.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: KickMindTheme.danger,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onRemove();
        return false;
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: KickMindTheme.primary.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                  Expanded(
                    child: Text(
                      match.league,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KickMindTheme.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: KickMindTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _timeLabel(match),
                    style: const TextStyle(
                      color: KickMindTheme.textMuted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Entfernen',
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: const Icon(Icons.bookmark_remove_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                match.teamsLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: KickMindTheme.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.10,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(
                    text: match.tipLabel,
                    color: KickMindTheme.primary,
                    background: KickMindTheme.primary.withOpacity(0.10),
                  ),
                  _MetricChip(
                    text: 'AI ${match.aiScore}%',
                    color: scoreColor,
                    background: scoreColor.withOpacity(0.10),
                  ),
                  _MetricChip(
                    text: 'Final ${score.finalScore.toStringAsFixed(1)}',
                    color: KickMindTheme.primary,
                    background: KickMindTheme.primary.withOpacity(0.10),
                  ),
                  _MetricChip(
                    text: '${match.riskEmoji} ${match.riskLevel}',
                    color: riskColor,
                    background: riskColor.withOpacity(0.10),
                  ),
                  _MetricChip(
                    text: 'Quote ${match.odds.toStringAsFixed(2)}',
                    color: const Color(0xFF4655A5),
                    background: const Color(0xFF4655A5).withOpacity(0.10),
                  ),
                  if (value.isValueBet)
                    _MetricChip(
                      text: 'Value +${value.edgePercent.toStringAsFixed(1)}%',
                      color: KickMindTheme.success,
                      background: KickMindTheme.success.withOpacity(0.10),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Confidence',
                    style: TextStyle(
                      color: KickMindTheme.textMuted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${score.confidence.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: (score.confidence / 100).clamp(0.0, 1.0),
                  backgroundColor: scoreColor.withOpacity(0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _reasonText(match, score, value),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  height: 1.35,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeLabel(FootballMatch match) {
    if (match.kickoffLabel.trim().isNotEmpty) return match.kickoffLabel;

    final hour = match.kickoff.hour.toString().padLeft(2, '0');
    final minute = match.kickoff.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _reasonText(
      FootballMatch match,
      _TopTipScore score,
      _ValueInfo value,
      ) {
    final valueText = value.isValueBet
        ? ' Value +${value.edgePercent.toStringAsFixed(1)}%.'
        : '';

    final reason = match.shortReason.trim();
    return '${match.tipLabel} gespeichert. Final ${score.finalScore.toStringAsFixed(1)}, AI ${match.aiScore}%, Confidence ${score.confidence.toStringAsFixed(0)}%, Risiko ${match.riskLevel}.$valueText ${reason.isEmpty ? 'Bewertung basiert auf Form, Quote, Risiko und Tore-Trend.' : reason}';
  }
}

class _MetricChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _MetricChip({
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: KickMindTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: KickMindTheme.primary),
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
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: KickMindTheme.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
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
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: KickMindTheme.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: KickMindTheme.primary, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KickMindTheme.textDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KickMindTheme.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedTipsStats {
  final int count;
  final double averageAi;
  final double averageFinal;
  final double averageOdds;
  final double bestFinal;
  final int valueCount;

  const _SavedTipsStats({
    required this.count,
    required this.averageAi,
    required this.averageFinal,
    required this.averageOdds,
    required this.bestFinal,
    required this.valueCount,
  });

  factory _SavedTipsStats.fromTips(List<FootballMatch> tips) {
    if (tips.isEmpty) {
      return const _SavedTipsStats(
        count: 0,
        averageAi: 0,
        averageFinal: 0,
        averageOdds: 0,
        bestFinal: 0,
        valueCount: 0,
      );
    }

    final scores = tips.map(_TopTipScore.fromMatch).toList();
    final values = tips.map(_ValueInfo.fromMatch).toList();

    return _SavedTipsStats(
      count: tips.length,
      averageAi: tips.map((m) => m.aiScore).reduce((a, b) => a + b) / tips.length,
      averageFinal:
      scores.map((s) => s.finalScore).reduce((a, b) => a + b) / scores.length,
      averageOdds: tips.map((m) => m.odds).reduce((a, b) => a + b) / tips.length,
      bestFinal: scores.map((s) => s.finalScore).reduce((a, b) => a > b ? a : b),
      valueCount: values.where((v) => v.isValueBet).length,
    );
  }
}

class _TopTipScore {
  final double finalScore;
  final double confidence;

  const _TopTipScore({required this.finalScore, required this.confidence});

  factory _TopTipScore.fromMatch(FootballMatch match) {
    final value = _ValueInfo.fromMatch(match).edgePercent.clamp(-15.0, 18.0);
    final riskBonus = _riskBonus(match);
    final oddsBonus = _oddsBonus(match.odds);
    final formBoost = _formBoost(match);

    final finalScore = (match.aiScore * 0.62 + value * 0.95 + riskBonus + oddsBonus + formBoost)
        .clamp(1.0, 99.0)
        .toDouble();

    final confidence = (match.aiScore + riskBonus + formBoost + oddsBonus)
        .clamp(1.0, 99.0)
        .toDouble();

    return _TopTipScore(finalScore: finalScore, confidence: confidence);
  }

  static double _riskBonus(FootballMatch match) {
    final risk = match.riskLevel.toLowerCase();
    if (risk.contains('niedrig') || risk.contains('low')) return 8.0;
    if (risk.contains('mittel') || risk.contains('medium')) return 2.0;
    return -10.0;
  }

  static double _oddsBonus(double odds) {
    if (odds >= 1.45 && odds <= 2.05) return 5.0;
    if (odds > 2.05 && odds <= 2.45) return 1.0;
    if (odds < 1.25 || odds > 3.10) return -5.0;
    return 0.0;
  }

  static double _formBoost(FootballMatch match) {
    final strongestForm = match.homeFormScore > match.awayFormScore
        ? match.homeFormScore
        : match.awayFormScore;

    if (strongestForm >= 84) return 5.0;
    if (strongestForm >= 76) return 2.5;
    if (strongestForm < 58) return -4.0;
    return 0.0;
  }
}

class _ValueInfo {
  final double edgePercent;

  const _ValueInfo({required this.edgePercent});

  bool get isValueBet => edgePercent >= 4.5;

  factory _ValueInfo.fromMatch(FootballMatch match) {
    if (match.odds <= 1.0) return const _ValueInfo(edgePercent: 0);

    final aiProbability = (match.aiScore / 100.0).clamp(0.0, 1.0);
    final impliedProbability = (1.0 / match.odds).clamp(0.0, 1.0);

    return _ValueInfo(
      edgePercent: (aiProbability - impliedProbability) * 100.0,
    );
  }
}
