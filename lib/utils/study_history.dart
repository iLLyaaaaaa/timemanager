import '../models/study_record.dart';

class StudyHistoryDay {
  const StudyHistoryDay({required this.date, required this.studiedSeconds});

  final DateTime date;
  final int studiedSeconds;
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

  static StudyHistoryDay _day(DateTime date, Map<String, int> totals) {
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return StudyHistoryDay(date: date, studiedSeconds: totals[key] ?? 0);
  }
}
