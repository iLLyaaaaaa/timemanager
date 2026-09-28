import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/main.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';

void main() {
  testWidgets('fresh install is empty and navigation works', (tester) async {
    final store = StudyPlanStore();
    await tester.pumpWidget(MyApp(store: store));
    expect(store.plans, isEmpty);
    expect(find.textContaining('还没有学习计划'), findsOneWidget);
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('今日总览'), findsOneWidget);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('显示秒数'), findsNothing);
  });

  testWidgets('90 second plan can be added, edited, timed and deleted', (
    tester,
  ) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增计划'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('plan_name')), 'Python');
    await tester.enterText(find.byKey(const ValueKey('duration_hours')), '0');
    await tester.enterText(find.byKey(const ValueKey('duration_minutes')), '0');
    await tester.enterText(find.byKey(const ValueKey('duration_seconds')), '0');
    await tester.tap(find.text('保存计划'));
    await tester.pump();
    expect(find.text('总时长必须大于 0 秒'), findsOneWidget);
    expect(store.plans, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('duration_minutes')), '60');
    await tester.tap(find.text('保存计划'));
    await tester.pump();
    expect(find.text('分钟和秒须在 0 到 59 之间'), findsOneWidget);
    expect(store.plans, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('duration_minutes')), '1');
    await tester.enterText(
      find.byKey(const ValueKey('duration_seconds')),
      '30',
    );
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(store.plans.single.plannedSeconds, 90);
    final id = store.plans.single.id;
    await tester.tap(find.byTooltip('编辑Python计划'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('plan_name')), 'Python进阶');
    await tester.enterText(
      find.byKey(const ValueKey('duration_seconds')),
      '31',
    );
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(store.plans.single.id, id);
    expect(store.plans.single.plannedSeconds, 91);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final card = find.byKey(ValueKey('plan_card_$id'));
    expect(
      find.descendant(of: card, matching: find.text('今日计划 01:31')),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: card, matching: find.text('开始学习')));
    await tester.pumpAndSettle();
    expect(find.text('01:31'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('01:31'), findsOneWidget);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('01:30'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除Python进阶计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(store.plans, isEmpty);
  });

  testWidgets('timer pauses, resumes and completes', (tester) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 3);
    final id = store.plans.single.id;
    await tester.pumpWidget(
      MaterialApp(
        home: StudyTimerPage(store: store, planId: id),
      ),
    );
    expect(find.text('00:03'), findsOneWidget);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(store.plans.single.studiedSeconds, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(store.plans.single.studiedSeconds, 1);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('今日计划已完成'), findsOneWidget);
    expect(find.text('开始'), findsNothing);
  });
}
