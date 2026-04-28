import 'package:flutter/material.dart';

import '../domain/football_match.dart';
import 'match_detail_screen.dart';

class MatchCard extends StatelessWidget {
  final FootballMatch match;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onTap;

  const MatchCard({
    super.key,
    required this.match,
    this.trailingLabel,
    this.onTrailingTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(match.aiScore);
    final riskColor = _riskColor(match.riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap ??
                () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MatchDetailScreen(match: match),
                ),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    match.kickoffLabel,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                match.teamsLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(text: match.tipLabel, color: const Color(0xFF1565C0)),
                  _Badge(text: 'AI ${match.aiScore}', color: scoreColor),
                  _Badge(text: '${match.riskEmoji} ${match.riskLabel}', color: riskColor),
                  _Badge(text: 'Quote ${match.odds.toStringAsFixed(2)}', color: Colors.indigo),
                ],
              ),
              if (match.shortReason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  match.shortReason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (trailingLabel != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onTrailingTap,
                    child: Text(trailingLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 82) return const Color(0xFF16A34A);
    if (score >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  Color _riskColor(String risk) {
    final value = risk.toLowerCase();
    if (value.contains('niedrig') || value.contains('low')) return const Color(0xFF16A34A);
    if (value.contains('mittel') || value.contains('medium')) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
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
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
