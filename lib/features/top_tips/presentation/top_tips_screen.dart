import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../matches/data/api/football_api_service.dart';
import '../../matches/presentation/match_card.dart';

class TopTipsScreen extends StatelessWidget {
  const TopTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Top Tipps')),
      body: FutureBuilder(
        future: const FootballApiService().fetchTodayFixtures(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Fehler: ${snapshot.error}'),
            );
          }

          final matches = snapshot.data ?? [];

          final tips = matches
              .where((m) => m.isStrongTip)
              .toList()
            ..sort((a, b) => b.aiScore.compareTo(a.aiScore));

          if (tips.isEmpty) {
            return const Center(
              child: Text('Keine starken Tipps gefunden'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: tips
                .map(
                  (m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MatchCard(match: m),
              ),
            )
                .toList(),
          );
        },
      ),
    );
  }
}