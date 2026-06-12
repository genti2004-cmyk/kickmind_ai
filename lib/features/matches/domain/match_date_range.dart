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
        // Ab morgen: Tag +1, +2, +3. Dadurch zeigt „3 Tage“ nicht wieder
        // dieselben heutigen Spiele wie der Heute-Tab.
        return 3;
      case MatchDateRange.next7Days:
        // Ab morgen: nächste echte 7 Tage ohne Heute-Duplikate.
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
        return today.add(const Duration(days: 1));
      case MatchDateRange.next7Days:
        return today.add(const Duration(days: 1));
    }
  }

  String rangeLabel(DateTime now) {
    final start = startDate(now);
    final end = start.add(Duration(days: durationDays - 1));
    if (durationDays <= 1) return _formatDate(start);
    return '${_formatDate(start)} – ${_formatDate(end)}';
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
}
