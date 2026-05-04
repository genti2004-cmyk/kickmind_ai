enum TipType {
  homeWin,
  draw,
  awayWin,
  over25,
  under25,
  btts,
}

class FootballMatch {
  final String id;
  final int? fixtureId;
  final int season;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final DateTime kickoff;
  final String kickoffLabel;
  final TipType tipType;
  final String tipLabel;
  final int aiScore;
  final String riskLevel;
  final double odds;
  final int homeFormScore;
  final int awayFormScore;
  final int goalsScore;
  final String shortReason;

  final String? tip;


  const FootballMatch({
    required this.id,
    this.fixtureId,
    required this.season,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoff,
    required this.kickoffLabel,
    required this.tipType,
    required this.tipLabel,
    required this.aiScore,
    required this.riskLevel,
    required this.odds,
    required this.homeFormScore,
    required this.awayFormScore,
    required this.goalsScore,
    required this.shortReason,
    this.tip,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fixtureId': fixtureId,
      'season': season,
      'league': league,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'kickoff': kickoff.toIso8601String(),
      'kickoffLabel': kickoffLabel,
      'tipType': tipType.name,
      'tipLabel': tipLabel,
      'aiScore': aiScore,
      'riskLevel': riskLevel,
      'odds': odds,
      'homeFormScore': homeFormScore,
      'awayFormScore': awayFormScore,
      'goalsScore': goalsScore,
      'shortReason': shortReason,
    };
  }

  factory FootballMatch.fromJson(Map<String, dynamic> json) {
    final rawTipType = json['tipType']?.toString() ?? 'homeWin';

    return FootballMatch(
      id: json['id']?.toString() ?? '',
      fixtureId: int.tryParse(json['fixtureId']?.toString() ?? ''),
      season: int.tryParse(json['season']?.toString() ?? '') ?? DateTime.now().year,
      league: json['league']?.toString() ?? 'Soccer',
      homeTeam: json['homeTeam']?.toString() ?? '',
      awayTeam: json['awayTeam']?.toString() ?? '',
      kickoff: DateTime.tryParse(json['kickoff']?.toString() ?? '') ?? DateTime.now(),
      kickoffLabel: json['kickoffLabel']?.toString() ?? '',
      tipType: TipType.values.firstWhere(
            (e) => e.name == rawTipType,
        orElse: () => TipType.homeWin,
      ),
      tipLabel: json['tipLabel']?.toString() ?? '1',
      aiScore: int.tryParse(json['aiScore']?.toString() ?? '') ?? 0,
      riskLevel: json['riskLevel']?.toString() ?? 'Mittel',
      odds: (json['odds'] as num?)?.toDouble() ?? double.tryParse(json['odds']?.toString() ?? '') ?? 1.0,
      homeFormScore: int.tryParse(json['homeFormScore']?.toString() ?? '') ?? 50,
      awayFormScore: int.tryParse(json['awayFormScore']?.toString() ?? '') ?? 50,
      goalsScore: int.tryParse(json['goalsScore']?.toString() ?? '') ?? 50,
      shortReason: json['shortReason']?.toString() ?? '',
    );
  }

  bool get isStrongTip => aiScore >= 72 && riskLevel.toLowerCase() != 'hoch' && riskLevel.toLowerCase() != 'high';

  String get riskLabel => riskLevel;

  String get riskEmoji {
    switch (riskLevel.toLowerCase()) {
      case 'niedrig':
      case 'low':
        return '🟢';
      case 'mittel':
      case 'medium':
        return '🟡';
      default:
        return '🔴';
    }
  }

  String get teamsLabel => '$homeTeam vs $awayTeam';

  FootballMatch copyWith({
    String? id,
    int? fixtureId,
    int? season,
    String? league,
    String? homeTeam,
    String? awayTeam,
    DateTime? kickoff,
    String? kickoffLabel,
    TipType? tipType,
    String? tipLabel,
    int? aiScore,
    String? riskLevel,
    double? odds,
    int? homeFormScore,
    int? awayFormScore,
    int? goalsScore,
    String? shortReason,
  }) {
    return FootballMatch(
      id: id ?? this.id,
      fixtureId: fixtureId ?? this.fixtureId,
      season: season ?? this.season,
      league: league ?? this.league,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      kickoff: kickoff ?? this.kickoff,
      kickoffLabel: kickoffLabel ?? this.kickoffLabel,
      tipType: tipType ?? this.tipType,
      tipLabel: tipLabel ?? this.tipLabel,
      aiScore: aiScore ?? this.aiScore,
      riskLevel: riskLevel ?? this.riskLevel,
      odds: odds ?? this.odds,
      homeFormScore: homeFormScore ?? this.homeFormScore,
      awayFormScore: awayFormScore ?? this.awayFormScore,
      goalsScore: goalsScore ?? this.goalsScore,
      shortReason: shortReason ?? this.shortReason,
    );
  }
}
