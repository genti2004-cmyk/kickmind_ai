import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../matches/data/api/football_api_service.dart';
import '../../matches/presentation/match_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Heute')),
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

          final topTips = matches.where((m) => m.isStrongTip).toList();
          final lowRisk = matches.where((m) => m.riskLabel == 'Niedrig').length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Spiele',
                      value: '${matches.length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'Top Tipps',
                      value: '${topTips.length}', // 🔥 HIER
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'Niedrig',
                      value: '$lowRisk',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...matches.map(
                    (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MatchCard(match: m),
                ),
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}