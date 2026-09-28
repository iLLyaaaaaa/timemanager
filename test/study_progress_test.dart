import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hello_app/data/study_plan_storage.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_statistics_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';

class _MemoryStudyPlanStorage implements StudyPlanStorage {
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
  const japaneseId = 'default_japanese';

  testWidgets('pause, leave, and resume from the saved second', (tester) async {
    final storage = _MemoryStudyPlanStorage();
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));

    final card = find.byKey(const ValueKey('plan_card_default_japanese'));
    expect(
      find.descendant(of: card, matching: find.text('今日计划 60 分钟')),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: card, matching: find.text('开始学习')));
    await tester.pumpAndSettle();
    expect(find.text('60:00'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('60:00'), findsOneWidget);
    expect(store.planById(japaneseId)!.hasStartedToday, isFalse);
    await tester.tap(find.text('开始'));
    await tester.pump();
    expect(find.text('暂停'), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('59:00'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(store.planById(japaneseId)!.remainingSeconds, 3540);
    expect(store.planById(japaneseId)!.studiedSeconds, 60);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card, matching: find.text('今日剩余 59 分钟')),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: card, matching: find.text('开始学习')));
    await tester.pumpAndSettle();
    expect(find.text('59:00'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('59:00'), findsOneWidget);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('58:59'), findsOneWidget);
    expect(store.planById(japaneseId)!.studiedSeconds, 61);
  });

  testWidgets('saved seconds survive a store reload on the same day', (
    tester,
  ) async {
    final storage = _MemoryStudyPlanStorage();
    final first = await StudyPlanStore.load(storage: storage, now: () => today);
    first.startOrResume(japaneseId);
    for (var second = 0; second < 1063; second++) {
      first.studyOneSecond(japaneseId);
    }
    expect(await first.flush(), isTrue);
    first.dispose();

    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => today,
    );
    addTearDown(reopened.dispose);
    final plan = reopened.planById(japaneseId)!;
    expect(plan.hasStartedToday, isTrue);
    expect(plan.remainingSeconds, 2537);
    expect(plan.studiedSeconds, 1063);
    await tester.pumpWidget(
      MaterialApp(
        home: StudyTimerPage(store: reopened, planId: japaneseId),
      ),
    );
    expect(find.text('42:17'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('42:17'), findsOneWidget);
  });

  testWidgets('completion is saved and shown on the home card', (tester) async {
    final store = StudyPlanStore(now: () => today);
    addTearDown(store.dispose);
    store.updatePlan(store.planById(japaneseId)!.copyWith(plannedMinutes: 1));
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));
    final card = find.byKey(const ValueKey('plan_card_default_japanese'));
    await tester.tap(find.descendant(of: card, matching: find.text('开始学习')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('今日计划已完成'), findsOneWidget);
    expect(find.text('开始'), findsNothing);
    expect(store.planById(japaneseId)!.remainingSeconds, 0);
    expect(store.planById(japaneseId)!.isCompletedToday, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card, matching: find.text('今日计划已完成')),
      findsOneWidget,
    );
  });

  testWidgets('system back pauses a running timer and preserves progress', (
    tester,
  ) async {
    final storage = _MemoryStudyPlanStorage();
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));
    final card = find.byKey(const ValueKey('plan_card_default_japanese'));
    await tester.tap(find.descendant(of: card, matching: find.text('开始学习')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(store.planById(japaneseId)!.remainingSeconds, 3597);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(store.planById(japaneseId)!.remainingSeconds, 3597);
    expect(store.planById(japaneseId)!.studiedSeconds, 3);
    await tester.pump(const Duration(seconds: 5));
    expect(store.planById(japaneseId)!.remainingSeconds, 3597);
    expect(find.text('今日剩余 59 分 57 秒'), findsOneWidget);

    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => today,
    );
    addTearDown(reopened.dispose);
    expect(reopened.planById(japaneseId)!.remainingSeconds, 3597);
    expect(reopened.planById(japaneseId)!.studiedSeconds, 3);
  });

  testWidgets('leaving the foreground pauses and saves the running timer', (
    tester,
  ) async {
    final storage = _MemoryStudyPlanStorage();
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    store.updatePlan(store.planById(japaneseId)!.copyWith(plannedMinutes: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: StudyTimerPage(store: store, planId: japaneseId),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(store.planById(japaneseId)!.hasStartedToday, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('00:40'), findsOneWidget);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      final before = store.planById(japaneseId)!;
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(
        store.planById(japaneseId)!.remainingSeconds,
        before.remainingSeconds,
      );
      expect(store.planById(japaneseId)!.studiedSeconds, before.studiedSeconds);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('开始'), findsOneWidget);
      if (state != AppLifecycleState.detached) {
        await tester.tap(find.text('开始'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('暂停'), findsOneWidget);
      }
    }
    expect(await store.flush(), isTrue);
    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => today,
    );
    addTearDown(reopened.dispose);
    expect(reopened.planById(japaneseId)!.remainingSeconds, 37);
    expect(reopened.planById(japaneseId)!.studiedSeconds, 23);
  });

  test(
    'editing duration preserves studied seconds and can complete a plan',
    () {
      final store = StudyPlanStore(now: () => today);
      addTearDown(store.dispose);
      store.updatePlan(store.planById(japaneseId)!.copyWith(plannedMinutes: 2));
      store.startOrResume(japaneseId);
      for (var second = 0; second < 70; second++) {
        store.studyOneSecond(japaneseId);
      }
      store.updatePlan(store.planById(japaneseId)!.copyWith(plannedMinutes: 3));
      expect(store.planById(japaneseId)!.studiedSeconds, 70);
      expect(store.planById(japaneseId)!.remainingSeconds, 110);
      expect(store.planById(japaneseId)!.isCompletedToday, isFalse);

      store.updatePlan(store.planById(japaneseId)!.copyWith(plannedMinutes: 1));
      expect(store.planById(japaneseId)!.studiedSeconds, 70);
      expect(store.planById(japaneseId)!.remainingSeconds, 0);
      expect(store.planById(japaneseId)!.isCompletedToday, isTrue);
    },
  );

  test('a new calendar day resets only daily progress', () async {
    final storage = _MemoryStudyPlanStorage();
    var now = today;
    final store = await StudyPlanStore.load(storage: storage, now: () => now);
    addTearDown(store.dispose);
    store.startOrResume(japaneseId);
    store.studyOneSecond(japaneseId);
    now = DateTime(2026, 9, 29);
    store.refreshForToday();
    final plan = store.planById(japaneseId)!;
    expect(plan.hasStartedToday, isFalse);
    expect(plan.isCompletedToday, isFalse);
    expect(plan.remainingSeconds, 0);
    expect(plan.studiedSeconds, 0);
    expect(plan.plannedMinutes, 60);
    expect(store.records.single.date, '2026-09-28');
    expect(store.records.single.planId, japaneseId);
    expect(store.records.single.studiedSeconds, 1);
    expect(await store.flush(), isTrue);
    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => now,
    );
    addTearDown(reopened.dispose);
    expect(reopened.records.single.studiedSeconds, 1);
    expect(reopened.planById(japaneseId)!.studiedSeconds, 0);
  });

  testWidgets('adjusting time pauses the timer and preserves studied seconds', (
    tester,
  ) async {
    final storage = _MemoryStudyPlanStorage();
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: StudyTimerPage(store: store, planId: japaneseId),
      ),
    );

    await tester.tap(find.text('调整时间'));
    await tester.pumpAndSettle();
    for (final invalid in ['', '0', '-1', 'abc', '1.5']) {
      await tester.enterText(
        find.byKey(const ValueKey('adjust_minutes')),
        invalid,
      );
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(
        find.text(invalid.isEmpty ? '请输入剩余分钟数' : '请输入大于 0 的整数分钟数'),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.planById(japaneseId)!.hasStartedToday, isFalse);

    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(store.planById(japaneseId)!.studiedSeconds, 30);
    await tester.tap(find.text('调整时间'));
    await tester.pumpAndSettle();
    expect(store.planById(japaneseId)!.remainingSeconds, 3570);
    await tester.pump(const Duration(seconds: 10));
    expect(store.planById(japaneseId)!.studiedSeconds, 30);
    await tester.enterText(find.byKey(const ValueKey('adjust_minutes')), '90');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('90:00'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(store.planById(japaneseId)!.plannedMinutes, 60);
    expect(store.planById(japaneseId)!.remainingSeconds, 5400);
    expect(store.planById(japaneseId)!.studiedSeconds, 30);
    await tester.pump(const Duration(seconds: 5));
    expect(store.planById(japaneseId)!.studiedSeconds, 30);

    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => today,
    );
    addTearDown(reopened.dispose);
    expect(reopened.planById(japaneseId)!.remainingSeconds, 5400);
    expect(reopened.planById(japaneseId)!.studiedSeconds, 30);
  });

  testWidgets('statistics show actual progress above 100%', (tester) async {
    final storage = _MemoryStudyPlanStorage();
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    for (final plan in store.plans) {
      store.deletePlan(plan.id);
    }
    store.addPlan(name: '阅读', iconId: 'book', plannedMinutes: 1);
    final id = store.plans.single.id;
    store.adjustRemainingMinutes(id, 2);
    for (var second = 0; second < 70; second++) {
      store.studyOneSecond(id);
    }
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('statistics_$id')), findsOneWidget);
    expect(find.text('今日计划总时长：1 分钟'), findsOneWidget);
    expect(find.text('今日已学习：1 分 10 秒'), findsOneWidget);
    expect(find.text('今日剩余：0 分 50 秒'), findsOneWidget);
    expect(find.text('今日完成率：116.7%'), findsOneWidget);
    expect(find.text('已学习：1 分 10 秒'), findsOneWidget);
    expect(find.text('116.7%'), findsOneWidget);
    expect(find.text('超出计划：0 分 10 秒'), findsOneWidget);
    for (final bar in tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    )) {
      expect(bar.value, 1.0);
    }

    store.deletePlan(id);
    await tester.pump();
    expect(find.byKey(ValueKey('statistics_$id')), findsNothing);
    expect(find.text('今日计划总时长：0 分钟'), findsOneWidget);
    expect(store.records.single.planId, id);
    expect(store.records.single.studiedSeconds, 70);
    expect(await store.flush(), isTrue);
    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => today,
    );
    addTearDown(reopened.dispose);
    expect(reopened.plans, isEmpty);
    expect(reopened.records.single.planId, id);
    expect(reopened.records.single.studiedSeconds, 70);
  });

  testWidgets('statistics show the exact completion percentage', (
    tester,
  ) async {
    final store = StudyPlanStore(now: () => today);
    addTearDown(store.dispose);
    for (final plan in store.plans) {
      store.deletePlan(plan.id);
    }
    store.addPlan(name: '数学', iconId: 'calculate', plannedMinutes: 2);
    final id = store.plans.single.id;
    store.startOrResume(id);
    for (var second = 0; second < 75; second++) {
      store.studyOneSecond(id);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StudyStatisticsPage(store: store)),
      ),
    );
    expect(find.text('今日完成率：62.5%'), findsOneWidget);
    expect(find.text('62.5%'), findsOneWidget);
    expect(find.text('已学习：1 分 15 秒'), findsOneWidget);
    expect(find.text('剩余：0 分 45 秒'), findsOneWidget);
  });

  testWidgets('a two-minute session keeps a one-minute daily plan', (
    tester,
  ) async {
    final store = StudyPlanStore(now: () => today);
    addTearDown(store.dispose);
    for (final plan in store.plans.where((plan) => plan.id != japaneseId)) {
      store.deletePlan(plan.id);
    }
    store.updatePlan(store.planById(japaneseId)!.copyWith(plannedMinutes: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: StudyTimerPage(store: store, planId: japaneseId),
      ),
    );
    await tester.tap(find.text('调整时间'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('adjust_minutes')), '2');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.planById(japaneseId)!.plannedMinutes, 1);
    expect(store.planById(japaneseId)!.remainingSeconds, 120);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(store.planById(japaneseId)!.studiedSeconds, 120);
    expect(store.planById(japaneseId)!.isCompletedToday, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StudyStatisticsPage(store: store)),
      ),
    );
    expect(find.text('今日完成率：200%'), findsOneWidget);
    expect(find.text('200%'), findsOneWidget);
    expect(find.text('超出计划：1 分钟'), findsOneWidget);
  });

  testWidgets('ninety minutes against a sixty-minute plan shows 150%', (
    tester,
  ) async {
    final store = StudyPlanStore(now: () => today);
    addTearDown(store.dispose);
    for (final plan in store.plans) {
      store.deletePlan(plan.id);
    }
    store.addPlan(name: '数学', iconId: 'calculate', plannedMinutes: 60);
    final id = store.plans.single.id;
    store.adjustRemainingMinutes(id, 90);
    for (var second = 0; second < 90 * 60; second++) {
      store.studyOneSecond(id);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StudyStatisticsPage(store: store)),
      ),
    );
    expect(find.text('今日完成率：150%'), findsOneWidget);
    expect(find.text('150%'), findsOneWidget);
    expect(find.text('计划：60 分钟'), findsOneWidget);
    expect(find.text('已学习：90 分钟'), findsOneWidget);
    expect(find.text('超出计划：30 分钟'), findsOneWidget);
  });

  test('older saved plans migrate without losing progress', () async {
    final storage = _MemoryStudyPlanStorage();
    storage.value = jsonEncode({
      'version': 1,
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
    });
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    expect(store.plans.single.remainingSeconds, 2537);
    expect(store.records.single.studiedSeconds, 1063);
    expect(await store.flush(), isTrue);
    expect(jsonDecode(storage.value!)['version'], 2);
    store.adjustRemainingMinutes('custom_1', 90);
    store.updatePlan(store.plans.single.copyWith(name: '深度阅读'));
    expect(store.plans.single.remainingSeconds, 5400);
    expect(store.plans.single.studiedSeconds, 1063);
  });
}
