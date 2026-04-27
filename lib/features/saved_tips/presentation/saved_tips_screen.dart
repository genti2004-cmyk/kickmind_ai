import 'package:flutter/material.dart';
import '../../matches/domain/football_match.dart';

enum TipResult { open, win, loss }

class SavedTip {
  final FootballMatch match;
  final double stake;
  TipResult result;

  SavedTip({
    required this.match,
    required this.stake,
    this.result = TipResult.open,
  });
}

class SavedTipsScreen extends StatefulWidget {
  const SavedTipsScreen({super.key});

  @override
  State<SavedTipsScreen> createState() => _SavedTipsScreenState();
}

class _SavedTipsScreenState extends State<SavedTipsScreen> {
  final List<SavedTip> _tips = [];

  // 🔥 Beispiel Daten (kannst du später entfernen)
  @override
  void initState() {
    super.initState();

    _tips.addAll([
      SavedTip(
        match: FootballMatch(
          id: '1',
          season: 2026,
          league: 'Bundesliga',
          homeTeam: 'Bayern',
          awayTeam: 'Dortmund',
          kickoff: DateTime.now(),
          kickoffLabel: 'Heute • 20:30',
          tipType: TipType.over25,
          tipLabel: 'Über 2.5',
          aiScore: 82,
          riskLevel: RiskLevel.low,
          odds: 1.7,
          homeFormScore: 80,
          awayFormScore: 70,
          goalsScore: 85,
          shortReason: '',
        ),
        stake: 10,
        result: TipResult.win,
      ),
      SavedTip(
        match: FootballMatch(
          id: '2',
          season: 2026,
          league: 'Bundesliga',
          homeTeam: 'Leipzig',
          awayTeam: 'Mainz',
          kickoff: DateTime.now(),
          kickoffLabel: 'Heute • 18:30',
          tipType: TipType.homeWin,
          tipLabel: 'Heimsieg',
          aiScore: 75,
          riskLevel: RiskLevel.medium,
          odds: 1.9,
          homeFormScore: 75,
          awayFormScore: 65,
          goalsScore: 70,
          shortReason: '',
        ),
        stake: 10,
        result: TipResult.loss,
      ),
    ]);
  }

  // ---------------- STATISTIK ----------------

  int get total => _tips.length;

  int get wins => _tips.where((t) => t.result == TipResult.win).length;

  int get losses => _tips.where((t) => t.result == TipResult.loss).length;

  int get open => _tips.where((t) => t.result == TipResult.open).length;

  double get hitRate {
    if (total == 0) return 0;
    return (wins / total) * 100;
  }

  double get profit {
    double p = 0;

    for (final t in _tips) {
      if (t.result == TipResult.win) {
        p += t.stake * (t.match.odds - 1);
      } else if (t.result == TipResult.loss) {
        p -= t.stake;
      }
    }

    return p;
  }

  double get roi {
    final invested = _tips.fold<double>(0, (sum, t) => sum + t.stake);
    if (invested == 0) return 0;
    return (profit / invested) * 100;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Tipps')),
      body: Column(
        children: [
          _buildStats(),
          Expanded(
            child: ListView.builder(
              itemCount: _tips.length,
              itemBuilder: (_, i) => _buildTipCard(_tips[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _row('Trefferquote', '${hitRate.toStringAsFixed(1)}%'),
          _row('Gewinn', '${profit.toStringAsFixed(2)} €'),
          _row('ROI', '${roi.toStringAsFixed(1)}%'),
          _row('Gewonnen', '$wins'),
          _row('Verloren', '$losses'),
          _row('Offen', '$open'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTipCard(SavedTip tip) {
    Color color;

    switch (tip.result) {
      case TipResult.win:
        color = Colors.green;
        break;
      case TipResult.loss:
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text('${tip.match.homeTeam} vs ${tip.match.awayTeam}'),
        subtitle: Text('${tip.match.tipLabel} • Quote ${tip.match.odds}'),
        trailing: DropdownButton<TipResult>(
          value: tip.result,
          onChanged: (v) {
            setState(() {
              tip.result = v!;
            });
          },
          items: const [
            DropdownMenuItem(value: TipResult.open, child: Text('Offen')),
            DropdownMenuItem(value: TipResult.win, child: Text('Gewonnen')),
            DropdownMenuItem(value: TipResult.loss, child: Text('Verloren')),
          ],
        ),
      ),
    );
  }
}