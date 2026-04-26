import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/football_match.dart';

class MatchCard extends StatelessWidget {
  final FootballMatch match;
  final bool showReason;

  const MatchCard({
    super.key,
    required this.match,
    this.showReason = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            match.league,
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.sports_soccer, color: AppTheme.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${match.homeTeam}\nvs ${match.awayTeam}',
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ),
              _ScoreBadge(score: match.aiScore),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Chip(label: match.tipLabel),
              const SizedBox(width: 8),
              _Chip(label: 'Risiko: ${match.riskLabel}'),
              const SizedBox(width: 8),
              _Chip(label: 'Quote ${match.odds.toStringAsFixed(2)}'),
            ],
          ),
          if (showReason) ...[
            const SizedBox(height: 12),
            Text(
              match.shortReason,
              style: const TextStyle(
                color: AppTheme.mutedText,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;

  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.blue.withOpacity(0.14),
        border: Border.all(color: AppTheme.blue.withOpacity(0.65)),
      ),
      child: Text(
        '$score%',
        style: const TextStyle(
          color: AppTheme.blue,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}