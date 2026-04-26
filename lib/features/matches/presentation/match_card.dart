import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/football_match.dart';
import 'match_detail_screen.dart';

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
    final time =
        '${match.kickoff.hour.toString().padLeft(2, '0')}:${match.kickoff.minute.toString().padLeft(2, '0')}';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(match: match),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopLine(
              league: match.league,
              time: time,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.sports_soccer_rounded,
                  color: AppTheme.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${match.homeTeam}\nvs ${match.awayTeam}',
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.28,
                    ),
                  ),
                ),
                _ScoreBadge(score: match.aiScore),
              ],
            ),
            const SizedBox(height: 14),
            _PredictionBox(match: match),
            if (showReason) ...[
              const SizedBox(height: 12),
              _ReasonText(reason: match.shortReason),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopLine extends StatelessWidget {
  final String league;
  final String time;

  const _TopLine({
    required this.league,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            league,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppTheme.mutedText,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PredictionBox extends StatelessWidget {
  final FootballMatch match;

  const _PredictionBox({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.blue.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppTheme.blue,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              match.tipLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SmallBadge(label: 'Quote ${match.odds.toStringAsFixed(2)}'),
          const SizedBox(width: 6),
          _SmallBadge(label: match.riskLabel),
        ],
      ),
    );
  }
}

class _ReasonText extends StatelessWidget {
  final String reason;

  const _ReasonText({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Text(
      reason,
      style: const TextStyle(
        color: AppTheme.mutedText,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w600,
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
      width: 60,
      height: 60,
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

class _SmallBadge extends StatelessWidget {
  final String label;

  const _SmallBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.blue.withOpacity(0.08)),
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