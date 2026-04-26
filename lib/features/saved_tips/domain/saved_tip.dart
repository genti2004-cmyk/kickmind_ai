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
  });

  double get payout => stake * odds;
  double get profit => payout - stake;

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
    );
  }
}