import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/l10n/app_localizations.dart';
import 'package:hello_app/models/app_settings.dart';
import 'package:hello_app/models/study_plan.dart';
import 'package:hello_app/pages/settings_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';
import 'package:hello_app/services/timer_alert_service.dart';
import 'package:hello_app/services/screen_state_service.dart';

import 'support/localized_app.dart';

class _FakeAlerts extends TimerAlertService {
  _FakeAlerts({this.scheduled = true});
  final bool scheduled;
  final List<int> previews = [];
  final List<String> completedModes = [];
  final List<String> scheduledPlans = [];
  final List<String> cancelledPlans = [];
  int stops = 0;

  @override
  Future<void> preview(int sound) async => previews.add(sound);

  @override
  Future<void> stopPreview() async => stops++;

  @override
  Future<void> complete(AppSettings settings) async => completedModes.add(
    '${settings.timerAlertMode}:${settings.selectedAlertSound}',
  );

  @override
  Future<bool> scheduleBackgroundCompletion({
    required StudyPlan plan,
    required AppSettings settings,
    required AppLocalizations l10n,
  }) async {
    scheduledPlans.add(plan.id);
    return scheduled;
  }

  @override
  Future<void> cancelBackgroundCompletion(String sessionId) async =>
      cancelledPlans.add(sessionId);

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> exactAlarmsEnabled() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;
}

class _DeniedAlerts extends _FakeAlerts {
  @override
  Future<bool> notificationsEnabled() async => false;

  @override
  Future<bool> requestNotificationPermission() async => false;

  @override
  Future<bool> exactAlarmsEnabled() async => false;
}

class _ScreenState extends ScreenStateService {
  _ScreenState(this.locked);
  final bool locked;
  @override
  Future<bool> isScreenLocked() async => locked;
}

