import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../matches/data/api/football_api_service.dart';
import '../../matches/domain/football_match.dart';
import '../../matches/presentation/match_card.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Analyse'),
      ),
      body: FutureBuilder<List<FootballMatch>>(
        future: const FootballApiService().fetchTodayFixtures(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Fehler: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.text),
                textAlign: TextAlign.center,
              ),
            );
          }

          final List<FootballMatch> matches = snapshot.data ?? <FootballMatch>[];

          if (matches.isEmpty) {
            return const Center(
              child: Text(
                'Keine Analyse-Daten gefunden',
                style: TextStyle(color: AppTheme.text),
              ),
            );
          }

          final int avgScore =
              matches.map((m) => m.aiScore).reduce((a, b) => a + b) ~/
                  matches.length;

          final List<FootballMatch> sortedMatches = [...matches]
            ..sort((a, b) => b.aiScore.compareTo(a.aiScore));

          final FootballMatch topMatch = sortedMatches.first;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _AnalysisHeader(avgScore: avgScore),
              const SizedBox(height: 16),
              const _SectionTitle(title: 'Stärkstes Spiel'),
              const SizedBox(height: 10),
              MatchCard(match: topMatch),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Analyse Übersicht'),
              const SizedBox(height: 10),
              ...sortedMatches.take(5).map(
                    (match) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MatchCard(match: match),
                ),
              ),
            ],
          );
        },
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
              '$avgScore%',
              style: const TextStyle(
                color: AppTheme.blue,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Durchschnittlicher KickMind-Score aller heutigen Live-Spiele.',
              style: TextStyle(
                color: AppTheme.text,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
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