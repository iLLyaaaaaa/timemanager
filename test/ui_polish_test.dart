import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_storage.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/main.dart';
import 'package:hello_app/models/study_record.dart';
import 'package:hello_app/pages/plan_edit_page.dart';
import 'package:hello_app/pages/plan_management_page.dart';
import 'package:hello_app/pages/settings_page.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_statistics_page.dart';
import 'package:hello_app/pages/study_review_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';
import 'package:hello_app/services/timer_alert_service.dart';
import 'package:hello_app/utils/study_history.dart';
import 'package:hello_app/widgets/study_history_view.dart';

import 'support/localized_app.dart';

class _SettingsMemory implements AppSettingsStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _UnreadablePlans implements StudyPlanStorage {
  @override
  Future<String?> read() async => '{"version":99,"plans":[]}';
  @override
  Future<void> write(String value) async =>
      fail('Invalid data must not be overwritten');
}

class _Alerts extends TimerAlertService {
  final previews = <int>[];
  int stops = 0;
  @override
  Future<bool> notificationsEnabled() async => true;
  @override
  Future<bool> exactAlarmsEnabled() async => true;
  @override
  Future<void> preview(int sound) async => previews.add(sound);
  @override
  Future<void> stopPreview() async => stops++;
}

final _previewEnabled = Platform.environment['TIMEMANAGER_UI_PREVIEW'] == '1';
const _previewKey = ValueKey('ui_preview');

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_previewEnabled) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_previewKey),
    );
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _checkScroll(WidgetTester tester, {Finder? scrollable}) async {
  final scroll = scrollable ?? find.byType(Scrollable).first;
  for (var step = 0; step < 16; step++) {
    final position = tester.state<ScrollableState>(scroll).position;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!_previewEnabled) return;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final playerId = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$playerId'),
            (_) async => null,
          );
        }
        return null;
      },
    );
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    // Use a locally installed font only for optional screenshots, never bundle it.
    final windows = Platform.environment['WINDIR'];
    if (windows == null) return;
    final file = File('$windows/Fonts/msyh.ttc');
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    for (final family in ['Ahem', 'Roboto']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  });

  testWidgets('home add shortcuts preserve defaults and update overview', (
    tester,
  ) async {
    final settings = SettingsStore();
    settings.update(settings.settings.copyWith(defaultPlanSeconds: 90));
    final store = StudyPlanStore(settings: settings);
    await tester.pumpWidget(MyApp(store: store, settings: settings));
    for (final (key, name) in [
      ('empty_add_plan', '阅读'),
      ('home_add_plan', 'Python'),
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(find.byType(PlanEditPage), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('plan_name')), name);
      await tester.tap(find.text('保存计划'));
      await tester.pumpAndSettle();
      expect(store.plans.last.plannedSeconds, 90);
    }
    store.startOrResume(store.plans.first.id);
    store.studySeconds(store.plans.first.id, 90);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home_studied_total')))
          .data,
      '01:30',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home_completed_total')))
          .data,
      '1 / 2',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unreadable plans remain an error rather than an empty state', (
    tester,
  ) async {
    final store = await StudyPlanStore.load(storage: _UnreadablePlans());
    await tester.pumpWidget(MyApp(store: store));
    expect(find.byKey(const ValueKey('empty_add_plan')), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('home_add_plan')))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('读取'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sound sheet selection persists and closing stops preview', (
    tester,
  ) async {
    final memory = _SettingsMemory();
    final settings = await SettingsStore.load(storage: memory);
    final store = StudyPlanStore(settings: settings);
    final alerts = _Alerts();
    addTearDown(settings.dispose);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SettingsPage(settings: settings, plans: store, alerts: alerts),
        ),
      ),
    );
    final picker = find.byKey(const ValueKey('open_sound_picker'));
    await tester.scrollUntilVisible(picker, 200);
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final sound = find.byKey(const ValueKey('alert_sound_3'));
    await tester.tap(sound);
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(sound).selected, isTrue);
    await tester.tap(
      find.descendant(of: sound, matching: find.byTooltip('试听')),
    );
    await tester.pump();
    expect(alerts.previews, [3]);
    final stops = alerts.stops;
    await tester.tap(find.byKey(const ValueKey('close_sound_picker')));
    await tester.pumpAndSettle();
    expect(alerts.stops, greaterThan(stops));
    expect(find.byType(BottomSheet), findsNothing);
    expect(await settings.flush(), isTrue);
    final reopened = await SettingsStore.load(storage: memory);
    addTearDown(reopened.dispose);
    expect(reopened.settings.selectedAlertSound, 3);
    expect(reopened.settings.soundSource, 'builtin');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('history bars compare actual durations without changing totals', (
    tester,
  ) async {
    final summary = StudyHistorySummary.recentWeek(
      lastDay: DateTime(2026, 10, 4),
      records: [
        const StudyRecord(
          id: 'a',
          planId: 'one',
          date: '2026-10-04',
          plannedSeconds: 30,
          studiedSeconds: 60,
        ),
        const StudyRecord(
          id: 'b',
          planId: 'deleted',
          date: '2026-10-03',
          plannedSeconds: 30,
          studiedSeconds: 120,
        ),
      ],
    );
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudyHistoryView(summary: summary),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('history_bar_2026-10-04')),
          )
          .value,
      0.5,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('history_bar_2026-10-03')),
          )
          .value,
      1,
    );
    expect(summary.totalStudiedSeconds, 180);
  });

  testWidgets(
    'timer respects reduced motion and retains the 60dp main control',
    (tester) async {
      final store = StudyPlanStore();
      addTearDown(store.dispose);
      store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
      await tester.pumpWidget(
        localizedApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              disableAnimations: true,
            ),
            child: StudyTimerPage(
              store: store,
              planId: store.plans.single.id,
              alerts: _Alerts(),
            ),
          ),
        ),
      );
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
      expect(find.text('未开始'), findsOneWidget);
      final control = find.ancestor(
        of: find.text('开始'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(tester.getSize(control.first).height, 60);
      await tester.pump(const Duration(seconds: 3));
      expect(store.plans.single.hasStartedToday, isFalse);
      expect(store.plans.single.studiedSeconds, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final locale in ['zh', 'en']) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final scale in [1.0, 1.5]) {
          testWidgets(
            'major pages fit $width $locale ${brightness.name} scale $scale',
            (tester) async {
              tester.view.physicalSize = Size(width, 844);
              tester.view.devicePixelRatio = 1;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(() {
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
                tester.platformDispatcher.clearTextScaleFactorTestValue();
              });
              final settings = SettingsStore();
              final store = StudyPlanStore(settings: settings);
              addTearDown(settings.dispose);
              addTearDown(store.dispose);
              store.addPlan(
                name: '高等数学与线性代数 Advanced Mathematics',
                iconId: 'calculate',
                plannedSeconds: 14400,
              );
              final id = store.plans.single.id;
              store.startOrResume(id);
              store.studySeconds(id, 3723);
              store.addPlan(
                name: 'Python',
                iconId: 'code',
                plannedSeconds: 120,
              );
              final pages = <String, Widget>{
                'home': StudyHomePage(store: store, settings: settings),
                'statistics': Scaffold(
                  appBar: AppBar(
                    title: Text(locale == 'zh' ? '学习统计' : 'Study Statistics'),
                  ),
                  body: StudyStatisticsPage(store: store),
                ),
                'management': PlanManagementPage(
                  store: store,
                  settings: settings,
                ),
                'timer': StudyTimerPage(
                  store: store,
                  planId: id,
                  settings: settings,
                  alerts: _Alerts(),
                ),
                'settings': Scaffold(
                  appBar: AppBar(
                    title: Text(locale == 'zh' ? '设置' : 'Settings'),
                  ),
                  body: SettingsPage(
                    settings: settings,
                    plans: store,
                    alerts: _Alerts(),
                  ),
                ),
                'editor': PlanEditPage(store: store, settings: settings),
              };
              for (final page in pages.entries) {
                await tester.pumpWidget(
                  RepaintBoundary(
                    key: _previewKey,
                    child: localizedApp(
                      home: page.value,
                      locale: Locale(locale),
                      brightness: brightness,
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull, reason: page.key);
                if (page.key == 'editor') {
                  for (final id in ['book', 'code']) {
                    final size = tester.getSize(
                      find.byKey(ValueKey('icon_option_$id')),
                    );
                    expect(size.width, greaterThanOrEqualTo(48));
                    expect(size.height, greaterThanOrEqualTo(48));
                  }
                }
                if ((width == 390 && scale == 1) ||
                    (width == 320 && scale == 1.5)) {
                  final suffix = width == 320 ? '_320_large' : '';
                  await _capture(
                    tester,
                    '${page.key}_${locale}_${brightness.name}$suffix',
                  );
                }
                if (page.key == 'home' || page.key == 'management') {
                  for (final filter in [
                    'all',
                    'notStarted',
                    'inProgress',
                    'completed',
                  ]) {
                    final chip = find.byKey(ValueKey('plan_filter_$filter'));
                    await tester.scrollUntilVisible(
                      chip,
                      160,
                      scrollable: find.byType(Scrollable).first,
                    );
                    await tester.ensureVisible(chip);
                    await tester.pumpAndSettle();
                    expect(
                      tester.getSize(chip).height,
                      greaterThanOrEqualTo(48),
                    );
                  }
                }
                if (page.key == 'editor' && width == 390 && scale == 1) {
                  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
                  await tester.showKeyboard(
                    find.byKey(const ValueKey('plan_name')),
                  );
                  await tester.pumpAndSettle();
                  expect(
                    tester
                        .getRect(find.byKey(const ValueKey('save_plan')))
                        .bottom,
                    lessThanOrEqualTo(544),
                  );
                  await _capture(
                    tester,
                    'editor_keyboard_${locale}_${brightness.name}',
                  );
                  tester.view.resetViewInsets();
                  await tester.pumpAndSettle();
                }
                if (page.key == 'statistics') {
                  await tester.tap(
                    find.text(locale == 'zh' ? '近 7 天' : 'Last 7 days'),
                  );
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                  if ((width == 390 && scale == 1) ||
                      (width == 320 && scale == 1.5)) {
                    final suffix = width == 320 ? '_320_large' : '';
                    await _capture(
                      tester,
                      'history_${locale}_${brightness.name}$suffix',
                    );
                  }
                }
                if (page.key == 'management') {
                  final search = find.byKey(const ValueKey('plan_search'));
                  await tester.scrollUntilVisible(
                    search,
                    -160,
                    scrollable: find.byType(Scrollable).first,
                  );
                  await tester.ensureVisible(search);
                  await tester.pumpAndSettle();
                  await tester.enterText(search, 'Python');
                  await tester.testTextInput.receiveAction(
                    TextInputAction.search,
                  );
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                  if ((width == 390 && scale == 1) ||
                      (width == 320 && scale == 1.5)) {
                    final suffix = width == 320 ? '_320_large' : '';
                    await _capture(
                      tester,
                      'search_${locale}_${brightness.name}$suffix',
                    );
                  }
                  await tester.enterText(search, 'no matching plan');
                  await tester.testTextInput.receiveAction(
                    TextInputAction.search,
                  );
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                  if ((width == 390 && scale == 1) ||
                      (width == 320 && scale == 1.5)) {
                    final suffix = width == 320 ? '_320_large' : '';
                    await _capture(
                      tester,
                      'no_results_${locale}_${brightness.name}$suffix',
                    );
                  }
                  final reset = find.byKey(
                    const ValueKey('reset_plan_filters'),
                  );
                  await tester.ensureVisible(reset);
                  await tester.pumpAndSettle();
                  await tester.tap(reset);
                  await tester.pumpAndSettle();
                }
                if (page.key == 'settings') {
                  final picker = find.byKey(
                    const ValueKey('open_sound_picker'),
                  );
                  await tester.scrollUntilVisible(picker, 200);
                  await tester.ensureVisible(picker);
                  await tester.pumpAndSettle();
                  await tester.tap(picker);
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                  if (width == 390 && scale == 1) {
                    await _capture(
                      tester,
                      'sound_picker_${locale}_${brightness.name}',
                    );
                  }
                  await tester.tap(
                    find.byKey(const ValueKey('close_sound_picker')),
                  );
                  await tester.pumpAndSettle();
                }
                await _checkScroll(tester);
                await tester.pumpWidget(const SizedBox());
              }
            },
          );
        }
      }
    }
  }
  for (final locale in ['zh', 'en']) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'editor confirms changes at narrow large type $locale ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final store = StudyPlanStore();
          addTearDown(store.dispose);
          await tester.pumpWidget(
            RepaintBoundary(
              key: _previewKey,
              child: localizedApp(
                locale: Locale(locale),
                brightness: brightness,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlanEditPage(store: store),
                        ),
                      ),
                      child: const Text('Open editor'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open editor'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('plan_name')),
            'Draft',
          );
          await tester.pump();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            'editor_discard_${locale}_${brightness.name}_320_large',
          );
          await tester.tap(find.byKey(const ValueKey('keep_editing')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextFormField>(find.byKey(const ValueKey('plan_name')))
                .controller!
                .text,
            'Draft',
          );
          await tester.enterText(find.byKey(const ValueKey('plan_name')), '');
          await tester.pump();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(PlanEditPage), findsNothing);
          expect(store.plans, isEmpty);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final width in [320.0, 390.0]) {
    for (final locale in ['zh', 'en']) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final scale in [1.0, 1.5]) {
          testWidgets(
            'review fits $width $locale ${brightness.name} scale $scale',
            (tester) async {
              tester.view.physicalSize = Size(width, 844);
              tester.view.devicePixelRatio = 1;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(() {
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
                tester.platformDispatcher.clearTextScaleFactorTestValue();
              });
              var now = DateTime(2026, 9, 30, 12);
              final settings = SettingsStore();
              final store = StudyPlanStore(settings: settings, now: () => now);
              addTearDown(settings.dispose);
              addTearDown(store.dispose);
              final plan = store.addPlan(
                name: '高等数学与线性代数 Advanced Mathematics',
                iconId: 'calculate',
                plannedSeconds: 7200,
              );
              store.startOrResume(plan.id);
              store.studySeconds(plan.id, 900);
              for (final (day, seconds) in [(1, 1800), (3, 3601), (4, 1350)]) {
                now = DateTime(2026, 10, day, 12);
                store.refreshForToday();
                store.startOrResume(plan.id);
                store.studySeconds(plan.id, seconds);
              }
              final deleted = store.addPlan(
                name: 'Deleted',
                iconId: 'book',
                plannedSeconds: 90,
              );
              store.startOrResume(deleted.id);
              store.studySeconds(deleted.id, 45);
              store.deletePlan(deleted.id);
              final capture =
                  (width == 390 && scale == 1) ||
                  (width == 320 && scale == 1.5);
              final suffix = width == 320 ? '_320_large' : '';
              final name = '${locale}_${brightness.name}$suffix';
              Future<void> tapVisible(Finder target) async {
                await tester.scrollUntilVisible(
                  target,
                  180,
                  scrollable: find.byType(Scrollable).first,
                );
                await tester.ensureVisible(target);
                await tester.pumpAndSettle();
                await tester.tap(target);
                await tester.pumpAndSettle();
              }

              Future<void> top() async {
                tester
                    .state<ScrollableState>(find.byType(Scrollable).first)
                    .position
                    .jumpTo(0);
                await tester.pumpAndSettle();
              }

              try {
                await tester.pumpWidget(
                  RepaintBoundary(
                    key: _previewKey,
                    child: localizedApp(
                      home: StudyReviewPage(store: store),
                      locale: Locale(locale),
                      brightness: brightness,
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                if (capture) await _capture(tester, 'review_overview_$name');
                final day = find.byKey(
                  const ValueKey('calendar_day_2026-10-04'),
                );
                await tester.scrollUntilVisible(
                  day,
                  180,
                  scrollable: find.byType(Scrollable).first,
                );
                await tester.ensureVisible(day);
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const ValueKey('review_month_grid')),
                  width == 390 && scale == 1 ? findsOneWidget : findsNothing,
                );
                expect(tester.getSize(day).width, greaterThanOrEqualTo(48));
                expect(tester.getSize(day).height, greaterThanOrEqualTo(48));
                expect(tester.takeException(), isNull);
                if (capture) await _capture(tester, 'review_calendar_$name');
                await tester.tap(day);
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const ValueKey('review_day_total')),
                  findsOneWidget,
                );
                expect(tester.takeException(), isNull);
                if (capture) await _capture(tester, 'review_day_$name');
                await _checkScroll(
                  tester,
                  scrollable: find
                      .descendant(
                        of: find.byKey(const ValueKey('review_day_entries')),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
                await tester.tap(
                  find.byKey(const ValueKey('review_close_day')),
                );
                await tester.pumpAndSettle();
                await top();
                await tapVisible(
                  find.text(locale == 'zh' ? '范围统计' : 'Date range'),
                );
                await tester.scrollUntilVisible(
                  find.byKey(const ValueKey('review_range_total')),
                  180,
                  scrollable: find.byType(Scrollable).first,
                );
                await tester.ensureVisible(
                  find.byKey(const ValueKey('review_range_total')),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                if (capture) {
                  await tester.ensureVisible(
                    find.byKey(const ValueKey('review_range_last30')),
                  );
                  await tester.pumpAndSettle();
                  await _capture(tester, 'review_range_$name');
                }
                await top();
                await tapVisible(
                  find.byKey(const ValueKey('review_range_custom')),
                );
                expect(find.byType(DateRangePickerDialog), findsOneWidget);
                expect(tester.takeException(), isNull);
                if (capture) await _capture(tester, 'review_picker_$name');
                await tester.binding.handlePopRoute();
                await tester.pumpAndSettle();
                await _checkScroll(tester);
                store.clearLearningData();
                await tester.pumpAndSettle();
                await top();
                expect(
                  tester
                      .widget<Text>(
                        find.byKey(const ValueKey('review_current_streak')),
                      )
                      .data,
                  locale == 'zh' ? '0 天' : '0 days',
                );
                expect(tester.takeException(), isNull);
                if (capture) await _capture(tester, 'review_empty_$name');
              } finally {
                await tester.pumpWidget(const SizedBox());
              }
            },
          );
        }
      }
    }
  }
}
