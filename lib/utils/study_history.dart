import '../models/study_record.dart';

class StudyHistoryDay {
  const StudyHistoryDay({required this.date, required this.studiedSeconds});

  final DateTime date;
  final int studiedSeconds;
}

// UTC is used only as a calendar-date coordinate, never to reinterpret records.
// This keeps date offsets and inclusive day counts independent of DST.
DateTime studyCalendarDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

DateTime offsetStudyDay(DateTime date, int days) =>
    DateTime.utc(date.year, date.month, date.day + days);

String studyDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int studyHeatLevel(int seconds) => switch (seconds) {
  <= 0 => 0,
  <= 900 => 1,
  <= 1800 => 2,
  <= 3600 => 3,
  _ => 4,
};

class StudyRangeSummary {
  StudyRangeSummary({
    required this.startDay,
    required this.endDay,
    required this.totalStudiedSeconds,
    required this.activeDays,
    required this.longestStudyDay,
    Map<String, int> planSeconds = const {},
    Iterable<StudyHistoryDay> studiedDays = const [],
  }) : planSeconds = Map.unmodifiable(planSeconds),
       studiedDays = List.unmodifiable(studiedDays);

  final DateTime startDay;
  final DateTime endDay;
  final int totalStudiedSeconds;
  final int activeDays;
  final StudyHistoryDay? longestStudyDay;
  final Map<String, int> planSeconds;
  // Only positive days, in descending date order; no zero-day expansion.
  final List<StudyHistoryDay> studiedDays;

  int get dayCount => endDay.difference(startDay).inDays + 1;
  int get averageDailySeconds => totalStudiedSeconds ~/ dayCount;

  DateTime dayAt(int descendingIndex) {
    RangeError.checkValueInInterval(
      descendingIndex,
      0,
      dayCount - 1,
      'descendingIndex',
    );
    return offsetStudyDay(endDay, -descendingIndex);
  }
}

class StudyPeriodComparison {
  const StudyPeriodComparison({required this.current, required this.previous});

  final StudyRangeSummary current;
  final StudyRangeSummary previous;

  int get secondsChange =>
      current.totalStudiedSeconds - previous.totalStudiedSeconds;

  // A zero baseline has no meaningful percentage change.
  double? get relativeChange => previous.totalStudiedSeconds == 0
      ? null
      : secondsChange / previous.totalStudiedSeconds;
}

/// Read-only history projection. Invalid/future dates never affect review
/// metrics; the source records themselves are retained without alteration.
class StudyHistoryIndex {
  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  StudyHistoryIndex({
    required Iterable<StudyRecord> records,
    required DateTime lastDay,
  }) : lastDay = studyCalendarDate(lastDay) {
    for (final record in records) {
      final date = _parseDate(record.date);
      if (date == null ||
          date.isAfter(this.lastDay) ||
          record.studiedSeconds < 0) {
        continue;
      }
      _totals.update(
        date,
        (value) => value + record.studiedSeconds,
        ifAbsent: () => record.studiedSeconds,
      );
      final plans = _planTotals.putIfAbsent(date, () => <String, int>{});
      plans.update(
        record.planId,
        (value) => value + record.studiedSeconds,
        ifAbsent: () => record.studiedSeconds,
      );
    }
    _dates = _totals.keys.toList()..sort();
    _activeDates = _dates.where((date) => _totals[date]! > 0).toList();
  }

  final DateTime lastDay;
  final _totals = <DateTime, int>{};
  final _planTotals = <DateTime, Map<String, int>>{};
  late final List<DateTime> _dates;
  late final List<DateTime> _activeDates;

  DateTime? get earliestDay => _dates.firstOrNull;
  DateTime? get latestDay => _dates.lastOrNull;
  bool get hasStudyHistory => _activeDates.isNotEmpty;
  bool get hasStudiedToday => studiedSecondsOn(lastDay) > 0;

  int studiedSecondsOn(DateTime day) => _totals[studyCalendarDate(day)] ?? 0;

  Map<String, int> planSecondsOn(DateTime day) => Map.unmodifiable(
    _planTotals[studyCalendarDate(day)] ?? const <String, int>{},
  );

