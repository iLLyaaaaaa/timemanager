import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_storage.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/main.dart';
import 'package:hello_app/models/study_record.dart';
import 'package:hello_app/utils/study_history.dart';
import 'package:hello_app/widgets/study_history_view.dart';

class _MemoryStorage implements StudyPlanStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

StudyRecord _record(String planId, String date, int studiedSeconds) =>
    StudyRecord(
      id: '${date}_$planId',
      planId: planId,
      date: date,
      plannedSeconds: 60,
      studiedSeconds: studiedSeconds,
    );

void main() {
  test('recent week combines plans, fills gaps and keeps overtime', () {
    final summary = StudyHistorySummary.recentWeek(
      lastDay: DateTime(2026, 10, 4, 23),
      records: [
        _record('one', '2026-10-04', 121),
        _record('two', '2026-10-04', 59),
        _record('one', '2026-10-03', 0),
        _record('deleted', '2026-10-01', 30),
        _record('one', '2026-09-28', 1),
        _record('one', '2026-09-27', 600),
        _record('one', '2026-10-05', 600),
      ],
    );

    expect(summary.days.length, 7);
    expect(summary.days.first.date, DateTime(2026, 10, 4));
    expect(summary.days.last.date, DateTime(2026, 9, 28));
    expect(summary.days.map((day) => day.studiedSeconds), [
      180,
      0,
      0,
      30,
      0,
      0,
      1,
    ]);
    expect(summary.totalStudiedSeconds, 211);
    expect(summary.activeDays, 3);
  });

  test('recent week uses calendar dates across years and leap days', () {
    final newYear = StudyHistorySummary.recentWeek(
      records: [],
      lastDay: DateTime(2027, 1, 2),
    );
    expect(newYear.days.last.date, DateTime(2026, 12, 27));
    expect(newYear.activeDays, 0);
    expect(newYear.totalStudiedSeconds, 0);

    final leapYear = StudyHistorySummary.recentWeek(
      records: [_record('one', '2028-02-29', 90)],
      lastDay: DateTime(2028, 3, 1),
    );
    expect(leapYear.days[1].date, DateTime(2028, 2, 29));
    expect(leapYear.days[1].studiedSeconds, 90);
    expect(leapYear.days.last.date, DateTime(2028, 2, 24));
  });

  test('daily reset and reload retain deleted-plan history', () async {
    var now = DateTime(2026, 10, 3, 12);
    final settings = SettingsStore();
    settings.update(settings.settings.copyWith(dailyResetHour: 4));
    final storage = _MemoryStorage();
    final store = await StudyPlanStore.load(
      storage: storage,
      settings: settings,
      now: () => now,
    );
    addTearDown(settings.dispose);
    addTearDown(store.dispose);
    store.addPlan(name: '高等数学', iconId: 'book', plannedSeconds: 120);
    final id = store.plans.single.id;
    store.startOrResume(id);
    store.studySeconds(id, 90);

    now = DateTime(2026, 10, 4, 2);
    store.refreshForToday();
    var summary = StudyHistorySummary.recentWeek(
      records: store.records,
      lastDay: settings.studyDate(now),
    );
    expect(summary.days.first.date, DateTime(2026, 10, 3));
    expect(summary.days.first.studiedSeconds, 90);
    expect(store.plans.single.studiedSeconds, 90);

    now = DateTime(2026, 10, 4, 4);
    store.refreshForToday();
    store.startOrResume(id);
    store.studySeconds(id, 25);
    store.deletePlan(id);
    expect(await store.flush(), isTrue);
    final reopened = await StudyPlanStore.load(
      storage: storage,
      settings: settings,
      now: () => now,
    );
    addTearDown(reopened.dispose);
    summary = StudyHistorySummary.recentWeek(
      records: reopened.records,
      lastDay: settings.studyDate(now),
    );
    expect(reopened.plans, isEmpty);
    expect(summary.days.first.studiedSeconds, 25);
    expect(summary.days[1].studiedSeconds, 90);
    expect(summary.totalStudiedSeconds, 115);
    expect(summary.activeDays, 2);
  });

  testWidgets('history updates from the store and switches back to today', (
    tester,
  ) async {
    final settings = SettingsStore();
    final store = StudyPlanStore(
      settings: settings,
      now: () => DateTime(2026, 10, 4),
    );
    store.addPlan(name: '高等数学', iconId: 'book', plannedSeconds: 120);
    final deletedId = store.plans.single.id;
    store.startOrResume(deletedId);
    store.studySeconds(deletedId, 90);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 120);
    final remainingId = store.plans.last.id;
    store.startOrResume(remainingId);
    store.studySeconds(remainingId, 45);
    store.deletePlan(deletedId);

    await tester.pumpWidget(MyApp(store: store, settings: settings));
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('今日总览'), findsOneWidget);
    await tester.tap(find.text('近 7 天'));
    await tester.pumpAndSettle();
    expect(find.text('近 7 天累计学习'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('history_total'))).data,
      '02:15',
    );
    expect(find.text('7 天中有 1 天学习'), findsOneWidget);

    store.studySeconds(remainingId, 15);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('history_total'))).data,
      '02:30',
    );
    await tester.tap(find.text('今日').first);
    await tester.pumpAndSettle();
    expect(find.text('今日总览'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('高等数学'), findsNothing);

    await tester.tap(find.text('近 7 天'));
    await tester.pumpAndSettle();
    store.clearLearningData();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('history_total'))).data,
      '00:00',
    );
    expect(find.text('还没有学习记录'), findsOneWidget);
    expect(store.plans.single.name, '阅读');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'empty history fits narrow screens and large text in both locales',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final settings = SettingsStore();
      final store = StudyPlanStore(
        settings: settings,
        now: () => DateTime(2026, 10, 4),
      );
      await tester.pumpWidget(MyApp(store: store, settings: settings));
      await tester.tap(find.text('统计'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('近 7 天'));
      await tester.pumpAndSettle();
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      for (final locale in ['zh', 'en']) {
        settings.update(settings.settings.copyWith(localeCode: locale));
        await tester.pumpAndSettle();
        final history = tester.widget<StudyHistoryView>(
          find.byType(StudyHistoryView),
        );
        expect(history.summary.days.length, 7);
        expect(history.summary.totalStudiedSeconds, 0);
        expect(
          find.text(
            locale == 'zh' ? '近 7 天累计学习' : 'Total studied in the last 7 days',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