void main() {
  testWidgets('locking continues a pause-enabled plan by wall clock', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 29, 12);
    final store = StudyPlanStore(now: () => now);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 120);
    final alerts = _FakeAlerts();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      localizedApp(
        home: StudyTimerPage(
          store: store,
          planId: store.plans.single.id,
          alerts: alerts,
          screenState: _ScreenState(true),
          now: () => now,
        ),
      ),
    );
    await tester.tap(find.text('开始'));
    await tester.pump();
    expect(alerts.scheduledPlans, [store.plans.single.id]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(store.plans.single.isRunning, isTrue);
    now = now.add(const Duration(seconds: 60));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(store.plans.single.remainingSeconds, 60);
    expect(store.plans.single.studiedSeconds, 60);
    expect(alerts.cancelledPlans, isEmpty);
    now = now.add(const Duration(seconds: 60));
    await tester.pump(const Duration(seconds: 1));
    expect(store.plans.single.isCompletedToday, isTrue);
    expect(store.plans.single.remainingSeconds, 0);
    expect(alerts.completedModes, isEmpty);
  });

  testWidgets('Home pauses a pause-enabled plan without counting time away', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 29, 12);
    final store = StudyPlanStore(now: () => now);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 120);
    final alerts = _FakeAlerts();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      localizedApp(
        home: StudyTimerPage(
          store: store,
          planId: store.plans.single.id,
          alerts: alerts,
          screenState: _ScreenState(false),
          now: () => now,
        ),
      ),
    );
    await tester.tap(find.text('开始'));
    await tester.pump();
    final sessionId = store.plans.single.sessionId!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(store.plans.single.isRunning, isFalse);
    now = now.add(const Duration(seconds: 60));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(store.plans.single.remainingSeconds, 120);
    expect(store.plans.single.studiedSeconds, 0);
    expect(find.text('开始'), findsOneWidget);
    expect(alerts.cancelledPlans, contains(sessionId));
  });

  testWidgets('disposing a running page keeps its OS alert scheduled', (
    tester,
  ) async {
    final store = StudyPlanStore();
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 60);
    final alerts = _FakeAlerts();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      localizedApp(
        home: StudyTimerPage(
          store: store,
          planId: store.plans.single.id,
          alerts: alerts,
        ),
      ),
    );
    await tester.tap(find.text('开始'));
    await tester.pump();
    expect(alerts.scheduledPlans, [store.plans.single.id]);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(store.plans.single.isRunning, isTrue);
    expect(alerts.cancelledPlans, isEmpty);
  });
  test('all five bundled tones are distinct valid wave files', () async {
    final signatures = <int>[];
    for (var sound = 1; sound <= 5; sound++) {
      final data = await rootBundle.load('assets/sounds/timer_bell_$sound.wav');
      final bytes = data.buffer.asUint8List();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(bytes.length, greaterThan(1000));
      signatures.add(Object.hashAll(bytes));
    }
    expect(signatures.toSet().length, 5);
  });

  testWidgets('five preview controls use one service and stop on exit', (
    tester,
  ) async {
    final settings = SettingsStore();
    final plans = StudyPlanStore(settings: settings);
    final alerts = _FakeAlerts();
    addTearDown(plans.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SettingsPage(settings: settings, plans: plans, alerts: alerts),
        ),
      ),
    );
    for (var sound = 1; sound <= 5; sound++) {
      final tile = find.byKey(ValueKey('alert_sound_$sound'));
      await tester.scrollUntilVisible(tile, 200);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: tile, matching: find.byTooltip('试听')),
      );
      await tester.pump();
    }
    expect(alerts.previews, [1, 2, 3, 4, 5]);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(alerts.stops, greaterThanOrEqualTo(1));
  });

  testWidgets(
    'denied notification permission shows guidance without crashing',
    (tester) async {
      final settings = SettingsStore();
      final plans = StudyPlanStore(settings: settings);
      final alerts = _DeniedAlerts();
      addTearDown(plans.dispose);
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: SettingsPage(
              settings: settings,
              plans: plans,
              alerts: alerts,
            ),
          ),
        ),
      );
      await tester.pump();
      final action = find.text('开启通知权限');
      await tester.scrollUntilVisible(action, 200);
      await tester.drag(find.byType(ListView).first, const Offset(0, -220));
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pump();
      expect(find.textContaining('后台完成提醒'), findsOneWidget);
    },
  );

  testWidgets('alert mode and selected tone change through settings', (
    tester,
  ) async {
    final settings = SettingsStore();
    final plans = StudyPlanStore(settings: settings);
    final alerts = _FakeAlerts();
    addTearDown(plans.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SettingsPage(settings: settings, plans: plans, alerts: alerts),
        ),
      ),
    );
    for (final (label, mode) in [
      ('震动', 'vibration'),
      ('无提醒', 'none'),
      ('铃声', 'sound'),
    ]) {
      await tester.tap(find.text('提醒方式'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(settings.settings.timerAlertMode, mode);
    }
    final selected = find.byKey(const ValueKey('alert_sound_3'));
    await tester.scrollUntilVisible(selected, 200);
    await tester.ensureVisible(selected);
    await tester.pumpAndSettle();
    await tester.tap(selected);
    await tester.pump();
    expect(settings.settings.selectedAlertSound, 3);
  });

  for (final mode in ['sound', 'vibration', 'none']) {
    testWidgets('$mode completion invokes only its chosen behavior once', (
      tester,
    ) async {
      final settings = SettingsStore();
      settings.update(
        settings.settings.copyWith(timerAlertMode: mode, selectedAlertSound: 3),
      );
      final store = StudyPlanStore(
        settings: settings,
        now: () => tester.binding.clock.now(),
      );
      store.addPlan(name: '高等数学', iconId: 'calculate', plannedSeconds: 1);
      final alerts = _FakeAlerts(scheduled: false);
      addTearDown(store.dispose);
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        localizedApp(
          home: StudyTimerPage(
            store: store,
            planId: store.plans.single.id,
            settings: settings,
            alerts: alerts,
          ),
        ),
      );
      await tester.tap(find.text('开始'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      expect(store.plans.single.isCompletedToday, isTrue);
      expect(alerts.completedModes, mode == 'none' ? isEmpty : ['$mode:3']);
    });
  }

  testWidgets(
    'background continuation schedules an OS alert, then cancels on resume',
    (tester) async {
      final settings = SettingsStore();
      final store = StudyPlanStore(
        settings: settings,
        now: () => tester.binding.clock.now(),
      );
      store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 4);
      final plan = store.plans.single;
      store.updatePlan(plan.copyWith(pauseWhenBackgrounded: false));
      var clock = DateTime(2026, 9, 29, 12);
      final alerts = _FakeAlerts();
      addTearDown(store.dispose);
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        localizedApp(
          home: StudyTimerPage(
            store: store,
            planId: plan.id,
            settings: settings,
            now: () => clock,
            alerts: alerts,
          ),
        ),
      );
      await tester.tap(find.text('开始'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(alerts.scheduledPlans, [plan.id]);
      clock = clock.add(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(store.plans.single.isCompletedToday, isTrue);
      expect(alerts.cancelledPlans, isEmpty);
      expect(alerts.completedModes, isEmpty);
    },
  );
}
