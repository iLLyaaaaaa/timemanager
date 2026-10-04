import 'support/localized_app.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _FakePreferences implements SharedPreferencesAsync {
  _FakePreferences(this.values);
  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'custom sound selection persists and old settings retain built-in default',
    () async {
      final storage = _MemorySettingsStorage();
      final settings = await SettingsStore.load(storage: storage);
      addTearDown(settings.dispose);
      settings.update(
        settings.settings.copyWith(
          soundSource: 'custom',
          customSoundPath: '/app/custom_sounds/example.mp3',
          customSoundName: 'example.mp3',
        ),
      );
      expect(await settings.flush(), isTrue);
      final reopened = await SettingsStore.load(storage: storage);
      addTearDown(reopened.dispose);
      expect(reopened.settings.soundSource, 'custom');
      expect(reopened.settings.customSoundName, 'example.mp3');
      reopened.restoreDefaults();
      expect(reopened.settings.soundSource, 'builtin');
      expect(reopened.settings.customSoundPath, isNull);
    },
  );
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
      expect(jsonDecode(storage.value!)['version'], 4);
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

  test('version 2 settings gain language and alert defaults', () async {
    final storage = _MemorySettingsStorage()
      ..value = jsonEncode({
        'version': 2,
        'themeMode': 'dark',
        'homeHeadline': '专注每一天',
        'defaultPlanSeconds': 5400,
      });
    final settings = await SettingsStore.load(storage: storage);
    addTearDown(settings.dispose);
    expect(settings.settings.localeCode, 'zh');
    expect(settings.settings.timerAlertMode, 'sound');
    expect(settings.settings.selectedAlertSound, 1);
    expect(settings.settings.homeHeadline, '专注每一天');
    expect(settings.settings.defaultPlanSeconds, 5400);
    expect(await settings.flush(), isTrue);
    expect(jsonDecode(storage.value!)['version'], 4);
  });

  test('SharedPreferences retains v2 snapshot as a migration backup', () async {
    final old = jsonEncode({
      'version': 2,
      'themeMode': 'dark',
      'homeHeadline': '我的目标',
      'defaultPlanSeconds': 4200,
    });
    final preferences = _FakePreferences({'app_settings_v2': old});
    final storage = SharedPreferencesSettingsStorage(preferences: preferences);
    final settings = await SettingsStore.load(storage: storage);
    addTearDown(settings.dispose);
    expect(settings.settings.homeHeadline, '我的目标');
    expect(settings.settings.homeHeadlineCustomized, isTrue);
    expect(await settings.flush(), isTrue);
    expect(preferences.values['app_settings_v2'], old);
    expect(
      jsonDecode(preferences.values['app_settings_v4']!)['localeCode'],
      'zh',
    );
  });

  testWidgets(
    'language switches both ways and persists without translating user data',
    (tester) async {
      final storage = _MemorySettingsStorage();
      final settings = await SettingsStore.load(storage: storage);
      settings.update(settings.settings.copyWith(homeHeadline: '专注每一天'));
      final plans = StudyPlanStore(settings: settings);
      plans.addPlan(name: '高等数学', iconId: 'calculate', plannedSeconds: 90);
      await tester.pumpWidget(MyApp(store: plans, settings: settings));
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('语言'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Theme Mode'), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('高等数学'), findsOneWidget);
      expect(find.text('专注每一天'), findsOneWidget);
      expect(find.text('Manage Plans'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('简体中文'));
      await tester.pumpAndSettle();
      expect(find.text('主题模式'), findsOneWidget);
      await tester.tap(find.text('语言'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(await settings.flush(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      final reopened = await SettingsStore.load(storage: storage);
      addTearDown(reopened.dispose);
      expect(reopened.settings.localeCode, 'en');
      expect(reopened.settings.homeHeadline, '专注每一天');
    },
  );

  test(
    'alert mode and chosen sound survive reload and defaults restore',
    () async {
      final storage = _MemorySettingsStorage();
      final settings = await SettingsStore.load(storage: storage);
      addTearDown(settings.dispose);
      settings.update(
        settings.settings.copyWith(
          timerAlertMode: 'vibration',
          selectedAlertSound: 4,
          localeCode: 'en',
        ),
      );
      expect(await settings.flush(), isTrue);
      final reopened = await SettingsStore.load(storage: storage);
      addTearDown(reopened.dispose);
      expect(reopened.settings.timerAlertMode, 'vibration');
      expect(reopened.settings.selectedAlertSound, 4);
      expect(reopened.settings.localeCode, 'en');
      reopened.restoreDefaults();
      expect(reopened.settings.timerAlertMode, 'sound');
      expect(reopened.settings.selectedAlertSound, 1);
      expect(reopened.settings.localeCode, 'zh');
    },
  );

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
      localizedApp(
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
      localizedApp(
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
      localizedApp(
        home: StudyHomePage(store: plans, settings: settings),
      ),
    );
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('新增计划默认时长'), 200);
    await tester.ensureVisible(find.text('新增计划默认时长'));
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
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('恢复默认设置'), 200);
    await tester.ensureVisible(find.text('恢复默认设置'));
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
      localizedApp(
        home: Scaffold(
          body: SettingsPage(settings: settings, plans: plans),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('清空学习数据'), 200);
    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空学习数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清空学习数据'));
    await tester.pumpAndSettle();
    expect(plans.plans.single.plannedSeconds, 90);
    expect(plans.plans.single.studiedSeconds, 0);
    expect(plans.records, isEmpty);
    await tester.scrollUntilVisible(find.text('清空全部数据'), 200);
    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空全部数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清空'));
    await tester.pumpAndSettle();
    expect(plans.plans, isEmpty);
  });
}
