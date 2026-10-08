import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/main.dart';
import 'package:hello_app/pages/backup_page.dart';
import 'package:hello_app/pages/settings_page.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/services/study_backup_service.dart';
import 'package:hello_app/services/timer_alert_service.dart';
import 'package:hello_app/services/local_media_store.dart';

import 'support/backup_fixtures.dart';
import 'support/backup_widgets.dart';
import 'support/localized_app.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

bool _idle(WidgetTester tester) => backupPageIdle(tester);

class _QuietAlerts extends TimerAlertService {
  @override
  Future<bool> notificationsEnabled() async => true;
  @override
  Future<bool> exactAlarmsEnabled() async => true;
  @override
  Future<void> stopPreview() async {}
}

class _FailingCleanup extends LocalMediaStore {
  @override
  Future<void> clearAll() async =>
      throw const FileSystemException('Cleanup failed');
}

Future<void> _open(WidgetTester tester, StudyBackupService service) async {
  await tester.pumpWidget(
    localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => BackupPage(service: service),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _preview(WidgetTester tester, BackupHarness h) async {
  h.files.selected = widgetSampleBackup().encode();
  await _tap(tester, 'import_backup');
  await waitForBackup(
    tester,
    () =>
        find.byKey(const ValueKey('backup_preview')).evaluate().isNotEmpty &&
        _idle(tester),
  );
}

Future<void> _confirm(WidgetTester tester) async {
  await _tap(tester, 'restore_backup');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirm_backup_restore')));
  await tester.pump();
}

void main() {
  setUpAll(() {
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
  });
  testWidgets('preview cancellation preserves choice and existing data', (
    tester,
  ) async {
    final h = await widgetBackupHarness(tester);
    h.store.addPlan(name: 'Original', iconId: 'book', plannedSeconds: 60);
    await tester.runAsync(h.store.flush);
    await _open(tester, h.service());
    await _preview(tester, h);
    await _tap(tester, 'restore_backup');
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backup_preview')), findsOneWidget);
    expect(h.store.plans.single.name, 'Original');
    h.files.selected = null;
    await _tap(tester, 'import_backup');
    await waitForBackup(tester, () => _idle(tester));
    expect(find.byKey(const ValueKey('backup_preview')), findsOneWidget);
    expect(h.store.plans.single.name, 'Original');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'confirmation restores and a failed restore keeps its preview for retry',
    (tester) async {
      final h = await widgetBackupHarness(tester);
      h.store.addPlan(name: 'Original', iconId: 'book', plannedSeconds: 60);
      await tester.runAsync(h.store.flush);
      await _open(tester, h.service());
      await _preview(tester, h);
      h.planStorage.failWrite = h.planStorage.writes + 1;
      await _confirm(tester);
      await waitForBackup(tester, () => _idle(tester));
      expect(find.byKey(const ValueKey('backup_preview')), findsOneWidget);
      expect(h.store.plans.single.name, 'Original');
      await _confirm(tester);
      await waitForBackup(tester, () => _idle(tester));
      expect(h.store.plans.single.name, 'Imported learning');
      expect(h.store.records.length, 5);
      expect(find.byKey(const ValueKey('backup_preview')), findsNothing);
      expect(find.text('数据已恢复'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('saving blocks repeat clicks and system back until complete', (
    tester,
  ) async {
    final h = await widgetBackupHarness(tester);
    h.store.addPlan(name: 'Original', iconId: 'book', plannedSeconds: 60);
    h.files.saveGate = Completer<void>();
    await _open(tester, h.service());
    await _tap(tester, 'export_backup');
    await waitForBackup(tester, () => h.files.saves == 1);
    expect(tester.widget<PopScope>(find.byType(PopScope).last).canPop, false);
    await _tap(tester, 'export_backup');
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(h.files.saves, 1);
    expect(find.byType(BackupPage), findsOneWidget);
    h.files.saveGate!.complete();
    await waitForBackup(tester, () => _idle(tester));
    expect(find.text('备份已保存'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BackupPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing media requires confirmation before export', (
    tester,
  ) async {
    final h = await widgetBackupHarness(tester);
    h.store.addPlan(
      name: 'Missing media',
      iconId: 'book',
      plannedSeconds: 60,
      customIconPath: '${h.directory.path}/custom_icons/missing.png',
    );
    await _open(tester, h.service());
    await _tap(tester, 'export_backup');
    await waitForBackup(
      tester,
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
    );
    expect(find.text('Missing media'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await waitForBackup(tester, () => _idle(tester));
    expect(h.files.saves, 0);
    await _tap(tester, 'export_backup');
    await waitForBackup(
      tester,
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('continue_backup')));
    await waitForBackup(tester, () => _idle(tester));
    expect(h.files.saves, 1);
    expect(h.store.plans.single.customIconPath, endsWith('missing.png'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'startup read failure has retry without migrating either snapshot',
    (tester) async {
      final h = await widgetBackupHarness(tester);
      h.planStorage.failReads = true;
      h.settingsStorage.value = '{"version":2,"homeHeadline":"Kept"}';
      await tester.pumpWidget(
        AppBootstrap(
          planStorage: h.planStorage,
          settingsStorage: h.settingsStorage,
          files: h.files,
          now: () => h.now,
          cancelNotifications: () async {},
        ),
      );
      await waitForBackup(
        tester,
        () => find.byKey(const ValueKey('retry_loading')).evaluate().isNotEmpty,
      );
      expect(h.planStorage.writes, 0);
      expect(h.settingsStorage.writes, 0);
      expect(find.byType(StudyHomePage), findsNothing);
      h.planStorage.failReads = false;
      await tester.tap(find.byKey(const ValueKey('retry_loading')));
      await waitForBackup(
        tester,
        () => find.byType(StudyHomePage).evaluate().isNotEmpty,
      );
      expect(find.text('Kept'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'startup corrupted data can be replaced through a verified backup',
    (tester) async {
      final h = await widgetBackupHarness(tester);
      h.planStorage.value = 'broken plans';
      h.settingsStorage.value = '{"version":99}';
      h.files.selected = widgetSampleBackup().encode();
      await tester.pumpWidget(
        AppBootstrap(
          planStorage: h.planStorage,
          settingsStorage: h.settingsStorage,
          files: h.files,
          now: () => h.now,
          cancelNotifications: () async {},
        ),
      );
      await waitForBackup(
        tester,
        () => find
            .byKey(const ValueKey('startup_restore_backup'))
            .evaluate()
            .isNotEmpty,
      );
      expect(h.planStorage.writes, 0);
      expect(h.settingsStorage.writes, 0);
      await tester.tap(find.byKey(const ValueKey('startup_restore_backup')));
      await tester.pump();
      await waitForBackup(
        tester,
        () =>
            find.byKey(const ValueKey('backup_preview')).evaluate().isNotEmpty,
      );
      await _confirm(tester);
      await waitForBackup(
        tester,
        () => find.byType(StudyHomePage).evaluate().isNotEmpty,
      );
      expect(find.text('Imported learning'), findsOneWidget);
      expect(
        await tester.runAsync(() => h.files.readControl('previous.json')),
        contains('broken plans'),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('home save failure banner retries without changing input', (
    tester,
  ) async {
    final h = await widgetBackupHarness(tester);
    h.planStorage.failWrites = true;
    h.store.addPlan(name: 'Retained', iconId: 'book', plannedSeconds: 60);
    await tester.runAsync(h.store.flush);
    await tester.pumpWidget(
      localizedApp(
        home: StudyHomePage(store: h.store, settings: h.settings),
      ),
    );
    expect(find.byKey(const ValueKey('retry_save')), findsOneWidget);
    h.planStorage.failWrites = false;
    h.planStorage.gate = Completer<void>();
    await _tap(tester, 'retry_save');
    await waitForBackup(tester, () => h.planStorage.writes == 2);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('retry_save')))
          .onPressed,
      null,
    );
    h.planStorage.gate!.complete();
    await waitForBackup(
      tester,
      () => find.byKey(const ValueKey('retry_save')).evaluate().isEmpty,
    );
    expect(h.store.plans.single.name, 'Retained');
    expect(h.store.hasUnsavedChanges, false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'failed rollback blocks leaving and exposes a working recovery button',
    (tester) async {
      final h = await widgetBackupHarness(tester);
      h.store.addPlan(name: 'Original', iconId: 'book', plannedSeconds: 60);
      final service = h.service(
        checkpoint: (phase) async {
          if (phase == 'mediaWritten') h.settingsStorage.failWrites = true;
        },
      );
      await _open(tester, service);
      await _preview(tester, h);
      await _confirm(tester);
      await waitForBackup(
        tester,
        () => find
            .byKey(const ValueKey('retry_backup_recovery'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(BackupPage), findsOneWidget);
      expect(h.store.isReplacing, true);
      h.settingsStorage.failWrites = false;
      await _tap(tester, 'retry_backup_recovery');
      await waitForBackup(tester, () => _idle(tester));
      expect(h.store.plans.single.name, 'Original');
      expect(service.requiresRecovery, false);
      expect(find.byKey(const ValueKey('backup_preview')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'no previous copy shows guidance and settings entry opens backup page',
    (tester) async {
      final h = await widgetBackupHarness(tester);
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: SettingsPage(
              settings: h.settings,
              plans: h.store,
              backups: h.service(),
              alerts: _QuietAlerts(),
            ),
          ),
        ),
      );
      await _tap(tester, 'settings_previous_backup');
      await waitForBackup(
        tester,
        () => find.textContaining('还没有恢复前副本').evaluate().isNotEmpty,
      );
      expect(find.byType(BackupPage), findsOneWidget);
      expect(h.planStorage.writes, 0);
      expect(h.settingsStorage.writes, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('clearing data reports media cleanup failure separately', (
    tester,
  ) async {
    final h = await widgetBackupHarness(tester);
    h.store.addPlan(name: 'Clear me', iconId: 'book', plannedSeconds: 60);
    final alerts = _QuietAlerts();
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SettingsPage(
            settings: h.settings,
            plans: h.store,
            alerts: alerts,
            media: _FailingCleanup(),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('清空全部数据'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('清空全部数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空全部数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清空'));
    await tester.pump();
    await waitForBackup(
      tester,
      () => find.textContaining('部分本地媒体').evaluate().isNotEmpty,
    );
    expect(h.store.plans, isEmpty);
    expect(h.store.records, isEmpty);
    expect(h.store.hasUnsavedChanges, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
