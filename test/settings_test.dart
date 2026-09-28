import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/main.dart';
import 'package:hello_app/pages/plan_management_page.dart';
import 'package:hello_app/pages/settings_page.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';

class _MemorySettingsStorage implements AppSettingsStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

void main() {
  testWidgets('theme changes immediately and survives an app restart', (
    tester,
  ) async {
    final storage = _MemorySettingsStorage();
    final settings = await SettingsStore.load(storage: storage);
    final plans = StudyPlanStore(settings: settings);
    await tester.pumpWidget(MyApp(store: plans, settings: settings));
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();
    expect(settings.settings.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('主题模式'))).brightness,
      Brightness.dark,
    );
    expect(await settings.flush(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    final reopened = await SettingsStore.load(storage: storage);
    final reopenedPlans = StudyPlanStore(settings: reopened);
    await tester.pumpWidget(MyApp(store: reopenedPlans, settings: reopened));
    expect(reopened.settings.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('今日学习'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('default duration fills new plans and reset keeps plans', (
    tester,
  ) async {
    final storage = _MemorySettingsStorage();
    final settings = await SettingsStore.load(storage: storage);
    final plans = StudyPlanStore(settings: settings);
    addTearDown(plans.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: StudyHomePage(store: plans, settings: settings),
      ),
    );
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('新增计划默认时长'), 200);
    await tester.tap(find.text('新增计划默认时长'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('default_plan_minutes')),
      '90',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(settings.settings.defaultPlanMinutes, 90);
    expect(await settings.flush(), isTrue);
    final reopened = await SettingsStore.load(storage: storage);
    expect(reopened.settings.defaultPlanMinutes, 90);
    reopened.dispose();

    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增计划'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('plan_minutes')))
          .controller!
          .text,
      '90',
    );
    await tester.enterText(find.byKey(const ValueKey('plan_name')), '阅读');
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(plans.plans.last.plannedMinutes, 90);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('恢复默认设置'), 200);
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(settings.settings.defaultPlanMinutes, 60);
    expect(plans.plans.length, 5);
    expect(plans.plans.last.name, '阅读');
  });

  test('daily reset time persists and controls the study date', () async {
    final storage = _MemorySettingsStorage();
    final settings = await SettingsStore.load(storage: storage);
    addTearDown(settings.dispose);
    settings.update(settings.settings.copyWith(dailyResetHour: 4));
    expect(await settings.flush(), isTrue);
    final reopened = await SettingsStore.load(storage: storage);
    addTearDown(reopened.dispose);
    expect(reopened.settings.dailyResetHour, 4);
    var now = DateTime(2026, 9, 29, 2);
    final plans = StudyPlanStore(settings: reopened, now: () => now);
    addTearDown(plans.dispose);
    plans.startOrResume('default_japanese');
    plans.studyOneSecond('default_japanese');
    expect(plans.planById('default_japanese')!.progressDay, '2026-09-28');
    now = DateTime(2026, 9, 29, 3, 59);
    plans.refreshForToday();
    expect(plans.planById('default_japanese')!.studiedSeconds, 1);
    now = DateTime(2026, 9, 29, 4);
    plans.refreshForToday();
    expect(plans.planById('default_japanese')!.studiedSeconds, 0);
    expect(plans.records.single.date, '2026-09-28');
  });

  testWidgets(
    'clearing study data retains plans; clearing all resets everything',
    (tester) async {
      final settings = SettingsStore();
      final plans = StudyPlanStore(settings: settings);
      addTearDown(plans.dispose);
      addTearDown(settings.dispose);
      plans.addPlan(name: '阅读', iconId: 'book', plannedMinutes: 90);
      final id = plans.plans.last.id;
      plans.startOrResume(id);
      plans.studyOneSecond(id);
      settings.update(settings.settings.copyWith(themeMode: ThemeMode.dark));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(settings: settings, plans: plans),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('清空学习数据'), 200);
      await tester.tap(find.text('清空学习数据'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '清空学习数据'));
      await tester.pumpAndSettle();
      expect(plans.plans.last.id, id);
      expect(plans.plans.last.plannedMinutes, 90);
      expect(plans.plans.last.studiedSeconds, 0);
      expect(plans.records, isEmpty);
      expect(settings.settings.themeMode, ThemeMode.dark);

      await tester.scrollUntilVisible(find.text('清空全部数据'), 200);
      await tester.tap(find.text('清空全部数据'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认清空'));
      await tester.pumpAndSettle();
      expect(plans.plans.length, 4);
      expect(plans.plans.any((plan) => plan.id == id), isFalse);
      expect(plans.records, isEmpty);
      expect(settings.settings.themeMode, ThemeMode.system);
    },
  );

  testWidgets('delete without confirmation can be undone', (tester) async {
    final settings = SettingsStore();
    final plans = StudyPlanStore(settings: settings);
    addTearDown(plans.dispose);
    addTearDown(settings.dispose);
    settings.update(settings.settings.copyWith(confirmBeforeDelete: false));
    await tester.pumpWidget(
      MaterialApp(
        home: PlanManagementPage(store: plans, settings: settings),
      ),
    );
    await tester.tap(find.byTooltip('删除日语计划'));
    await tester.pumpAndSettle();
    expect(plans.plans.length, 3);
    expect(find.text('确定删除“日语”计划吗？'), findsNothing);
    await tester.tap(find.text('撤销'));
    await tester.pump();
    expect(plans.plans.length, 4);
    expect(plans.plans.first.id, 'default_japanese');
  });

  testWidgets('hiding seconds keeps internal timing accurate', (tester) async {
    final settings = SettingsStore();
    final plans = StudyPlanStore(settings: settings);
    addTearDown(plans.dispose);
    addTearDown(settings.dispose);
    settings.update(settings.settings.copyWith(showSeconds: false));
    await tester.pumpWidget(
      MaterialApp(
        home: StudyTimerPage(
          store: plans,
          planId: 'default_japanese',
          settings: settings,
        ),
      ),
    );
    expect(find.text('60 分钟'), findsOneWidget);
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(plans.planById('default_japanese')!.remainingSeconds, 3599);
    expect(plans.planById('default_japanese')!.studiedSeconds, 1);
    expect(find.text('60 分钟'), findsOneWidget);
  });

  testWidgets('completion alert setting controls the in-app notice', (
    tester,
  ) async {
    final settings = SettingsStore();
    final plans = StudyPlanStore(settings: settings);
    addTearDown(plans.dispose);
    addTearDown(settings.dispose);
    settings.update(settings.settings.copyWith(completionAlertEnabled: false));
    plans.updatePlan(
      plans.planById('default_japanese')!.copyWith(plannedMinutes: 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudyTimerPage(
          store: plans,
          planId: 'default_japanese',
          settings: settings,
        ),
      ),
    );
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('今日计划已完成'), findsOneWidget);
    expect(find.text('太棒了，今日学习计划完成！'), findsNothing);

    plans.addPlan(name: '阅读', iconId: 'book', plannedMinutes: 1);
    settings.update(settings.settings.copyWith(completionAlertEnabled: true));
    await tester.pumpWidget(
      MaterialApp(
        home: StudyTimerPage(
          store: plans,
          planId: plans.plans.last.id,
          settings: settings,
        ),
      ),
    );
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('太棒了，今日学习计划完成！'), findsOneWidget);
  });
}
