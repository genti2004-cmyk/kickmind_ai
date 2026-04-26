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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Spielanalyse'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeaderCard(match: match),
          const SizedBox(height: 16),
          _RecommendationCard(match: match),
          const SizedBox(height: 16),
          _MetricBar(
            title: 'Heimform',
            value: match.homeFormScore,
          ),
          const SizedBox(height: 12),
          _MetricBar(
            title: 'Auswärtsform',
            value: match.awayFormScore,
          ),
          const SizedBox(height: 12),
          _MetricBar(
            title: 'Torbewertung',
            value: match.goalsScore,
          ),
          const SizedBox(height: 16),
          _ReasonCard(reason: match.shortReason),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF063A68),
            Color(0xFF0B1B2E),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            match.league,
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
                '${match.kickoff.hour.toString().padLeft(2, '0')}:${match.kickoff.minute.toString().padLeft(2, '0')} Uhr',
                style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontWeight: FontWeight.w700,
                ),
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
            width: 72,
            height: 72,
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
                fontSize: 20,
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
                    fontWeight: FontWeight.w700,
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
                const SizedBox(height: 6),
                Text(
                  'Quote ${match.odds.toStringAsFixed(2)} · Risiko ${match.riskLabel}',
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 13,
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

class _MetricBar extends StatelessWidget {
  final String title;
  final int value;

  const _MetricBar({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value.clamp(0, 100)) / 100;

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
      child: Text(
        reason,
        style: const TextStyle(
          color: AppTheme.text,
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}