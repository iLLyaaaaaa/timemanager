import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/study_plan_storage.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_statistics_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';
import 'package:hello_app/utils/study_duration.dart';

class _MemoryStorage implements StudyPlanStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String snapshot) async {
    value = snapshot;
  }
}

void main() {
  final today = DateTime(2026, 9, 28);

  test('duration formatter uses seconds everywhere', () {
    expect(formatStudyDuration(0), '00:00');
    expect(formatStudyDuration(90), '01:30');
    expect(formatStudyDuration(3599), '59:59');
    expect(formatStudyDuration(3600), '01:00:00');
  });

  test('fresh data stays empty through reload and clear all', () async {
    final storage = _MemoryStorage();
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    expect(store.plans, isEmpty);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    store.clearAllData();
    expect(await store.flush(), isTrue);
    store.dispose();
    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => today,
    );
    addTearDown(reopened.dispose);
    expect(reopened.plans, isEmpty);
  });

  test(
    'legacy plans migrate without losing second precision or history',
    () async {
      final storage = _MemoryStorage();
      storage.value = jsonEncode({
        'version': 2,
        'nextId': 2,
        'plans': [
          {
            'id': 'custom_1',
            'name': '阅读',
            'iconId': 'book',
            'plannedMinutes': 60,
            'progressDay': '2026-09-28',
            'remainingSeconds': 2537,
            'studiedSeconds': 1063,
            'hasStartedToday': true,
            'isCompletedToday': false,
          },
        ],
        'records': [
          {
            'id': '2026-09-27_custom_1',
            'planId': 'custom_1',
            'date': '2026-09-27',
            'plannedSeconds': 3600,
            'studiedSeconds': 1500,
          },
        ],
      });
      final legacy = storage.value;
      final store = await StudyPlanStore.load(
        storage: storage,
        now: () => today,
      );
      addTearDown(store.dispose);
      expect(store.plans.single.plannedSeconds, 3600);
      expect(store.plans.single.remainingSeconds, 2537);
      expect(store.plans.single.studiedSeconds, 1063);
      expect(store.records.length, 2);
      expect(store.records.first.date, '2026-09-27');
      expect(await store.flush(), isTrue);
      expect(jsonDecode(storage.value!)['version'], 3);
      expect(legacy, contains('plannedMinutes'));
      store.deletePlan('custom_1');
      expect(store.records.length, 2);
      expect(await store.flush(), isTrue);
      final reopened = await StudyPlanStore.load(
        storage: storage,
        now: () => today,
      );
      addTearDown(reopened.dispose);
      expect(reopened.plans, isEmpty);
      expect(reopened.records.length, 2);
    },
  );

  test('unknown snapshot is never overwritten with empty data', () async {
    final storage = _MemoryStorage()..value = '{"version":99,"plans":[]}';
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    expect(store.hasLoadError, isTrue);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    await store.flush();
    expect(storage.value, '{"version":99,"plans":[]}');
  });

  test(
    'daily target edits retain studied time and crossing day keeps history',
    () {
      var now = today;
      final store = StudyPlanStore(now: () => now);
      addTearDown(store.dispose);
      store.addPlan(name: '数学', iconId: 'calculate', plannedSeconds: 90);
      final id = store.plans.single.id;
      store.startOrResume(id);
      for (var i = 0; i < 70; i++) {
        store.studyOneSecond(id);
      }
      store.updatePlan(store.plans.single.copyWith(plannedSeconds: 120));
      expect(store.plans.single.remainingSeconds, 50);
      store.updatePlan(store.plans.single.copyWith(plannedSeconds: 60));
      expect(store.plans.single.remainingSeconds, 0);
      expect(store.plans.single.studiedSeconds, 70);
      expect(store.plans.single.isCompletedToday, isTrue);
      now = DateTime(2026, 9, 29);
      store.refreshForToday();
      expect(store.plans.single.hasStartedToday, isFalse);
      expect(store.plans.single.studiedSeconds, 0);
      expect(store.records.single.studiedSeconds, 70);
      expect(store.records.single.planId, id);
    },
  );

  testWidgets('pause, return, reload and background exclude idle time', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    final id = store.plans.single.id;
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle();
    expect(find.text('01:30'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(store.plans.single.hasStartedToday, isFalse);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(store.plans.single.remainingSeconds, 88);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(store.plans.single.remainingSeconds, 88);
    expect(store.plans.single.studiedSeconds, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('开始'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('今日剩余 01:28'), findsOneWidget);
    expect(await store.flush(), isTrue);
    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => today,
    );
    addTearDown(reopened.dispose);
    expect(reopened.planById(id)!.remainingSeconds, 88);
    expect(reopened.planById(id)!.studiedSeconds, 2);
  });

  testWidgets(
    'adjusted remaining time does not change target or studied time',
    (tester) async {
      final store = StudyPlanStore(now: () => today);
      addTearDown(store.dispose);
      store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 60);
      final id = store.plans.single.id;
      await tester.pumpWidget(
        MaterialApp(
          home: StudyTimerPage(store: store, planId: id),
        ),
      );
      await tester.tap(find.text('开始'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('调整时间'));
      await tester.pumpAndSettle();
      expect(find.text('开始'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('duration_minutes')),
        '2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('duration_seconds')),
        '0',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(store.plans.single.plannedSeconds, 60);
      expect(store.plans.single.remainingSeconds, 120);
      expect(store.plans.single.studiedSeconds, 3);
      await tester.pump(const Duration(seconds: 5));
      expect(store.plans.single.studiedSeconds, 3);
      expect(find.text('02:00'), findsOneWidget);
    },
  );

  testWidgets('completion percentage exceeds 100 while bar is capped', (
    tester,
  ) async {
    final store = StudyPlanStore(now: () => today);
    addTearDown(store.dispose);
    store.addPlan(name: '数学', iconId: 'calculate', plannedSeconds: 60);
    final id = store.plans.single.id;
    store.adjustRemainingSeconds(id, 120);
    for (var i = 0; i < 120; i++) {
      store.studyOneSecond(id);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StudyStatisticsPage(store: store)),
      ),
    );
    expect(find.text('今日完成率：200%'), findsOneWidget);
    expect(find.text('超出计划：01:00'), findsOneWidget);
    for (final bar in tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    )) {
      expect(bar.value, 1.0);
    }
    store.deletePlan(id);
    await tester.pump();
    expect(store.records.single.studiedSeconds, 120);
  });
}
