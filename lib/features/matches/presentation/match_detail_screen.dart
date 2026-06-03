import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_breakdown.dart';
import 'package:kickmind_ai/features/saved_tips/data/saved_tips_service.dart';
import 'package:kickmind_ai/features/team_stats/data/mock_team_stats_repository.dart';
import 'package:kickmind_ai/features/team_stats/data/pro_stats_enrichment_service.dart';

class MatchDetailScreen extends StatefulWidget {
  final FootballMatch match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final SavedTipsService _savedTipsService = SavedTipsService();

  bool _saved = false;
  bool _loading = true;
  double _stake = 10;

  FootballMatch get match => widget.match;

  late final PredictionBreakdown breakdown =
  const ProStatsEnrichmentService().buildBreakdown(
    const MockTeamStatsRepository().buildInput(match),
  );

  late final _TopTipScore topScore = _TopTipScore.fromMatch(match);
  late final _ValueInfo valueInfo = _ValueInfo.fromMatch(match);

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final saved = await _savedTipsService.isSaved(match.id);
    if (!mounted) return;

    setState(() {
      _saved = saved;
      _loading = false;
    });
  }

  Future<void> _toggleSaved() async {
    if (_saved) {
      await _savedTipsService.removeTip(match.id);
    } else {
      await _savedTipsService.saveTip(match);
    }

    if (!mounted) return;

    setState(() => _saved = !_saved);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_saved ? 'Tipp gespeichert' : 'Tipp entfernt')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final possibleReturn = _stake * match.odds;
    final profit = possibleReturn - _stake;

    return Scaffold(
      backgroundColor: KickMindTheme.background,
      appBar: AppBar(
        title: const Text('Pro Analyse'),
        actions: [
          IconButton(
            tooltip: _saved ? 'Tipp entfernen' : 'Tipp speichern',
            onPressed: _loading ? null : _toggleSaved,
            icon: Icon(
              _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 118),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                match: match,
                breakdown: breakdown,
                topScore: topScore,
                valueInfo: valueInfo,
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Top-Tipps Bewertung'),
              const SizedBox(height: 10),
              _TopTipsScoreCard(match: match, topScore: topScore),
              const SizedBox(height: 16),
              const _SectionTitle('KI Empfehlung'),
              const SizedBox(height: 10),
              _Recommendation(
                match: match,
                breakdown: breakdown,
                topScore: topScore,
                valueInfo: valueInfo,
              ),
              const SizedBox(height: 16),
              if (valueInfo.isValueBet) ...[
                const _SectionTitle('Value Bet Erklärung'),
                const SizedBox(height: 10),
                _ValueExplanation(match: match, valueInfo: valueInfo),
                const SizedBox(height: 16),
              ],
              const _SectionTitle('AI Breakdown'),
              const SizedBox(height: 10),
              _BreakdownCard(breakdown: breakdown),
              const SizedBox(height: 16),
              const _SectionTitle('Analysewerte'),
              const SizedBox(height: 10),
              _StatsGrid(match: match, breakdown: breakdown, topScore: topScore),
              const SizedBox(height: 16),
              const _SectionTitle('Formvergleich'),
              const SizedBox(height: 10),
              _FormComparison(match: match),
              const SizedBox(height: 16),
              const _SectionTitle('Begründung'),
              const SizedBox(height: 10),
              _PremiumCard(
                child: Text(
                  _buildReason(),
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Gewinnsimulation'),
              const SizedBox(height: 10),
              _PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Einsatz: ${_stake.toStringAsFixed(0)} €',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Slider(
                      min: 5,
                      max: 100,
                      divisions: 19,
                      value: _stake,
                      onChanged: (value) => setState(() => _stake = value),
                    ),
                    _InfoRow(
                      label: 'Mögliche Auszahlung',
                      value: '${possibleReturn.toStringAsFixed(2)} €',
                    ),
                    _InfoRow(
                      label: 'Möglicher Gewinn',
                      value: '${profit.toStringAsFixed(2)} €',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _toggleSaved,
                  icon: Icon(
                    _saved
                        ? Icons.bookmark_remove_rounded
                        : Icons.bookmark_add_rounded,
                  ),
                  label: Text(_saved ? 'Tipp entfernen' : 'Tipp speichern'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildReason() {
    final rawReason = breakdown.reason.trim().isEmpty
        ? match.shortReason.trim()
        : breakdown.reason.trim();

    final valueText = valueInfo.isValueBet
        ? ' Value +${valueInfo.edgePercent.toStringAsFixed(1)}% gegenüber der impliziten Quote.'
        : '';

    return '${match.tipLabel} empfohlen. Final Score ${topScore.finalScore.toStringAsFixed(1)}, AI ${match.aiScore}%, Confidence ${topScore.confidence.toStringAsFixed(0)}%, Risiko ${match.riskLevel}.$valueText ${rawReason.isEmpty ? 'Die Bewertung kombiniert Form, Heim/Auswärts-Werte, Tore-Trend, Risiko und Quote.' : rawReason}';
  }
}

class _Hero extends StatelessWidget {
  final FootballMatch match;
  final PredictionBreakdown breakdown;
  final _TopTipScore topScore;
  final _ValueInfo valueInfo;

  const _Hero({
    required this.match,
    required this.breakdown,
    required this.topScore,
    required this.valueInfo,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);

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
            color: KickMindTheme.primary.withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (valueInfo.isValueBet) const _WhiteBadge(text: 'VALUE'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            match.teamsLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WhiteBadge(text: match.kickoffLabel),
              _WhiteBadge(text: 'Tipp ${match.tipLabel}'),
              _WhiteBadge(text: 'AI ${match.aiScore}%'),
              _WhiteBadge(text: 'Final ${topScore.finalScore.toStringAsFixed(1)}'),
              _WhiteBadge(text: 'Confidence ${topScore.confidence.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (topScore.confidence / 100).clamp(0.03, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.16),
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTipsScoreCard extends StatelessWidget {
  final FootballMatch match;
  final _TopTipScore topScore;

  const _TopTipsScoreCard({required this.match, required this.topScore});

  @override
  Widget build(BuildContext context) {
    final riskColor = KickMindTheme.riskColor(match.riskLevel);

    return _PremiumCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ScoreTile(
                  label: 'Final',
                  value: topScore.finalScore.toStringAsFixed(1),
                  icon: Icons.auto_graph_rounded,
                  color: KickMindTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScoreTile(
                  label: 'Value',
                  value: '${topScore.valueEdge >= 0 ? '+' : ''}${topScore.valueEdge.toStringAsFixed(1)}%',
                  icon: Icons.trending_up_rounded,
                  color: topScore.valueEdge >= 0
                      ? KickMindTheme.success
                      : KickMindTheme.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ScoreTile(
                  label: 'Risiko',
                  value: match.riskLevel,
                  icon: Icons.shield_rounded,
                  color: riskColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScoreTile(
                  label: 'Quote',
                  value: match.odds.toStringAsFixed(2),
                  icon: Icons.percent_rounded,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ScoreTile({
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
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KickMindTheme.textMuted,
              fontSize: 12,
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
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Recommendation extends StatelessWidget {
  final FootballMatch match;
  final PredictionBreakdown breakdown;
  final _TopTipScore topScore;
  final _ValueInfo valueInfo;

  const _Recommendation({
    required this.match,
    required this.breakdown,
    required this.topScore,
    required this.valueInfo,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);
    final riskColor = KickMindTheme.riskColor(match.riskLevel);

    return _PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              match.tipLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scoreColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(text: '${match.riskEmoji} ${match.riskLevel}', color: riskColor),
                _Badge(text: 'Quote ${match.odds.toStringAsFixed(2)}', color: Colors.deepPurple),
                _Badge(text: 'AI ${match.aiScore}%', color: KickMindTheme.warning),
                _Badge(text: 'Final ${topScore.finalScore.toStringAsFixed(1)}', color: KickMindTheme.primary),
                _Badge(text: 'Confidence ${topScore.confidence.toStringAsFixed(0)}%', color: KickMindTheme.accent),
                if (valueInfo.isValueBet)
                  _Badge(text: 'Value +${valueInfo.edgePercent.toStringAsFixed(1)}%', color: KickMindTheme.success),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueExplanation extends StatelessWidget {
  final FootballMatch match;
  final _ValueInfo valueInfo;

  const _ValueExplanation({required this.match, required this.valueInfo});

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VALUE BET gefunden',
            style: TextStyle(
              color: KickMindTheme.success,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'AI Wahrscheinlichkeit', value: '${valueInfo.aiProbabilityPercent.toStringAsFixed(1)}%'),
          _InfoRow(label: 'Quote', value: match.odds.toStringAsFixed(2)),
          _InfoRow(label: 'Implizite Wahrscheinlichkeit', value: '${valueInfo.impliedProbabilityPercent.toStringAsFixed(1)}%'),
          _InfoRow(label: 'Vorteil / Edge', value: '+${valueInfo.edgePercent.toStringAsFixed(1)}%'),
          const SizedBox(height: 8),
          Text(
            'Die AI-Wahrscheinlichkeit liegt über der aus der Quote abgeleiteten Wahrscheinlichkeit. Das ist ein potenzieller Value-Hinweis, keine Gewinn-Garantie.',
            style: TextStyle(
              color: Colors.grey.shade800,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final PredictionBreakdown breakdown;

  const _BreakdownCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        children: [
          _BreakdownBar(label: 'Form', value: breakdown.formScore, color: KickMindTheme.primary),
          const SizedBox(height: 12),
          _BreakdownBar(label: 'Heim/Auswärts', value: breakdown.homeAwayScore, color: Colors.deepPurple),
          const SizedBox(height: 12),
          _BreakdownBar(label: 'Tore-Trend', value: breakdown.goalsTrendScore, color: KickMindTheme.accent),
          const SizedBox(height: 12),
          _BreakdownBar(label: 'Direkte Duelle', value: breakdown.headToHeadScore, color: Colors.indigo),
          const SizedBox(height: 12),
          _BreakdownBar(label: 'Tabelle', value: breakdown.tableScore, color: Colors.blueGrey),
        ],
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _BreakdownBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '$value/100',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.03, 1.0),
            minHeight: 10,
            backgroundColor: color.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final FootballMatch match;
  final PredictionBreakdown breakdown;
  final _TopTipScore topScore;

  const _StatsGrid({
    required this.match,
    required this.breakdown,
    required this.topScore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _StatTile(label: 'AI Score', value: '${match.aiScore}%', icon: Icons.psychology_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatTile(label: 'Final Score', value: topScore.finalScore.toStringAsFixed(1), icon: Icons.auto_graph_rounded)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StatTile(label: 'Confidence', value: '${topScore.confidence.toStringAsFixed(0)}%', icon: Icons.verified_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatTile(label: 'Breakdown', value: '${breakdown.confidence}%', icon: Icons.analytics_rounded)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StatTile(label: 'Heimform', value: '${match.homeFormScore}', icon: Icons.home_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatTile(label: 'Auswärtsform', value: '${match.awayFormScore}', icon: Icons.flight_takeoff_rounded)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StatTile(label: 'Tore-Trend', value: '${match.goalsScore}', icon: Icons.sports_soccer_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatTile(label: 'Risiko', value: match.riskLevel, icon: Icons.shield_rounded)),
        ]),
      ],
    );
  }
}

class _FormComparison extends StatelessWidget {
  final FootballMatch match;

  const _FormComparison({required this.match});

  @override
  Widget build(BuildContext context) {
    final total = (match.homeFormScore + match.awayFormScore).clamp(1, 200);

    return _PremiumCard(
      child: Column(
        children: [
          _TeamBar(
            label: match.homeTeam,
            value: match.homeFormScore,
            factor: match.homeFormScore / total,
            color: KickMindTheme.primary,
          ),
          const SizedBox(height: 14),
          _TeamBar(
            label: match.awayTeam,
            value: match.awayFormScore,
            factor: match.awayFormScore / total,
            color: Colors.deepPurple,
          ),
        ],
      ),
    );
  }
}

class _TeamBar extends StatelessWidget {
  final String label;
  final int value;
  final double factor;
  final Color color;

  const _TeamBar({
    required this.label,
    required this.value,
    required this.factor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: factor.clamp(0.05, 1.0),
            minHeight: 10,
            backgroundColor: color.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: KickMindTheme.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: KickMindTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: KickMindTheme.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumCard({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

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
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _WhiteBadge extends StatelessWidget {
  final String text;

  const _WhiteBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _TopTipScore {
  final double finalScore;
  final double valueEdge;
  final double confidence;

  const _TopTipScore({
    required this.finalScore,
    required this.valueEdge,
    required this.confidence,
  });

  factory _TopTipScore.fromMatch(FootballMatch match) {
    final valueEdge = _valueEdge(match);
    final riskBonus = _riskBonus(match);
    final oddsBonus = _oddsBonus(match.odds);
    final formBoost = _formBoost(match);

    final finalScore = (match.aiScore * 0.62 +
        valueEdge.clamp(-15.0, 18.0) * 0.95 +
        riskBonus +
        oddsBonus +
        formBoost)
        .clamp(1.0, 99.0)
        .toDouble();

    final confidence =
    (match.aiScore + riskBonus + formBoost + oddsBonus).clamp(1.0, 99.0).toDouble();

    return _TopTipScore(
      finalScore: finalScore,
      valueEdge: valueEdge,
      confidence: confidence,
    );
  }

  static double _valueEdge(FootballMatch match) {
    if (match.odds <= 1.0) return 0.0;

    final aiProbability = (match.aiScore / 100.0).clamp(0.0, 1.0).toDouble();
    final impliedProbability = (1.0 / match.odds).clamp(0.0, 1.0).toDouble();

    return (aiProbability - impliedProbability) * 100.0;
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
  final bool isValueBet;
  final double aiProbabilityPercent;
  final double impliedProbabilityPercent;
  final double edgePercent;

  const _ValueInfo({
    required this.isValueBet,
    required this.aiProbabilityPercent,
    required this.impliedProbabilityPercent,
    required this.edgePercent,
  });

  factory _ValueInfo.fromMatch(FootballMatch match) {
    if (match.odds <= 1.0) {
      return const _ValueInfo(
        isValueBet: false,
        aiProbabilityPercent: 0,
        impliedProbabilityPercent: 0,
        edgePercent: 0,
      );
    }

    final aiProbability = (match.aiScore / 100).clamp(0.0, 1.0);
    final impliedProbability = (1 / match.odds).clamp(0.0, 1.0);
    final edge = aiProbability - impliedProbability;

    return _ValueInfo(
      isValueBet: match.aiScore >= 70 && edge >= 0.045,
      aiProbabilityPercent: aiProbability * 100,
      impliedProbabilityPercent: impliedProbability * 100,
      edgePercent: edge * 100,
    );
  }
}
