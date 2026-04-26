import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../matches/data/mock_matches_repository.dart';
import '../../matches/presentation/match_card.dart';

class TopTipsScreen extends StatelessWidget {
  const TopTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = const MockMatchesRepository().getTopTips();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Top Tipps'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _PremiumHeader(totalTips: tips.length),
          const SizedBox(height: 16),
          if (tips.isNotEmpty) _BestPickCard(match: tips.first),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Rangliste'),
          const SizedBox(height: 10),
          ...tips.asMap().entries.map(
                (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RankedTipCard(
                rank: entry.key + 1,
                child: MatchCard(match: entry.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  final int totalTips;

  const _PremiumHeader({required this.totalTips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF09233D),
            Color(0xFF064F8C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.blue.withOpacity(0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.blue.withOpacity(0.15),
              border: Border.all(color: AppTheme.blue.withOpacity(0.60)),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppTheme.blue,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium Prognosen',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$totalTips Tipps mit starkem KI-Score gefunden.',
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _BestPickCard extends StatelessWidget {
  final dynamic match;

  const _BestPickCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.blue.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔥 Stärkster Tipp des Tages',
            style: TextStyle(
              color: AppTheme.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          MatchCard(match: match),
        ],
      ),
    );
  }
}

class _RankedTipCard extends StatelessWidget {
  final int rank;
  final Widget child;

  const _RankedTipCard({
    required this.rank,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: child,
        ),
        Positioned(
          top: 14,
          left: 0,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.blue,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.blue.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
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
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}