  int get currentStreakDays {
    var day = hasStudiedToday ? lastDay : offsetStudyDay(lastDay, -1);
    var count = 0;
    while (studiedSecondsOn(day) > 0) {
      count++;
      day = offsetStudyDay(day, -1);
    }
    return count;
  }

  int get longestStreakDays {
    var longest = 0;
    var streak = 0;
    DateTime? previous;
    for (final date in _activeDates) {
      streak = previous != null && date.difference(previous).inDays == 1
          ? streak + 1
          : 1;
      if (streak > longest) longest = streak;
      previous = date;
    }
    return longest;
  }

  StudyRangeSummary summarize({
    required DateTime startDay,
    required DateTime endDay,
  }) {
    final start = studyCalendarDate(startDay);
    final end = studyCalendarDate(endDay);
    if (start.isAfter(end) || end.isAfter(lastDay)) {
      throw ArgumentError(
        'Review ranges must end on or before the current study day',
      );
    }
    var seconds = 0;
    var active = 0;
    StudyHistoryDay? best;
    final planSeconds = <String, int>{};
    final studiedDays = <StudyHistoryDay>[];
    for (final date in _dates) {
      if (date.isBefore(start) || date.isAfter(end)) continue;
      final total = _totals[date]!;
      seconds += total;
      if (total > 0) {
        active++;
        studiedDays.add(StudyHistoryDay(date: date, studiedSeconds: total));
      }
      for (final entry in _planTotals[date]!.entries) {
        planSeconds.update(
          entry.key,
          (seconds) => seconds + entry.value,
          ifAbsent: () => entry.value,
        );
      }
      // Dates are ascending, so equality selects the most recent best day.
      if (total > 0 && total >= (best?.studiedSeconds ?? 0)) {
        best = StudyHistoryDay(date: date, studiedSeconds: total);
      }
    }
    return StudyRangeSummary(
      startDay: start,
      endDay: end,
      totalStudiedSeconds: seconds,
      activeDays: active,
      longestStudyDay: best,
      planSeconds: planSeconds,
      studiedDays: studiedDays.reversed,
    );
  }

  StudyPeriodComparison? comparePreviousPeriod(StudyRangeSummary current) {
    final previousStart = offsetStudyDay(current.startDay, -current.dayCount);
    if (previousStart.year < 1) return null;
    return StudyPeriodComparison(
      current: current,
      previous: summarize(
        startDay: previousStart,
        endDay: offsetStudyDay(current.startDay, -1),
      ),
    );
  }

  static DateTime? _parseDate(String value) {
    if (!_datePattern.hasMatch(value)) return null;
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime.utc(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }
}

class StudyHistorySummary {
  StudyHistorySummary.recentWeek({
    required Iterable<StudyRecord> records,
    required DateTime lastDay,
  }) {
    final totals = <String, int>{};
    for (final record in records) {
      totals.update(
        record.date,
        (seconds) => seconds + record.studiedSeconds,
        ifAbsent: () => record.studiedSeconds,
      );
    }
    days = List.unmodifiable([
      for (var offset = 0; offset < 7; offset++)
        _day(
          DateTime(lastDay.year, lastDay.month, lastDay.day - offset),
          totals,
        ),
    ]);
  }

  // Calendar dates keep the seven-day window correct across month/year changes.
  // Records are included even when their associated plan has been deleted.
  late final List<StudyHistoryDay> days;

  int get totalStudiedSeconds =>
      days.fold(0, (total, day) => total + day.studiedSeconds);

  int get activeDays => days.where((day) => day.studiedSeconds > 0).length;

  int get averageDailySeconds => totalStudiedSeconds ~/ days.length;

  // A tie keeps the most recent date. Empty weeks have no best day.
  StudyHistoryDay? get longestStudyDay {
    StudyHistoryDay? longest;
    for (final day in days) {
      if (day.studiedSeconds > (longest?.studiedSeconds ?? 0)) longest = day;
    }
    return longest;
  }

  static StudyHistoryDay _day(DateTime date, Map<String, int> totals) {
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return StudyHistoryDay(date: date, studiedSeconds: totals[key] ?? 0);
  }
}
