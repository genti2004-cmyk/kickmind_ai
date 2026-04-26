import 'package:flutter/material.dart';
import '../../saved_tips/data/saved_tips_service.dart';
import '../../saved_tips/domain/saved_tip.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/football_match.dart';

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
  final TextEditingController stakeController = TextEditingController(text: '10');

  @override
  void dispose() {
    stakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Spielanalyse'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeaderCard(match: match),
          const SizedBox(height: 14),
          _RecommendationCard(match: match),
          const SizedBox(height: 14),
          _ProfitSimulator(
            match: match,
            controller: stakeController,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          _SaveTipButton(
            match: match,
            stakeController: stakeController,
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Analysewerte'),
          const SizedBox(height: 10),
          _MetricBar(title: 'Heimform', value: match.homeFormScore),
          const SizedBox(height: 12),
          _MetricBar(title: 'Auswärtsform', value: match.awayFormScore),
          const SizedBox(height: 12),
          _MetricBar(title: 'Tortrend', value: match.goalsScore),
          const SizedBox(height: 16),
          _ReasonCard(reason: match.shortReason),
          const SizedBox(height: 16),
          _ApiInfoCard(match: match),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final FootballMatch match;

  const _HeaderCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final time =
        '${match.kickoff.hour.toString().padLeft(2, '0')}:${match.kickoff.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF063A68), Color(0xFF0B1B2E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            match.league,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${match.homeTeam}\nvs ${match.awayTeam}',
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppTheme.mutedText, size: 18),
              const SizedBox(width: 6),
              Text(
                '$time Uhr',
                style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _MiniBadge(label: 'Saison ${match.season}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final FootballMatch match;

  const _RecommendationCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.blue.withOpacity(0.14),
              border: Border.all(color: AppTheme.blue.withOpacity(0.65)),
            ),
            child: Text(
              '${match.aiScore}%',
              style: const TextStyle(
                color: AppTheme.blue,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Empfohlener Tipp',
                  style: TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  match.tipLabel,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniBadge(label: 'Quote ${match.odds.toStringAsFixed(2)}'),
                    _MiniBadge(label: 'Risiko ${match.riskLabel}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitSimulator extends StatelessWidget {
  final FootballMatch match;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _ProfitSimulator({
    required this.match,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rawStake = controller.text.replaceAll(',', '.');
    final stake = double.tryParse(rawStake) ?? 0;
    final payout = stake * match.odds;
    final profit = payout - stake;
    final hitChance = match.aiScore.clamp(1, 95);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 Gewinn Simulation',
            style: TextStyle(
              color: AppTheme.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            style: const TextStyle(
              color: AppTheme.text,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              labelText: 'Einsatz in €',
              labelStyle: const TextStyle(color: AppTheme.mutedText),
              prefixIcon: const Icon(Icons.euro_rounded, color: AppTheme.blue),
              filled: true,
              fillColor: AppTheme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.blue.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.blue),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SimBox(
                  label: 'Auszahlung',
                  value: '${payout.toStringAsFixed(2)} €',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SimBox(
                  label: 'Profit',
                  value: '${profit.toStringAsFixed(2)} €',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SimBox(
            label: 'geschätzte Trefferchance',
            value: '$hitChance%',
          ),
        ],
      ),
    );
  }
}

class _SimBox extends StatelessWidget {
  final String label;
  final String value;

  const _SimBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String title;
  final int value;

  const _MetricBar({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0, 100) / 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$value%',
                style: const TextStyle(
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppTheme.card,
            color: AppTheme.blue,
          ),
        ],
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final String reason;

  const _ReasonCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology_rounded, color: AppTheme.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiInfoCard extends StatelessWidget {
  final FootballMatch match;

  const _ApiInfoCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'API-Daten'),
          const SizedBox(height: 12),
          _InfoRow(label: 'Fixture ID', value: match.fixtureId?.toString() ?? '-'),
          _InfoRow(label: 'League ID', value: match.leagueId?.toString() ?? '-'),
          _InfoRow(label: 'Home Team ID', value: match.homeTeamId?.toString() ?? '-'),
          _InfoRow(label: 'Away Team ID', value: match.awayTeamId?.toString() ?? '-'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.text,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
class _SaveTipButton extends StatelessWidget {
  final FootballMatch match;
  final TextEditingController stakeController;

  const _SaveTipButton({
    required this.match,
    required this.stakeController,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () async {
        final rawStake = stakeController.text.replaceAll(',', '.');
        final stake = double.tryParse(rawStake) ?? 0;

        final tip = SavedTip(
          id: match.id,
          league: match.league,
          homeTeam: match.homeTeam,
          awayTeam: match.awayTeam,
          tipLabel: match.tipLabel,
          aiScore: match.aiScore,
          odds: match.odds,
          stake: stake,
          savedAt: DateTime.now(),
        );

        await const SavedTipsService().saveTip(tip);

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tipp gespeichert'),
          ),
        );
      },
      icon: const Icon(Icons.bookmark_add_rounded),
      label: const Text('Tipp speichern'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}