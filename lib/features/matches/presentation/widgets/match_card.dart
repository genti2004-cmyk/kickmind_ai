import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';

class MatchCard extends StatelessWidget {
  final FootballMatch match;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool compact;
  final String? badge;

  const MatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.trailing,
    this.compact = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = KickMindTheme.scoreColor(match.aiScore);
    final riskColor = KickMindTheme.riskColor(match.riskLevel);
    final valueInfo = _ValueInfo.fromMatch(match);
    final effectiveBadge = badge ??
        (valueInfo.isValueBet
            ? '💰 VALUE BET'
            : (!match.hasPlayableOdds ? '📅 Spielplan' : null));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: KickMindTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: valueInfo.isValueBet
                ? KickMindTheme.success.withOpacity(0.26)
                : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (effectiveBadge != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: KickMindTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  effectiveBadge,
                  style: const TextStyle(
                    color: KickMindTheme.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.league,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KickMindTheme.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.schedule_rounded, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  match.kickoffLabel,
                  style: const TextStyle(
                    color: KickMindTheme.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              match.teamsLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: KickMindTheme.textDark,
                fontSize: compact ? 15 : 17,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Badge(text: match.tipLabel, color: KickMindTheme.primary),
                _Badge(text: 'AI ${match.aiScore}%', color: scoreColor),
                _Badge(text: '${match.riskEmoji} ${match.riskLevel}', color: riskColor),
                if (match.hasPlayableOdds)
                  _Badge(
                    text: '${match.realOddsBookmaker ?? 'Bookmaker'} ${match.odds.toStringAsFixed(2)}',
                    color: Colors.indigo,
                  )
                else
                  _Badge(text: 'Keine echte Quote', color: Colors.blueGrey),
                if (valueInfo.isValueBet)
                  _Badge(text: 'Value +${valueInfo.edgePercent.toStringAsFixed(1)}%', color: KickMindTheme.success),
                if (trailing != null) trailing!,
              ],
            ),
            if (!compact && match.shortReason.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                match.shortReason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueInfo {
  final bool isValueBet;
  final double edgePercent;

  const _ValueInfo({required this.isValueBet, required this.edgePercent});

  factory _ValueInfo.fromMatch(FootballMatch match) {
    if (!match.hasPlayableOdds || match.odds <= 1.0) {
      return const _ValueInfo(isValueBet: false, edgePercent: 0);
    }

    final aiProbability = (match.aiScore / 100).clamp(0.0, 1.0);
    final impliedProbability = (1 / match.odds).clamp(0.0, 1.0);
    final edge = aiProbability - impliedProbability;

    return _ValueInfo(
      isValueBet: match.aiScore >= 70 && edge >= 0.05,
      edgePercent: edge * 100,
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
