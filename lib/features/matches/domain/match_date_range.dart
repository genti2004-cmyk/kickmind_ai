enum MatchDateRange {
  today,
  tomorrow,
  next3Days,
  next7Days,
}

extension MatchDateRangeX on MatchDateRange {
  String get label {
    switch (this) {
      case MatchDateRange.today:
        return 'Heute';
      case MatchDateRange.tomorrow:
        return 'Morgen';
      case MatchDateRange.next3Days:
        return '3 Tage';
      case MatchDateRange.next7Days:
        return 'Woche';
    }
  }

  int get durationDays {
    switch (this) {
      case MatchDateRange.today:
        return 1;
      case MatchDateRange.tomorrow:
        return 1;
      case MatchDateRange.next3Days:
        return 3;
      case MatchDateRange.next7Days:
        return 7;
    }
  }

  DateTime startDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case MatchDateRange.today:
        return today;
      case MatchDateRange.tomorrow:
        return today.add(const Duration(days: 1));
      case MatchDateRange.next3Days:
        return today;
      case MatchDateRange.next7Days:
        return today;
    }
  }
}
