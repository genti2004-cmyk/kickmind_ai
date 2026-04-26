import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../matches/data/mock_matches_repository.dart';
import '../../matches/presentation/match_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final matches = const MockMatchesRepository().getTodayMatches();
    final topTips = matches.where((m) => m.isTopTip).length;
    final lowRisk = matches.where((m) => m.riskLabel == 'Niedrig').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Heute'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _TodayDashboardCard(
            totalMatches: matches.length,
            topTips: topTips,
            lowRisk: lowRisk,
          ),
          const SizedBox(height: 14),
          const _QuickFilterRow(),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Alle Spiele heute'),
          const SizedBox(height: 10),
          ...matches.map(
                (match) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MatchCard(match: match),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayDashboardCard extends StatelessWidget {
  final int totalMatches;
  final int topTips;
  final int lowRisk;

  const _TodayDashboardCard({
    required this.totalMatches,
    required this.topTips,
    required this.lowRisk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF063A68),
            Color(0xFF0B1B2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          const Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: AppTheme.blue, size: 34),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'KickMind Tagescheck',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Alle heutigen Spiele werden nach Score, Risiko und Tipp-Art bewertet.',
            style: TextStyle(
              color: AppTheme.mutedText,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatBox(label: 'Spiele', value: '$totalMatches'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(label: 'Top Tipps', value: '$topTips'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(label: 'Niedrig', value: '$lowRisk'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFilterRow extends StatelessWidget {
  const _QuickFilterRow();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickChip(icon: Icons.calendar_today_rounded, label: 'Heute'),
          SizedBox(width: 8),
          _QuickChip(icon: Icons.star_rounded, label: 'Top Score'),
          SizedBox(width: 8),
          _QuickChip(icon: Icons.security_rounded, label: 'Niedriges Risiko'),
          SizedBox(width: 8),
          _QuickChip(icon: Icons.sports_score_rounded, label: 'Torwetten'),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.blue, size: 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

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