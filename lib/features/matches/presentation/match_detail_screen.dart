import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/football_match.dart';

class MatchDetailScreen extends StatelessWidget {
  final FootballMatch match;

  const MatchDetailScreen({
    super.key,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    final hasApiIds =
        match.fixtureId != null && match.leagueId != null && match.homeTeamId != null && match.awayTeamId != null;

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
          _SourceCard(hasApiIds: hasApiIds),
          const SizedBox(height: 14),
          _RecommendationCard(match: match),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Analysewerte'),
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
          colors: [
            Color(0xFF063A68),
            Color(0xFF0B1B2E),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.blue.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
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

class _SourceCard extends StatelessWidget {
  final bool hasApiIds;

  const _SourceCard({required this.hasApiIds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.blue.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(
            hasApiIds ? Icons.cloud_done_rounded : Icons.info_outline_rounded,
            color: AppTheme.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasApiIds
                  ? 'Live-Daten erkannt. Analyse basiert auf API-Spiel- und Teamdaten.'
                  : 'Teilweise Fallback-Daten. Analyse wird automatisch verbessert, sobald API-Werte verfügbar sind.',
              style: const TextStyle(
                color: AppTheme.mutedText,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
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
        border: Border.all(color: AppTheme.blue.withOpacity(0.10)),
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
        border: Border.all(color: AppTheme.blue.withOpacity(0.10)),
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
        border: Border.all(color: AppTheme.blue.withOpacity(0.10)),
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
        border: Border.all(color: AppTheme.blue.withOpacity(0.10)),
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