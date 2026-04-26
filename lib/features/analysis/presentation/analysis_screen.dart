import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../matches/data/mock_matches_repository.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final matches = const MockMatchesRepository().getTodayMatches();

    final avgScore =
        matches.map((m) => m.aiScore).reduce((a, b) => a + b) ~/ matches.length;
    final topMatch = [...matches]..sort((a, b) => b.aiScore.compareTo(a.aiScore));
    final lowRiskCount = matches.where((m) => m.riskLabel == 'Niedrig').length;
    final mediumRiskCount = matches.where((m) => m.riskLabel == 'Mittel').length;
    final highRiskCount = matches.where((m) => m.riskLabel == 'Hoch').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Analyse'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _AnalysisHeader(avgScore: avgScore),
          const SizedBox(height: 16),
          _TopMatchInsight(match: topMatch.first),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Risiko-Auswertung'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _RiskBox(label: 'Niedrig', value: lowRiskCount)),
              const SizedBox(width: 10),
              Expanded(child: _RiskBox(label: 'Mittel', value: mediumRiskCount)),
              const SizedBox(width: 10),
              Expanded(child: _RiskBox(label: 'Hoch', value: highRiskCount)),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Analysewerte'),
          const SizedBox(height: 10),
          ...matches.take(3).map(
                (match) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AnalysisMatchCard(match: match),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisHeader extends StatelessWidget {
  final int avgScore;

  const _AnalysisHeader({required this.avgScore});

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
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.blue.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
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
              '$avgScore%',
              style: const TextStyle(
                color: AppTheme.blue,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tagesanalyse',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Durchschnittlicher KickMind-Score aller heutigen Spiele.',
                  style: TextStyle(
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

class _TopMatchInsight extends StatelessWidget {
  final dynamic match;

  const _TopMatchInsight({required this.match});

  @override
  Widget build(BuildContext context) {
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
            'Stärkstes Analyse-Spiel',
            style: TextStyle(
              color: AppTheme.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${match.homeTeam} vs ${match.awayTeam}',
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${match.tipLabel} · ${match.aiScore}% · Risiko ${match.riskLabel}',
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            match.shortReason,
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisMatchCard extends StatelessWidget {
  final dynamic match;

  const _AnalysisMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.blue.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${match.homeTeam} vs ${match.awayTeam}',
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _MiniBar(label: 'Heimform', value: match.homeFormScore),
          const SizedBox(height: 8),
          _MiniBar(label: 'Auswärtsform', value: match.awayFormScore),
          const SizedBox(height: 8),
          _MiniBar(label: 'Tortrend', value: match.goalsScore),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final int value;

  const _MiniBar({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0, 100) / 100;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$value%',
              style: const TextStyle(
                color: AppTheme.blue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: progress,
          minHeight: 7,
          borderRadius: BorderRadius.circular(999),
          backgroundColor: AppTheme.card,
          color: AppTheme.blue,
        ),
      ],
    );
  }
}

class _RiskBox extends StatelessWidget {
  final String label;
  final int value;

  const _RiskBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.blue.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
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