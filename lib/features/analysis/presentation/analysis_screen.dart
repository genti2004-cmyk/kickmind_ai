import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/matches/data/api/football_api_service.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/matches/presentation/match_card.dart';
import 'package:kickmind_ai/features/predictions/domain/prediction_engine.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final FootballApiService _api = FootballApiService();
  final PredictionEngine _engine = const PredictionEngine();
  late Future<List<FootballMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchTodayFixtures();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(title: const Text('Analyse'), backgroundColor: const Color(0xFF0B5EA8), foregroundColor: Colors.white),
      body: FutureBuilder<List<FootballMatch>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final matches = snapshot.data ?? const <FootballMatch>[];
          final top = _engine.rankTopTips(matches, limit: 5);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${matches.length} Spiele analysiert', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              ...top.map((m) => MatchCard(match: m)),
            ],
          );
        },
      ),
    );
  }
}
