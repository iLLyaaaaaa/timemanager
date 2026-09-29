import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/main.dart';
import 'package:hello_app/pages/settings_page.dart';
import 'package:hello_app/pages/study_home_page.dart';

class _MemorySettingsStorage implements AppSettingsStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String snapshot) async {
    value = snapshot;
  }
}

void main() {
  test(
    'legacy settings migrate minutes to seconds and keep other choices',
    () async {
      final storage = _MemorySettingsStorage()
        ..value = jsonEncode({
          'themeMode': 'dark',
          'defaultPlanMinutes': 90,
          'showSeconds': false,
          'dailyResetHour': 4,
          'dailyResetMinute': 30,
          'confirmBeforeDelete': false,
          'completionAlertEnabled': false,
        });
      final settings = await SettingsStore.load(storage: storage);
      addTearDown(settings.dispose);
      expect(settings.settings.defaultPlanSeconds, 5400);
      expect(settings.settings.themeMode, ThemeMode.dark);
      expect(settings.settings.dailyResetHour, 4);
      expect(settings.settings.dailyResetMinute, 30);
      expect(settings.settings.confirmBeforeDelete, isFalse);
      expect(settings.settings.completionAlertEnabled, isFalse);
      expect(settings.settings.homeHeadline, '每天进步一点点');
      expect(await settings.flush(), isTrue);
      expect(jsonDecode(storage.value!)['version'], 2);
      expect(jsonDecode(storage.value!)['showSeconds'], isNull);
    },
  );

  test('unknown settings version is not overwritten', () async {
    final storage = _MemorySettingsStorage()..value = '{"version":99}';
    final settings = await SettingsStore.load(storage: storage);
    addTearDown(settings.dispose);
    await settings.flush();
    expect(storage.value, '{"version":99}');
  });

  testWidgets('theme changes immediately and survives reload', (tester) async {
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
    expect(await settings.flush(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    final reopened = await SettingsStore.load(storage: storage);
    addTearDown(reopened.dispose);
    expect(reopened.settings.themeMode, ThemeMode.dark);
  });

  testWidgets('home headline edits immediately and survives reload', (
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
    expect(find.text('每天进步一点点'), findsOneWidget);
    await tester.tap(find.byTooltip('编辑首页文案'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('home_headline_input')),
      '   ',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('请输入一句简短文案'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('home_headline_input')),
      '专注每一天',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('专注每一天'), findsOneWidget);
    expect(await settings.flush(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    final reopened = await SettingsStore.load(storage: storage);
    addTearDown(reopened.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: StudyHomePage(store: plans, settings: reopened),
      ),
    );
    expect(find.text('专注每一天'), findsOneWidget);
  });

  testWidgets('default seconds prefill new plans and restore keeps plans', (
    tester,
  ) async {
    final settings = SettingsStore();
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
    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增计划默认时长'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('duration_minutes')), '1');
    await tester.enterText(
      find.byKey(const ValueKey('duration_seconds')),
      '30',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(settings.settings.defaultPlanSeconds, 3690);
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增计划'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('duration_seconds')))
          .controller!
          .text,
      '30',
    );
    await tester.enterText(find.byKey(const ValueKey('plan_name')), '阅读');
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(plans.plans.single.plannedSeconds, 3690);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(settings.settings.defaultPlanSeconds, 3600);
    expect(plans.plans.single.name, '阅读');
  });

  test('daily reset setting changes study date', () {
    final settings = SettingsStore();
    addTearDown(settings.dispose);
    settings.update(settings.settings.copyWith(dailyResetHour: 4));
    var now = DateTime(2026, 9, 29, 2);
    final plans = StudyPlanStore(settings: settings, now: () => now);
    addTearDown(plans.dispose);
    plans.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    final id = plans.plans.single.id;
    plans.startOrResume(id);
    plans.studyOneSecond(id);
    expect(plans.plans.single.progressDay, '2026-09-28');
    now = DateTime(2026, 9, 29, 4);
    plans.refreshForToday();
    expect(plans.plans.single.studiedSeconds, 0);
    expect(plans.records.single.date, '2026-09-28');
  });

  testWidgets('clear learning retains plans and clear all empties them', (
    tester,
  ) async {
    final settings = SettingsStore();
    final plans = StudyPlanStore(settings: settings);
    addTearDown(plans.dispose);
    addTearDown(settings.dispose);
    plans.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    plans.startOrResume(plans.plans.single.id);
    plans.studyOneSecond(plans.plans.single.id);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(settings: settings, plans: plans),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空学习数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清空学习数据'));
    await tester.pumpAndSettle();
    expect(plans.plans.single.plannedSeconds, 90);
    expect(plans.plans.single.studiedSeconds, 0);
    expect(plans.records, isEmpty);
    await tester.scrollUntilVisible(find.text('清空全部数据'), 200);
    await tester.tap(find.text('清空全部数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清空'));
    await tester.pumpAndSettle();
    expect(plans.plans, isEmpty);
  });
}
