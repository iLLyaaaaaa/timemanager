import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_storage.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/models/study_record.dart';
import 'package:hello_app/utils/study_history.dart';

StudyRecord _record(String date, int seconds, [String plan = 'one']) =>
    StudyRecord(
      id: '${date}_$plan',
      planId: plan,
      date: date,
      plannedSeconds: 60,
      studiedSeconds: seconds,
    );

class _Storage implements StudyPlanStorage {
  String? value;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
    writes++;
  }
}

void main() {
  test('range plan totals and positive days are aggregated and read-only', () {
    final history = StudyHistoryIndex(
      lastDay: DateTime(2028, 3, 1),
      records: [
        _record('2028-02-28', 10),
        _record('2028-02-28', 5, 'two'),
        _record('2028-02-29', 20),
        _record('2028-02-29', 0, 'zero'),
        _record('2028-03-01', 0),
        _record('2028-03-02', 999, 'future'),
        _record('bad', 999, 'invalid'),
      ],
    );
    final summary = history.summarize(
      startDay: DateTime(2028, 2, 28),
      endDay: DateTime(2028, 3, 1),
    );
    expect(summary.planSeconds, {'one': 30, 'two': 5, 'zero': 0});
    expect(summary.studiedDays.map((day) => day.date), [
      DateTime.utc(2028, 2, 29),
      DateTime.utc(2028, 2, 28),
    ]);
    expect(summary.studiedDays.map((day) => day.studiedSeconds), [20, 15]);
    expect(() => summary.planSeconds['one'] = 5, throwsUnsupportedError);
    expect(() => summary.studiedDays.clear(), throwsUnsupportedError);
  });

  test('previous period has the same calendar length across leap day', () {
    final history = StudyHistoryIndex(
      lastDay: DateTime(2028, 3, 2),
      records: [
        _record('2028-02-27', 999),
        _record('2028-02-28', 60),
        _record('2028-02-29', 60),
        _record('2028-03-01', 90),
        _record('2028-03-02', 90),
      ],
    );
    final current = history.summarize(
      startDay: DateTime(2028, 3, 1),
      endDay: DateTime(2028, 3, 2),
    );
    final comparison = history.comparePreviousPeriod(current)!;
    expect(comparison.previous.startDay, DateTime.utc(2028, 2, 28));
    expect(comparison.previous.endDay, DateTime.utc(2028, 2, 29));
    expect(comparison.previous.dayCount, current.dayCount);
    expect(comparison.previous.totalStudiedSeconds, 120);
    expect(comparison.secondsChange, 60);
    expect(comparison.relativeChange, 0.5);
  });

  test(
    'comparison crosses the year and handles zero baselines and decreases',
    () {
      final history = StudyHistoryIndex(
        lastDay: DateTime(2028, 1, 2),
        records: [_record('2027-12-31', 60), _record('2028-01-01', 30)],
      );
      StudyPeriodComparison compare(DateTime date) =>
          history.comparePreviousPeriod(
            history.summarize(startDay: date, endDay: date),
          )!;
      final decreased = compare(DateTime(2028, 1, 1));
      expect(decreased.previous.endDay, DateTime.utc(2027, 12, 31));
      expect(decreased.secondsChange, -30);
      expect(decreased.relativeChange, -0.5);
      expect(compare(DateTime(2028, 1, 2)).relativeChange, -1);
      final started = compare(DateTime(2027, 12, 31));
      expect(started.secondsChange, 60);
      expect(started.relativeChange, isNull);
      final empty = compare(DateTime(2027, 12, 29));
      expect(empty.secondsChange, 0);
      expect(empty.relativeChange, isNull);
    },
  );

  test(
    'comparison does not construct a range before supported calendar dates',
    () {
      final history = StudyHistoryIndex(
        records: [],
        lastDay: DateTime(1, 1, 1),
      );
      expect(
        history.comparePreviousPeriod(
          history.summarize(
            startDay: DateTime(1, 1, 1),
            endDay: DateTime(1, 1, 1),
          ),
        ),
        isNull,
      );
    },
  );

  test('streak continues from yesterday until the current study day ends', () {
    final records = [
      _record('2026-09-30', 10),
      _record('2026-10-01', 1),
      _record('2026-10-02', 30),
      _record('2026-10-03', 0),
    ];
    var history = StudyHistoryIndex(
      records: records,
      lastDay: DateTime(2026, 10, 3),
    );
    expect(history.hasStudiedToday, isFalse);
    expect(history.currentStreakDays, 3);
    expect(history.longestStreakDays, 3);
    records.add(_record('2026-10-03', 1, 'two'));
    history = StudyHistoryIndex(
      records: records,
      lastDay: DateTime(2026, 10, 3),
    );
    expect(history.hasStudiedToday, isTrue);
    expect(history.currentStreakDays, 4);
    history = StudyHistoryIndex(
      records: records,
      lastDay: DateTime(2026, 10, 5),
    );
    expect(history.currentStreakDays, 0);
    expect(history.longestStreakDays, 4);
  });

  test(
    'longest streak includes all history and crosses leap/year boundaries',
    () {
      final history = StudyHistoryIndex(
        lastDay: DateTime(2028, 3, 2),
        records: [
          _record('2027-12-30', 1),
          _record('2027-12-31', 1),
          _record('2028-01-01', 1),
          _record('2028-01-02', 1),
          _record('2028-02-28', 1),
          _record('2028-02-29', 1),
          _record('2028-03-01', 1),
          _record('2028-03-02', 0),
        ],
      );
      expect(history.currentStreakDays, 3);
      expect(history.longestStreakDays, 4);
      expect(history.earliestDay, DateTime.utc(2027, 12, 30));
    },
  );

  test(
    'range includes both endpoints, zero days and the newest tied best day',
    () {
      final history = StudyHistoryIndex(
        lastDay: DateTime(2028, 3, 2),
        records: [
          _record('2028-02-27', 1000),
          _record('2028-02-28', 60),
          _record('2028-02-28', 30, 'two'),
          _record('2028-03-01', 90),
          _record('2028-03-02', 1000),
        ],
      );
      final summary = history.summarize(
        startDay: DateTime(2028, 2, 28, 12),
        endDay: DateTime(2028, 3, 1, 22),
      );
      expect(summary.totalStudiedSeconds, 180);
      expect(summary.activeDays, 2);
      expect(summary.dayCount, 3);
      expect(summary.averageDailySeconds, 60);
      expect(summary.longestStudyDay?.date, DateTime.utc(2028, 3, 1));
      expect(summary.dayAt(0), DateTime.utc(2028, 3, 1));
      expect(summary.dayAt(1), DateTime.utc(2028, 2, 29));
      expect(summary.dayAt(2), DateTime.utc(2028, 2, 28));
      expect(() => summary.dayAt(3), throwsRangeError);
      expect(() => summary.dayAt(-1), throwsRangeError);
      expect(history.planSecondsOn(DateTime(2028, 2, 28)), {
        'one': 60,
        'two': 30,
      });
      expect(
        () => history.planSecondsOn(DateTime(2028, 2, 28))['one'] = 9,
        throwsUnsupportedError,
      );
    },
  );

  test('empty and zero-only history have no active streak or best day', () {
    for (final records in [
      <StudyRecord>[],
      [_record('2026-10-03', 0)],
    ]) {
      final history = StudyHistoryIndex(
        records: records,
        lastDay: DateTime(2026, 10, 4),
      );
      final summary = history.summarize(
        startDay: DateTime(2026, 9, 5),
        endDay: DateTime(2026, 10, 4),
      );
      expect(history.currentStreakDays, 0);
      expect(history.longestStreakDays, 0);
      expect(history.hasStudyHistory, isFalse);
      expect(summary.dayCount, 30);
      expect(summary.averageDailySeconds, 0);
      expect(summary.longestStudyDay, isNull);
    }
  });

  test(
    'invalid dates and future records are excluded without changing input',
    () {
      final records = [
        _record('bad', 9000),
        _record('2026-02-29', 9000),
        _record('2026-04-31', 9000),
        _record('2026-00-01', 9000),
        _record('2026-13-01', 9000),
        _record('0000-01-01', 9000),
        _record('2026-1-01', 9000),
        _record('2026-10-05', 9000),
        _record('2026-10-04', 1),
      ];
      final snapshot = jsonEncode(
        records.map((record) => record.toJson()).toList(),
      );
      final history = StudyHistoryIndex(
        records: records,
        lastDay: DateTime(2026, 10, 4),
      );
      expect(history.earliestDay, DateTime.utc(2026, 10, 4));
      expect(history.longestStreakDays, 1);
      expect(
        history
            .summarize(
              startDay: DateTime(2026, 1, 1),
              endDay: DateTime(2026, 10, 4),
            )
            .totalStudiedSeconds,
        1,
      );
      expect(
        jsonEncode(records.map((record) => record.toJson()).toList()),
        snapshot,
      );
      expect(
        () => history.summarize(
          startDay: DateTime(2026, 10, 4),
          endDay: DateTime(2026, 10, 5),
        ),
        throwsArgumentError,
      );
      expect(
        () => history.summarize(
          startDay: DateTime(2026, 10, 4),
          endDay: DateTime(2026, 10, 3),
        ),
        throwsArgumentError,
      );
    },
  );

  test('fixed heat levels retain second-level boundary accuracy', () {
    expect([0, 1, 900, 901, 1800, 1801, 3600, 3601].map(studyHeatLevel), [
      0,
      1,
      1,
      2,
      2,
      3,
      3,
      4,
    ]);
  });

  test(
    'reset, deletion and reload preserve actual history and snapshot format',
    () async {
      var now = DateTime(2026, 10, 3, 12);
      final settings = SettingsStore();
      settings.update(settings.settings.copyWith(dailyResetHour: 4));
      final storage = _Storage();
      final store = await StudyPlanStore.load(
        storage: storage,
        settings: settings,
        now: () => now,
      );
      addTearDown(settings.dispose);
      addTearDown(store.dispose);
      final plan = store.addPlan(
        name: '阅读',
        iconId: 'book',
        plannedSeconds: 90,
      );
      store.startOrResume(plan.id);
      store.studySeconds(plan.id, 45);
      now = DateTime(2026, 10, 4, 2);
      var history = StudyHistoryIndex(
        records: store.records,
        lastDay: settings.studyDate(now),
      );
      expect(history.lastDay, DateTime.utc(2026, 10, 3));
      expect(history.hasStudiedToday, isTrue);
      now = DateTime(2026, 10, 4, 4);
      store.refreshForToday();
      store.startOrResume(plan.id);
      store.studySeconds(plan.id, 30);
      store.deletePlan(plan.id);
      await store.flush();
      final writes = storage.writes;
      history = StudyHistoryIndex(
        records: store.records,
        lastDay: settings.studyDate(now),
      );
      expect(history.currentStreakDays, 2);
      expect(
        history
            .summarize(
              startDay: DateTime(2026, 10, 3),
              endDay: DateTime(2026, 10, 4),
            )
            .totalStudiedSeconds,
        75,
      );
      expect(storage.writes, writes);
      expect(jsonDecode(storage.value!)['version'], 5);
      expect(settings.settings.toJson()['version'], 4);
      final reopened = await StudyPlanStore.load(
        storage: storage,
        settings: settings,
        now: () => now,
      );
      addTearDown(reopened.dispose);
      expect(
        StudyHistoryIndex(
          records: reopened.records,
          lastDay: settings.studyDate(now),
        ).longestStreakDays,
        2,
      );
      reopened.clearLearningData();
      history = StudyHistoryIndex(
        records: reopened.records,
        lastDay: settings.studyDate(now),
      );
      expect(history.currentStreakDays, 0);
      expect(history.longestStreakDays, 0);
    },
  );
}
