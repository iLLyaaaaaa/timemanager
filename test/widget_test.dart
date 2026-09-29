import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/main.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';
import 'package:hello_app/widgets/study_plan_card.dart';

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
    await tester.enterText(
      find.byKey(const ValueKey('duration_minutes')),
      '60',
    );
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

  testWidgets('study buttons are aligned, prominent and reflect progress', (
    tester,
  ) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    store.addPlan(name: '日语', iconId: 'language', plannedSeconds: 90);
    store.addPlan(name: '数学', iconId: 'calculate', plannedSeconds: 120);
    final first = store.plans.first.id;
    final second = store.plans.last.id;
    store.startOrResume(second);
    store.studyOneSecond(second);
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));
    final firstButton = find.byKey(ValueKey('start_plan_$first'));
    final secondButton = find.byKey(ValueKey('start_plan_$second'));
    expect(
      find.descendant(of: firstButton, matching: find.text('开始学习')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondButton, matching: find.text('继续学习')),
      findsOneWidget,
    );
    for (final id in [first, second]) {
      final button = find.byKey(ValueKey('start_plan_$id'));
      final card = find.byKey(ValueKey('plan_card_$id'));
      final buttonRect = tester.getRect(button);
      final cardRect = tester.getRect(card);
      expect(buttonRect.width, greaterThanOrEqualTo(100));
      expect(buttonRect.height, greaterThanOrEqualTo(44));
      expect((buttonRect.center.dy - cardRect.center.dy).abs(), lessThan(8));
      final buttonColor = tester
          .widget<FilledButton>(button)
          .style!
          .backgroundColor!
          .resolve({});
      final cardColor = tester.widget<Card>(card).color;
      expect(buttonColor, isNot(cardColor));
      final buttonLuminance = buttonColor!.computeLuminance();
      final cardLuminance = cardColor!.computeLuminance();
      final lighter = buttonLuminance > cardLuminance
          ? buttonLuminance
          : cardLuminance;
      final darker = buttonLuminance < cardLuminance
          ? buttonLuminance
          : cardLuminance;
      expect((lighter + 0.05) / (darker + 0.05), greaterThan(3));
    }
    expect(find.byType(StudyPlanCard), findsNWidgets(2));
    await tester.tap(secondButton);
    await tester.pumpAndSettle();
    expect(find.text('01:59'), findsOneWidget);
  });

  testWidgets('batch delete removes only selected plans after confirmation', (
    tester,
  ) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    for (final name in ['日语', '英语', '数学']) {
      store.addPlan(name: name, iconId: 'book', plannedSeconds: 90);
    }
    final ids = store.plans.map((plan) => plan.id).toList();
    store.startOrResume(ids.first);
    store.studyOneSecond(ids.first);
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('批量管理'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '删除选中 (0)'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('全选'));
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(find.byKey(ValueKey('select_plan_${ids[1]}')))
          .value,
      isTrue,
    );
    await tester.tap(find.text('取消全选'));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('select_plan_${ids[0]}')));
    await tester.tap(find.byKey(ValueKey('select_plan_${ids[2]}')));
    await tester.pump();
    await tester.tap(find.text('删除选中 (2)'));
    await tester.pumpAndSettle();
    expect(find.text('确定删除已选择的 2 个计划吗？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.plans.length, 3);
    await tester.tap(find.text('删除选中 (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(store.plans.map((plan) => plan.id), [ids[1]]);
    expect(store.records.single.planId, ids[0]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('plan_card_${ids[1]}')), findsOneWidget);
    expect(find.byKey(ValueKey('plan_card_${ids[0]}')), findsNothing);
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('statistics_${ids[1]}')), findsOneWidget);
    expect(find.byKey(ValueKey('statistics_${ids[2]}')), findsNothing);
  });
}
