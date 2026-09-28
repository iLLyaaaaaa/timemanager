import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/main.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';

void main() {
  testWidgets('default plans and bottom navigation remain available', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('今日学习'), findsOneWidget);
    expect(find.text('日语'), findsOneWidget);
    expect(find.text('英语'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('编程'), 250);
    expect(find.text('数学'), findsOneWidget);
    expect(find.text('编程'), findsOneWidget);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('今日总览'), findsOneWidget);
    expect(find.text('今日计划总时长：360 分钟'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('statistics_default_japanese')),
      findsOneWidget,
    );
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('主题模式'), findsOneWidget);
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();
    expect(find.text('计划管理'), findsOneWidget);
    expect(find.text('新增计划'), findsOneWidget);
  });

  testWidgets('a custom plan can be added, edited, timed, and deleted', (
    tester,
  ) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));

    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增计划'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存计划'));
    await tester.pump();
    expect(find.text('请输入计划名称'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('plan_minutes')), '');
    await tester.tap(find.text('保存计划'));
    await tester.pump();
    expect(find.text('请输入计划时长'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('plan_name')), 'Python');
    for (final invalid in ['', '0', '-2', 'abc', '1.5']) {
      await tester.enterText(
        find.byKey(const ValueKey('plan_minutes')),
        invalid,
      );
      await tester.tap(find.text('保存计划'));
      await tester.pump();
      expect(store.plans.length, 4);
      expect(
        find.text(invalid.isEmpty ? '请输入计划时长' : '请输入大于 0 的整数分钟数'),
        findsOneWidget,
      );
    }

    await tester.enterText(find.byKey(const ValueKey('plan_minutes')), '2');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('icon_option_terminal')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('icon_option_terminal')));
    await tester.pump();
    expect(find.text('当前：终端'), findsOneWidget);
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();

    expect(store.plans.length, 5);
    final customId = store.plans.last.id;
    expect(store.plans.last.iconId, 'terminal');
    await tester.scrollUntilVisible(find.text('Python'), 200);
    await tester.tap(find.byTooltip('编辑Python计划'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('plan_name')), 'Python进阶');
    await tester.enterText(find.byKey(const ValueKey('plan_minutes')), '3');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('icon_option_code')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('icon_option_code')));
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();

    expect(store.plans.length, 5);
    expect(store.plans.last.id, customId);
    expect(store.plans.last.name, 'Python进阶');
    expect(store.plans.last.plannedMinutes, 3);
    expect(store.plans.last.iconId, 'code');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('共 363 分钟'), findsOneWidget);
    final card = find.byKey(ValueKey('plan_card_$customId'));
    await tester.scrollUntilVisible(card, 250);
    expect(
      tester.widget<Icon>(find.byKey(ValueKey('plan_icon_$customId'))).icon,
      Icons.code,
    );
    await tester.tap(find.descendant(of: card, matching: find.text('开始学习')));
    await tester.pumpAndSettle();
    expect(find.text('Python进阶'), findsOneWidget);
    expect(find.text('今日计划总时长 3 分钟'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byKey(const ValueKey('timer_plan_icon'))).icon,
      Icons.code,
    );
    expect(find.text('03:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('03:00'), findsOneWidget);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('02:59'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Python进阶'), 200);
    await tester.tap(find.byTooltip('删除Python进阶计划'));
    await tester.pumpAndSettle();
    expect(find.text('确定删除“Python进阶”计划吗？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.plans.length, 5);
    await tester.tap(find.byTooltip('删除Python进阶计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(store.plans.length, 4);
    expect(store.plans.any((plan) => plan.id == customId), isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 项学习计划 · 共 360 分钟'), findsOneWidget);
  });

  testWidgets('default plans can be edited and deleted without duplication', (
    tester,
  ) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: StudyHomePage(store: store)));
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();

    final originalId = store.plans.first.id;
    await tester.tap(find.byTooltip('编辑日语计划'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('plan_name')), '日语会话');
    await tester.enterText(find.byKey(const ValueKey('plan_minutes')), '90');
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(store.plans.length, 4);
    expect(store.plans.first.id, originalId);
    expect(store.plans.first.name, '日语会话');
    expect(store.plans.first.plannedMinutes, 90);

    await tester.tap(find.byTooltip('删除日语会话计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(store.plans.length, 3);
    expect(store.plans.any((plan) => plan.id == originalId), isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('3 项学习计划 · 共 300 分钟'), findsOneWidget);
  });

  testWidgets('timer pauses, resumes, and completes', (tester) async {
    final store = StudyPlanStore();
    addTearDown(store.dispose);
    store.addPlan(name: '阅读', iconId: 'book', plannedMinutes: 1);
    final planId = store.plans.last.id;
    store.startOrResume(planId);
    await tester.pumpWidget(
      MaterialApp(
        home: StudyTimerPage(store: store, planId: planId),
      ),
    );
    expect(find.text('01:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('01:00'), findsOneWidget);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('00:57'), findsOneWidget);
    expect(find.text('00:03'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('00:57'), findsOneWidget);
    expect(find.text('00:03'), findsOneWidget);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 57));
    expect(find.text('今日计划已完成'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('开始'), findsNothing);
  });
}
