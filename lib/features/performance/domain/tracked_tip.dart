import 'package:kickmind_ai/features/matches/domain/football_match.dart';

enum TipResultStatus {
  pending,
  won,
  lost,
  voided,
}

extension TipResultStatusX on TipResultStatus {
  String get label {
    switch (this) {
      case TipResultStatus.pending:
        return 'Offen';
      case TipResultStatus.won:
        return 'Gewonnen';
      case TipResultStatus.lost:
        return 'Verloren';
      case TipResultStatus.voided:
        return 'Storniert';
    }
  }

  String get storageKey => name;

  static TipResultStatus fromStorage(String? value) {
    return TipResultStatus.values.firstWhere(
          (e) => e.storageKey == value,
      orElse: () => TipResultStatus.pending,
    );
  }
}

class TrackedTip {
  final FootballMatch match;
  final DateTime savedAt;
  final double stake;
  final TipResultStatus status;

  const TrackedTip({
    required this.match,
    required this.savedAt,
    this.stake = 1.0,
    this.status = TipResultStatus.pending,
  });

  double get possibleReturn => stake * match.odds;

  double get profit {
    switch (status) {
      case TipResultStatus.won:
        return possibleReturn - stake;
      case TipResultStatus.lost:
        return -stake;
      case TipResultStatus.voided:
      case TipResultStatus.pending:
        return 0;
    }
  }

  bool get isSettled => status == TipResultStatus.won || status == TipResultStatus.lost;

  TrackedTip copyWith({
    FootballMatch? match,
    DateTime? savedAt,
    double? stake,
    TipResultStatus? status,
  }) {
    return TrackedTip(
      match: match ?? this.match,
      savedAt: savedAt ?? this.savedAt,
      stake: stake ?? this.stake,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'match': match.toJson(),
      'savedAt': savedAt.toIso8601String(),
      'stake': stake,
      'status': status.storageKey,
    };
  }

  factory TrackedTip.fromJson(Map<String, dynamic> json) {
    return TrackedTip(
      match: FootballMatch.fromJson(Map<String, dynamic>.from(json['match'] as Map)),
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now(),
      stake: (json['stake'] as num?)?.toDouble() ?? 1.0,
      status: TipResultStatusX.fromStorage(json['status']?.toString()),
    );
  }
}
