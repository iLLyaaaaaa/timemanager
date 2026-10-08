import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/l10n/app_localizations.dart';
import 'package:hello_app/models/app_settings.dart';
import 'package:hello_app/models/study_plan.dart';
import 'package:hello_app/pages/study_timer_page.dart';
import 'package:hello_app/services/timer_alert_service.dart';

import 'backup_fixtures.dart';
import 'localized_app.dart';

void mockDailyAudio() {
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
}

class DailyAlerts extends TimerAlertService {
  final scheduled = <String>[];
  final cancelled = <String>[];
  int completions = 0;
  @override
  Future<bool> scheduleBackgroundCompletion({
    required StudyPlan plan,
    required AppSettings settings,
    required AppLocalizations l10n,
  }) async {
    scheduled.add(plan.sessionId!);
    return false;
  }

  @override
  Future<void> cancelBackgroundCompletion(String sessionId) async =>
      cancelled.add(sessionId);
  @override
  Future<bool> notificationsEnabled() async => true;
  @override
  Future<bool> exactAlarmsEnabled() async => true;
  @override
  Future<void> complete(AppSettings settings) async => completions++;
}

class DailyHarness {
  DailyHarness({int seconds = 600}) {
    settings = SettingsStore(storage: settingsStorage);
    settings.update(settings.settings.copyWith(timerAlertMode: 'none'));
    store = StudyPlanStore(
      storage: planStorage,
      settings: settings,
      now: () => now,
    );
    id = store
        .addPlan(
          name: '阅读与长期学习计划 Reading practice',
          iconId: 'book',
          plannedSeconds: seconds,
        )
        .id;
  }
  DateTime now = DateTime(2026, 10, 8, 12);
  final planStorage = BackupPlanStorage();
  final settingsStorage = BackupSettingsStorage();
  final alerts = DailyAlerts();
  late final SettingsStore settings;
  late final StudyPlanStore store;
  late final String id;
  StudyPlan get plan => store.planById(id)!;
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));
  void dispose() {
    store.dispose();
    settings.dispose();
  }

  Widget timer({bool autoStart = true}) => StudyTimerPage(
    store: store,
    settings: settings,
    planId: id,
    alerts: alerts,
    autoStart: autoStart,
  );
}

Future<void> openDailyTimer(
  WidgetTester tester,
  DailyHarness h, {
  bool autoStart = true,
}) async {
  await tester.pumpWidget(
    localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('open_timer'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => h.timer(autoStart: autoStart),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open_timer')));
  await tester.pumpAndSettle();
}

Future<void> tapDaily(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
