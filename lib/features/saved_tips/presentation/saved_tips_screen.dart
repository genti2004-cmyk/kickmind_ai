import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/matches/domain/football_match.dart';
import 'package:kickmind_ai/features/saved_tips/data/saved_tips_service.dart';

class SavedTipsScreen extends StatefulWidget {
  const SavedTipsScreen({super.key});

  @override
  State<SavedTipsScreen> createState() => _SavedTipsScreenState();
}

class _SavedTipsScreenState extends State<SavedTipsScreen> {
  final SavedTipsService _service = SavedTipsService();
  late Future<List<FootballMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.loadSavedTips();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.loadSavedTips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Tipps'),
      ),
      body: FutureBuilder<List<FootballMatch>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tips = snapshot.data ?? [];

          if (tips.isEmpty) {
            return const Center(
              child: Text('Keine gespeicherten Tipps'),
            );
          }

          return ListView.builder(
            itemCount: tips.length,
            itemBuilder: (context, index) {
              final match = tips[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('${match.homeTeam} vs ${match.awayTeam}'),
                  subtitle: Text(
                    '${match.league} • ${match.tipLabel} • ${match.riskEmoji} ${match.riskLevel} • AI ${match.aiScore}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await _service.removeTip(match.id);
                      _reload();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}