import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/saved_tips/data/saved_tips_service.dart';

class MatchDetailScreen extends StatefulWidget {
  final FootballMatch match;

  const MatchDetailScreen({
    super.key,
    required this.match,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final SavedTipsService _savedTipsService = SavedTipsService();
  bool _isSaved = false;
  bool _loading = true;

  FootballMatch get match => widget.match;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await _savedTipsService.isSaved(match.id);
    if (!mounted) return;

    setState(() {
      _isSaved = saved;
      _loading = false;
    });
  }

  Future<void> _toggleSaved() async {
    if (_isSaved) {
      await _savedTipsService.removeTip(match.id);
    } else {
      await _savedTipsService.saveTip(match);
    }

    if (!mounted) return;

    setState(() {
      _isSaved = !_isSaved;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved ? 'Tipp gespeichert' : 'Tipp entfernt',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(match.aiScore);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Analyse'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _toggleSaved,
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroCard(match: match, scoreColor: scoreColor),
              const SizedBox(height: 16),

              _SectionTitle('KI Empfehlung'),
              const SizedBox(height: 10),
              _RecommendationCard(match: match, scoreColor: scoreColor),
              const SizedBox(height: 16),

              _SectionTitle('Analysewerte'),
              const SizedBox(height: 10),
              _StatsGrid(match: match),
              const SizedBox(height: 16),

              _SectionTitle('Formvergleich'),
              const SizedBox(height: 10),
              _FormComparison(match: match),
              const SizedBox(height: 16),

              _SectionTitle('Begründung'),
              const SizedBox(height: 10),
              _ReasonCard(text: match.shortReason),
            ],
          ),
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 82) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }
}

class _HeroCard extends StatelessWidget {
  final FootballMatch match;
  final Color scoreColor;

  const _HeroCard({
    required this.match,
    required this.scoreColor,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            match.league,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            match.teamsLabel,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                match.kickoffLabel,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _Badge(
                text: 'AI ${match.aiScore}%',
                color: scoreColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final FootballMatch match;
  final Color scoreColor;

  const _RecommendationCard({
    required this.match,
    required this.scoreColor,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
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
                fontSize: 18,
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
                _Badge(text: '${match.riskEmoji} ${match.riskLevel}', color: scoreColor),
                _Badge(text: 'Quote ${match.odds.toStringAsFixed(2)}', color: Colors.indigo),
                _Badge(text: 'Score ${match.aiScore}/100', color: scoreColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final FootballMatch match;

  const _StatsGrid({required this.match});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Heimform', value: '${match.homeFormScore}')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Auswärtsform', value: '${match.awayFormScore}')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Tore-Trend', value: '${match.goalsScore}')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Saison', value: '${match.season}')),
          ],
        ),
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
    final homeFactor = match.homeFormScore / total;
    final awayFactor = match.awayFormScore / total;

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TeamBar(
            label: match.homeTeam,
            value: match.homeFormScore,
            factor: homeFactor,
            color: Colors.blue,
          ),
          const SizedBox(height: 14),
          _TeamBar(
            label: match.awayTeam,
            value: match.awayFormScore,
            factor: awayFactor,
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
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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

class _ReasonCard extends StatelessWidget {
  final String text;

  const _ReasonCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Text(
        text.isEmpty ? 'Keine Begründung vorhanden.' : text,
        style: TextStyle(
          color: Colors.grey.shade800,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
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

  const _Badge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
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
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}