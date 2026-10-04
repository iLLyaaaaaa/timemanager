import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/pages/plan_management_page.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';
import 'package:hello_app/utils/study_plan_query.dart';
import 'package:hello_app/widgets/study_history_view.dart';
import 'package:hello_app/widgets/study_plan_card.dart';

import 'support/localized_app.dart';

StudyPlanStore _plans() {
  final store = StudyPlanStore(now: () => DateTime(2026, 10, 4, 12));
  final math = store.addPlan(
    name: 'Advanced Math',
    iconId: 'calculate',
    plannedSeconds: 120,
  );
  store.addPlan(name: 'Python', iconId: 'code', plannedSeconds: 120);
  final reading = store.addPlan(
    name: '阅读 Math notes',
    iconId: 'book',
    plannedSeconds: 60,
  );
  store.startOrResume(math.id);
  store.studySeconds(math.id, 30);
  store.startOrResume(reading.id);
  store.studySeconds(reading.id, 60);
  return store;
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester, String key) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(PageStorageKey(key)),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void main() {
  test('name and status filters preserve plan order and stored progress', () {
    final store = _plans();
    addTearDown(store.dispose);
    final before = jsonEncode(
      store.plans.map((plan) => plan.toJson()).toList(),
    );
    expect(
      filterStudyPlans(store.plans, query: '  mAtH ').map((plan) => plan.name),
      ['Advanced Math', '阅读 Math notes'],
    );
    expect(
      filterStudyPlans(
        store.plans,
        query: 'math',
        filter: StudyPlanFilter.inProgress,
      ).single.name,
      'Advanced Math',
    );
    expect(
      filterStudyPlans(
        store.plans,
        filter: StudyPlanFilter.notStarted,
      ).single.name,
      'Python',
    );
    expect(
      filterStudyPlans(
        store.plans,
        filter: StudyPlanFilter.completed,
      ).single.name,
      '阅读 Math notes',
    );
    expect(
      filterStudyPlans(
        store.plans,
        query: 'Python',
        filter: StudyPlanFilter.completed,
      ),
      isEmpty,
    );
    expect(
      jsonEncode(store.plans.map((plan) => plan.toJson()).toList()),
      before,
    );
  });

  test('continue entry prefers running plans and skips completed plans', () {
    final store = _plans();
    addTearDown(store.dispose);
    expect(planToContinue(store.plans)?.id, store.plans.first.id);
    store.beginRunning(store.plans[1].id);
    expect(planToContinue(store.plans)?.id, store.plans[1].id);
    store.pauseRunning(store.plans[1].id);
    expect(planToContinue(store.plans)?.id, store.plans.first.id);
    for (final plan in store.plans) {
      store.studySeconds(plan.id, 120);
    }
    expect(planToContinue(store.plans), isNull);
    expect(planToContinue([]), isNull);
  });

  testWidgets(
    'home search and status filter retain full overview and recover',
    (tester) async {
      _phoneSize(tester);
      final store = _plans();
      addTearDown(store.dispose);
      await tester.pumpWidget(localizedApp(home: StudyHomePage(store: store)));
      final search = find.byKey(const ValueKey('plan_search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'mAtH');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('home_completed_total')))
            .data,
        '1 / 3',
      );
      expect(find.text('全部 · 2'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('plan_filter_completed')),
      );
      final card = tester.widget<StudyPlanCard>(find.byType(StudyPlanCard));
      expect(card.plan.id, store.plans.last.id);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'unknown');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byType(StudyPlanCard), findsNothing);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('reset_plan_filters')),
      );
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('plan_filter_all')))
            .selected,
        isTrue,
      );
      expect(store.plans.length, 3);
      expect(store.plans.first.studiedSeconds, 30);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('home shortcut opens the paused plan without starting it', (
    tester,
  ) async {
    final store = _plans();
    addTearDown(store.dispose);
    await tester.pumpWidget(localizedApp(home: StudyHomePage(store: store)));
    await _tapVisible(tester, find.byKey(const ValueKey('home_resume_plan')));
    expect(
      tester.widget<StudyTimerPage>(find.byType(StudyTimerPage)).planId,
      store.plans.first.id,
    );
    expect(store.plans.first.isRunning, isFalse);
    expect(store.plans.first.remainingSeconds, 90);
    await tester.pump(const Duration(seconds: 2));
    expect(store.plans.first.studiedSeconds, 30);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bulk management uses all plans and restores the search', (
    tester,
  ) async {
    _phoneSize(tester);
    final store = _plans();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      localizedApp(home: PlanManagementPage(store: store)),
    );
    final search = find.byKey(const ValueKey('plan_search'));
    await tester.enterText(search, 'Python');
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      find.byKey(ValueKey('manage_plan_${store.plans.first.id}')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('toggle_bulk_mode')));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byKey(const ValueKey('plan_search')), findsNothing);
    expect(find.textContaining('批量选择显示全部计划'), findsOneWidget);
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    expect(find.text('删除选中 (3)'), findsOneWidget);
    expect(find.text('取消全选'), findsOneWidget);
    await tester.tap(find.text('取消全选'));
    await tester.pumpAndSettle();
    expect(find.text('删除选中 (0)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle_bulk_mode')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, 'Python');
    expect(
      find.byKey(ValueKey('manage_plan_${store.plans.first.id}')),
      findsNothing,
    );
    await _tapVisible(tester, find.byKey(const ValueKey('clear_plan_search')));
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(store.plans.length, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tabs retain home query, scroll and the history view position', (
    tester,
  ) async {
    _phoneSize(tester);
    final settings = SettingsStore();
    final store = StudyPlanStore(settings: settings);
    addTearDown(settings.dispose);
    addTearDown(store.dispose);
    for (var index = 0; index < 8; index++) {
      store.addPlan(name: 'Plan $index', iconId: 'book', plannedSeconds: 60);
    }
    await tester.pumpWidget(
      localizedApp(
        home: StudyHomePage(store: store, settings: settings),
      ),
    );
    final search = find.byKey(const ValueKey('plan_search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Plan');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    _position(tester, 'home_scroll').jumpTo(500);
    await tester.pumpAndSettle();
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('近 7 天'));
    await tester.pumpAndSettle();
    _position(tester, 'statistics_scroll_true').jumpTo(220);
    await tester.pumpAndSettle();
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(_position(tester, 'home_scroll').pixels, closeTo(500, 1));
    _position(tester, 'home_scroll').jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, 'Plan');
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.byType(StudyHistoryView), findsOneWidget);
    expect(_position(tester, 'statistics_scroll_true').pixels, closeTo(220, 1));
    _position(tester, 'statistics_scroll_true').jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('今日').first);
    await tester.pumpAndSettle();
    expect(_position(tester, 'statistics_scroll_false').pixels, 0);
    await tester.tap(find.text('近 7 天'));
    await tester.pumpAndSettle();
    expect(_position(tester, 'statistics_scroll_true').pixels, 0);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    _position(tester, 'settings_scroll').jumpTo(200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(_position(tester, 'settings_scroll').pixels, closeTo(200, 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('completion and daily reset refresh the selected status', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 4, 12);
    final store = StudyPlanStore(now: () => now);
    addTearDown(store.dispose);
    final plan = store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 60);
    await tester.pumpWidget(localizedApp(home: StudyHomePage(store: store)));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('plan_filter_completed')),
    );
    expect(find.byType(StudyPlanCard), findsNothing);
    store.startOrResume(plan.id);
    store.studySeconds(plan.id, 60);
    await tester.pumpAndSettle();
    expect(find.byType(StudyPlanCard), findsOneWidget);
    expect(find.byKey(const ValueKey('home_resume_plan')), findsNothing);
    now = DateTime(2026, 10, 5, 12);
    store.refreshForToday();
    await tester.pumpAndSettle();
    expect(find.byType(StudyPlanCard), findsNothing);
    await _tapVisible(tester, find.byKey(const ValueKey('reset_plan_filters')));
    expect(store.plans.single.hasStartedToday, isFalse);
    expect(find.byType(StudyPlanCard), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
