import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hello_app/data/study_snapshot.dart';
import 'package:hello_app/models/app_settings.dart';
import 'package:hello_app/models/study_backup.dart';
import 'package:hello_app/models/study_plan.dart';
import 'package:hello_app/models/study_record.dart';
import 'package:hello_app/pages/backup_page.dart';

import 'backup_fixtures.dart';

bool backupPageIdle(WidgetTester tester) => tester
    .widget<PopScope>(
      find.descendant(
        of: find.byType(BackupPage),
        matching: find.byType(PopScope),
      ),
    )
    .canPop;

Future<BackupHarness> widgetBackupHarness(WidgetTester tester) async {
  final harness = (await tester.runAsync(BackupHarness.create))!;
  addTearDown(() async {
    await tester.runAsync(harness.close);
  });
  return harness;
}

Future<void> waitForBackup(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump();
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Backup operation did not finish');
}

StudyBackup widgetSampleBackup() => StudyBackup(
  createdAt: DateTime.utc(2026, 10, 8, 4),
  appVersion: '0.1.8+9',
  settings: const AppSettings(),
  plans: StudyPlanSnapshot(
    plans: [
      const StudyPlan(
        id: 'custom_8',
        name: 'Imported learning',
        iconId: 'book',
        plannedSeconds: 3600,
      ),
    ],
    records: [
      for (final (day, seconds) in [
        ('2024-02-29', 60),
        ('2026-10-07', 120),
        ('2026-10-08', 0),
        ('2026-02-30', 60),
        ('2028-01-01', 60),
      ])
        StudyRecord(
          id: day,
          planId: 'deleted',
          date: day,
          plannedSeconds: 300,
          studiedSeconds: seconds,
        ),
    ],
    nextId: 9,
  ),
);
