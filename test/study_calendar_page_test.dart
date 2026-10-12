import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/main.dart';
import 'package:hello_app/l10n/app_localizations_en.dart';
import 'package:hello_app/services/timer_alert_service.dart';
import 'package:hello_app/models/study_scheme.dart';
import 'package:hello_app/models/app_settings.dart';
import 'package:hello_app/pages/plan_edit_page.dart';
import 'package:hello_app/pages/plan_management_page.dart';
import 'package:hello_app/pages/scheme_management_page.dart';
import 'package:hello_app/pages/study_calendar_page.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_statistics_page.dart';
import 'package:hello_app/pages/weekly_schedule_page.dart';

import 'support/daily_study_fixtures.dart';
import 'support/localized_app.dart';

class _NotificationTestPlayer extends Fake implements AudioPlayer {
  @override
  Future<void> dispose() async {}
}

DailyHarness _h() {
  final h = DailyHarness()..now = DateTime(2026, 10, 12, 12);
  addTearDown(h.dispose);
  return h;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      key.startsWith('schedule_day_') ? 300 : -300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (Platform.environment['TIMEMANAGER_UI_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('schedule_preview')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final directory = Directory('build/ui-previews')
      ..createSync(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    mockDailyAudio();
    if (Platform.environment['TIMEMANAGER_UI_PREVIEW'] != '1') return;
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    final windows = Platform.environment['WINDIR'];
    if (windows == null) return;
    final file = File('$windows/Fonts/msyh.ttc');
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    for (final family in ['Ahem', 'Roboto']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  testWidgets(
    'bottom calendar entry and home switching show only active tasks',
    (tester) async {
      final h = _h();
      final scheme = h.store.addScheme('周末方案');
      h.store.addPlan(
        name: '周末阅读',
        iconId: 'book',
        plannedSeconds: 300,
        schemeId: scheme.id,
      );
      h.store.startOrResume(h.id);
      h.store.studySeconds(h.id, 60);
      await tester.pumpWidget(
        localizedApp(
          home: StudyHomePage(store: h.store, settings: h.settings),
        ),
      );
      await _tap(tester, 'switch_today_scheme');
      await _tap(tester, 'pick_scheme_${scheme.id}');
      expect(h.store.todaySchemeId, scheme.id);
      expect(find.byKey(ValueKey('home_plan_${h.id}')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('home_studied_total')))
            .data,
        '01:00',
      );
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(StudyCalendarPage), findsOneWidget);
      expect(find.byKey(const ValueKey('manage_schemes')), findsNothing);
      expect(find.text('批量管理'), findsOneWidget);
      expect(find.text('编辑任务'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final restDay in [false, true]) {
    testWidgets(
      'home management edits any scheme and its tasks, rest day $restDay',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = _h();
        final scheme = h.store.addScheme('周末');
        if (restDay) h.store.assignDates([h.store.studyDate], null);
        final todayScheme = h.store.todaySchemeId;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('schedule_preview'),
            child: localizedApp(
              home: StudyHomePage(store: h.store, settings: h.settings),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!restDay) await _capture(tester, 'home_management_entry');
        await _tap(tester, 'home_manage_plans');
        expect(find.byType(SchemeManagementPage), findsOneWidget);
        expect(find.byType(PlanManagementPage), findsNothing);
        expect(
          find.byKey(ValueKey('edit_scheme_${scheme.id}')),
          findsOneWidget,
        );
        if (!restDay) await _capture(tester, 'home_scheme_management');
        await _tap(tester, 'scheme_menu_${scheme.id}');
        await tester.tap(find.text('重命名方案'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('scheme_name')),
          '周末阅读',
        );
        await _tap(tester, 'save_scheme_name');
        expect(h.store.schemeById(scheme.id)!.name, '周末阅读');
        await _tap(tester, 'edit_scheme_${scheme.id}');
        expect(find.byType(PlanManagementPage), findsOneWidget);
        await _tap(tester, 'management_empty_add');
        await tester.enterText(find.byKey(const ValueKey('plan_name')), '周末数学');
        await _tap(tester, 'save_plan');
        expect(h.store.plansForScheme(scheme.id).single.name, '周末数学');
        expect(h.store.todaySchemeId, todayScheme);
        expect(h.store.plansForScheme(defaultStudySchemeId).single.id, h.id);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'batch dates override weekly rules and can restore or become rest days',
    (tester) async {
      final h = _h();
      final scheme = h.store.addScheme('假期');
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: StudyCalendarPage(store: h.store, settings: h.settings),
          ),
        ),
      );
      await _tap(tester, 'select_schedule_dates');
      expect(find.text('已选择 0 个日期'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('assign_batch_dates')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('schedule_day_2026-10-11')),
            )
            .onPressed,
        isNull,
      );
      await _tap(tester, 'schedule_day_2026-10-13');
      await _tap(tester, 'schedule_day_2026-10-15');
      await _tap(tester, 'assign_batch_dates');
      await _tap(tester, 'pick_scheme_${scheme.id}');
      expect(h.store.dateOverrides, {
        '2026-10-13': scheme.id,
        '2026-10-15': scheme.id,
      });
      expect(find.text('安排已保存'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('assign_batch_dates')).hitTestable(),
        findsOneWidget,
      );
      await _tap(tester, 'assign_batch_dates');
      await _tap(tester, 'pick_scheme_rest');
      expect(h.store.schemeIdOn(DateTime(2026, 10, 13)), isNull);
      await _tap(tester, 'restore_batch_dates');
      expect(h.store.dateOverrides, isEmpty);
      expect(h.store.schemeIdOn(DateTime(2026, 10, 15)), defaultStudySchemeId);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('weekly workdays and weekends have independent assignments', (
    tester,
  ) async {
    final h = _h();
    final scheme = h.store.addScheme('周末');
    await tester.pumpWidget(
      localizedApp(
        home: WeeklySchedulePage(store: h.store, settings: h.settings),
      ),
    );
    await _tap(tester, 'assign_weekends');
    await _tap(tester, 'pick_scheme_${scheme.id}');
    expect(h.store.weeklyAssignments[6], scheme.id);
    expect(h.store.weeklyAssignments[7], scheme.id);
    expect(h.store.weeklyAssignments[1], defaultStudySchemeId);
    await _tap(tester, 'weekly_day_1');
    await _tap(tester, 'pick_scheme_rest');
    expect(h.store.todaySchemeId, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'batch selection spans months and clearing or exiting resets it',
    (tester) async {
      final h = _h();
      final scheme = h.store.addScheme('假期');
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: StudyCalendarPage(store: h.store, settings: h.settings),
          ),
        ),
      );
      await _tap(tester, 'select_schedule_dates');
      await _tap(tester, 'schedule_day_2026-10-13');
      await _tap(tester, 'schedule_next_month');
      await _tap(tester, 'schedule_day_2026-11-01');
      expect(find.text('已选择 2 个日期'), findsOneWidget);
      await _tap(tester, 'assign_batch_dates');
      await _tap(tester, 'pick_scheme_${scheme.id}');
      expect(h.store.dateOverrides, {
        '2026-10-13': scheme.id,
        '2026-11-01': scheme.id,
      });
      await _tap(tester, 'clear_schedule_selection');
      expect(find.text('已选择 0 个日期'), findsOneWidget);
      await _tap(tester, 'schedule_day_2026-11-02');
      await _tap(tester, 'select_schedule_dates');
      expect(
        find.byKey(const ValueKey('schedule_batch_actions')),
        findsNothing,
      );
      await _tap(tester, 'select_schedule_dates');
      expect(find.text('已选择 0 个日期'), findsOneWidget);
      expect(h.store.dateOverrides.length, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('range picker assigns every day in an inclusive range', (
    tester,
  ) async {
    final h = _h();
    final scheme = h.store.addScheme('假期');
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: StudyCalendarPage(store: h.store, settings: h.settings),
        ),
      ),
    );
    await _tap(tester, 'select_schedule_dates');
    await _tap(tester, 'select_schedule_range');
    await tester.tap(
      find
          .descendant(
            of: find.byType(DateRangePickerDialog),
            matching: find.text('13'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(DateRangePickerDialog),
            matching: find.text('15'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 3 个日期'), findsOneWidget);
    await _tap(tester, 'assign_batch_dates');
    await _tap(tester, 'pick_scheme_${scheme.id}');
    expect(h.store.dateOverrides, {
      '2026-10-13': scheme.id,
      '2026-10-14': scheme.id,
      '2026-10-15': scheme.id,
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancelling a batch picker keeps assignments and selection', (
    tester,
  ) async {
    final h = _h();
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: StudyCalendarPage(store: h.store, settings: h.settings),
        ),
      ),
    );
    await _tap(tester, 'select_schedule_dates');
    await _tap(tester, 'schedule_day_2026-10-13');
    await _tap(tester, 'select_schedule_range');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 个日期'), findsOneWidget);
    await _tap(tester, 'assign_batch_dates');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(h.store.dateOverrides, isEmpty);
    expect(find.text('已选择 1 个日期'), findsOneWidget);
    expect(find.text('安排已保存'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in ['zh', 'en']) {
    testWidgets(
      'failed batch saving retains selection and retry updates feedback $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = _h();
        await tester.runAsync(h.store.flush);
        h.planStorage.failWrites = true;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('schedule_preview'),
            child: localizedApp(
              locale: Locale(locale),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 844),
                  textScaler: TextScaler.linear(locale == 'en' ? 1.5 : 1),
                ),
                child: StudyHomePage(store: h.store, settings: h.settings),
              ),
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.calendar_month_outlined));
        await tester.pumpAndSettle();
        await _tap(tester, 'select_schedule_dates');
        await _tap(tester, 'schedule_day_2026-10-13');
        await _tap(tester, 'assign_batch_dates');
        await _tap(tester, 'pick_scheme_rest');
        expect(h.store.hasSaveError, isTrue);
        final countLabel = locale == 'zh' ? '已选择 1 个日期' : '1 dates selected';
        final savedLabel = locale == 'zh' ? '安排已保存' : 'Schedule saved';
        expect(find.text(countLabel), findsOneWidget);
        expect(find.text(savedLabel), findsNothing);
        expect(
          find.byKey(const ValueKey('assign_batch_dates')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _capture(tester, 'schedule_batch_failed_$locale');
        h.planStorage.failWrites = false;
        await _tap(tester, 'retry_save');
        expect(h.store.hasSaveError, isFalse);
        expect(h.store.hasUnsavedChanges, isFalse);
        expect(h.planStorage.value, contains('2026-10-13'));
        expect(find.text(savedLabel), findsOneWidget);
        expect(find.text(countLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'narrow previews are read only and batch actions stay visible while scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = _h();
      final scheme = h.store.addScheme('周末');
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('schedule_preview'),
          child: localizedApp(
            home: Scaffold(
              body: StudyCalendarPage(store: h.store, settings: h.settings),
            ),
          ),
        ),
      );
      await _tap(tester, 'schedule_day_2026-10-13');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('preview_assign_day')), findsNothing);
      expect(find.text('编辑任务'), findsNothing);
      expect(find.text('分配方案'), findsNothing);
      expect(h.store.dateOverrides, isEmpty);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await _tap(tester, 'select_schedule_dates');
      await _tap(tester, 'schedule_day_2026-10-13');
      final actions = find.byKey(const ValueKey('schedule_batch_actions'));
      final originalRect = tester.getRect(actions);
      await _tap(tester, 'schedule_day_2026-10-31');
      await _tap(tester, 'schedule_day_2026-10-31');
      expect(tester.getRect(actions), originalRect);
      expect(
        find.byKey(const ValueKey('assign_batch_dates')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('select_schedule_dates')).hitTestable(),
        findsOneWidget,
      );
      await _capture(tester, 'schedule_batch_narrow');
      await tester.tap(find.byKey(const ValueKey('assign_batch_dates')));
      await tester.pumpAndSettle();
      await _tap(tester, 'pick_scheme_${scheme.id}');
      expect(h.store.schemeIdOn(DateTime(2026, 10, 13)), scheme.id);
      expect(h.store.dateOverrides.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('calendar cancellation invalidates a pending request in another alert service', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final enabled = Completer<bool>();
    final reached = Completer<void>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'areNotificationsEnabled') {
        if (!reached.isCompleted) reached.complete();
        return enabled.future;
      }
      return true;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
    final h = _h();
    h.store.beginRunning(h.id);
    final scheduler = TimerAlertService(player: _NotificationTestPlayer());
    final canceller = TimerAlertService(player: _NotificationTestPlayer());
    final pending = scheduler.scheduleBackgroundCompletion(
      plan: h.plan,
      settings: const AppSettings(),
      l10n: AppLocalizationsEn(),
    );
    await reached.future.timeout(const Duration(seconds: 10));
    expect(reached.isCompleted, isTrue);
    await canceller
        .cancelBackgroundCompletion(h.plan.sessionId!)
        .timeout(const Duration(seconds: 5));
    enabled.complete(true);
    expect(await pending.timeout(const Duration(seconds: 5)), isFalse);
    expect(calls, contains('cancel'));
    expect(calls, isNot(contains('zonedSchedule')));
    await scheduler.dispose();
    await canceller.dispose();
  });

  testWidgets('scheme creation and task editing stay scoped to that scheme', (
    tester,
  ) async {
    final h = _h();
    await tester.pumpWidget(
      localizedApp(
        home: SchemeManagementPage(store: h.store, settings: h.settings),
      ),
    );
    await _tap(tester, 'add_scheme');
    await tester.enterText(find.byKey(const ValueKey('scheme_name')), '周末');
    await _tap(tester, 'save_scheme_name');
    expect(find.byType(PlanManagementPage), findsOneWidget);
    final id = h.store.schemes.last.id;
    await _tap(tester, 'management_empty_add');
    expect(find.byType(PlanEditPage), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('plan_name')), '周末数学');
    await _tap(tester, 'save_plan');
    expect(h.store.plansForScheme(id).single.name, '周末数学');
    expect(h.store.todayPlans.single.id, h.id);
    expect(find.text(h.plan.name), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'actual today total includes other schemes while completion uses current target',
    (tester) async {
      final h = _h();
      h.store.startOrResume(h.id);
      h.store.studySeconds(h.id, 60);
      final scheme = h.store.addScheme('周末');
      final task = h.store.addPlan(
        name: '数学',
        iconId: 'book',
        plannedSeconds: 120,
        schemeId: scheme.id,
      );
      h.store.assignDates([h.now], scheme.id);
      h.store.startOrResume(task.id);
      h.store.studySeconds(task.id, 30);
      await tester.pumpWidget(
        localizedApp(home: StudyStatisticsPage(store: h.store)),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('statistics_studied_total')),
            )
            .data,
        '01:30',
      );
      expect(find.text('当前方案完成度 25%'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('other_study_2026-10-12_${h.id}')),
        300,
      );
      expect(find.text('今日其他已学任务'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('root cancels reminders for invalidated scheme sessions', (
    tester,
  ) async {
    final h = DailyHarness()..now = DateTime(2026, 10, 12, 12);
    await tester.pumpWidget(
      MyApp(store: h.store, settings: h.settings, scheduleAlerts: h.alerts),
    );
    h.store.beginRunning(h.id);
    final id = h.plan.sessionId!;
    h.advance(5);
    h.store.assignDates([h.now], null);
    await tester.pumpAndSettle();
    expect(h.alerts.cancelled, contains(id));
    expect(h.store.todayStudiedSeconds, 5);
    expect(find.textContaining('休息日'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('old timer page cannot restart an inactive scheme', (
    tester,
  ) async {
    final h = _h();
    await openDailyTimer(tester, h);
    h.advance(5);
    final other = h.store.addScheme('另一套');
    h.store.assignDates([h.now], other.id);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('学习日期或方案已变化'), findsOneWidget);
    expect(find.byKey(const ValueKey('timer_main_action')), findsNothing);
    expect(h.plan.isRunning, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 390.0]) {
    for (final locale in ['zh', 'en']) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final scale in [1.0, 1.5]) {
          testWidgets(
            'calendar layout $width $locale ${brightness.name} font $scale',
            (tester) async {
              tester.view.physicalSize = Size(width, 844);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final h = _h();
              final scheme = h.store.addScheme(
                'Weekend scheme with a long descriptive name',
              );
              h.store.setWeeklyAssignments({6: scheme.id, 7: scheme.id});
              await tester.pumpWidget(
                RepaintBoundary(
                  key: const ValueKey('schedule_preview'),
                  child: localizedApp(
                    locale: Locale(locale),
                    brightness: brightness,
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: Size(width, 844),
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: StudyHomePage(
                        store: h.store,
                        settings: h.settings,
                      ),
                    ),
                  ),
                ),
              );
              await tester.tap(find.byIcon(Icons.calendar_month_outlined));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await _capture(
                tester,
                'schedule_${width.toInt()}_${locale}_${brightness.name}_$scale',
              );
              await _tap(tester, 'schedule_day_2026-10-11');
              final hint = find.text(
                locale == 'zh' ? '过去日期展示实际学习记录，不能重新排期。' : 'Past dates show actual study records and cannot be rescheduled.',
              );
              if (hint.evaluate().isEmpty) {
                await tester.scrollUntilVisible(
                  hint,
                  400,
                  scrollable: find.byType(Scrollable).last,
                  maxScrolls: 50,
                );
              }
              await tester.ensureVisible(hint);
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('assign_selected_day')),
                findsNothing,
              );
              expect(tester.takeException(), isNull);
              if (find.byType(BottomSheet).evaluate().isNotEmpty) {
                await tester.tapAt(const Offset(10, 10));
                await tester.pumpAndSettle();
              }
              await _tap(tester, 'select_schedule_dates');
              await _tap(tester, 'schedule_day_2026-10-13');
              expect(
                find.byKey(const ValueKey('assign_batch_dates')).hitTestable(),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
              await _capture(
                tester,
                'schedule_batch_${width.toInt()}_${locale}_${brightness.name}_$scale',
              );
              await tester.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }
  }
}
