enum TipResult {
  open,
  won,
  lost,
}

class SavedTip {
  final String id;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final String tipLabel;
  final int aiScore;
  final double odds;
  final double stake;
  final DateTime savedAt;
  final TipResult result;

  const SavedTip({
    required this.id,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    required this.tipLabel,
    required this.aiScore,
    required this.odds,
    required this.stake,
    required this.savedAt,
    this.result = TipResult.open,
  });

  double get payout => stake * odds;

  double get profit {
    switch (result) {
      case TipResult.won:
        return payout - stake;
      case TipResult.lost:
        return -stake;
      case TipResult.open:
        return 0;
    }
  }

  String get resultLabel {
    switch (result) {
      case TipResult.open:
        return 'Offen';
      case TipResult.won:
        return 'Gewonnen';
      case TipResult.lost:
        return 'Verloren';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league': league,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'tipLabel': tipLabel,
      'aiScore': aiScore,
      'odds': odds,
      'stake': stake,
      'savedAt': savedAt.toIso8601String(),
      'result': result.name,
    };
  }

  factory SavedTip.fromJson(Map<String, dynamic> json) {
    return SavedTip(
      id: json['id']?.toString() ?? '',
      league: json['league']?.toString() ?? '',
      homeTeam: json['homeTeam']?.toString() ?? '',
      awayTeam: json['awayTeam']?.toString() ?? '',
      tipLabel: json['tipLabel']?.toString() ?? '',
      aiScore: int.tryParse(json['aiScore']?.toString() ?? '') ?? 0,
      odds: double.tryParse(json['odds']?.toString() ?? '') ?? 1.0,
      stake: double.tryParse(json['stake']?.toString() ?? '') ?? 0.0,
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now(),
      result: TipResult.values.firstWhere(
            (e) => e.name == json['result']?.toString(),
        orElse: () => TipResult.open,
      ),
    );
  }

  SavedTip copyWith({
    TipResult? result,
  }) {
    return SavedTip(
      id: id,
      league: league,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      tipLabel: tipLabel,
      aiScore: aiScore,
      odds: odds,
      stake: stake,
      savedAt: savedAt,
      result: result ?? this.result,
    );
  }
}