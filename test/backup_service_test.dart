import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/data/study_snapshot.dart';
import 'package:hello_app/models/app_settings.dart';
import 'package:hello_app/models/study_backup.dart';
import 'package:hello_app/models/study_plan.dart';
import 'package:hello_app/models/study_record.dart';
import 'package:hello_app/services/backup_file_access.dart';

import 'support/backup_fixtures.dart';

class _ProcessDeath extends Error {}

final class _PickedBackup extends PlatformFile {
  _PickedBackup(this.reportedSize, this.chunks);
  final int? reportedSize;
  final List<Uint8List> chunks;
  int reads = 0;
  @override
  String get name => 'backup.json';
  @override
  Uri get uri => Uri.parse('content://backups/test');
  @override
  int? lengthSync() => reportedSize;
  @override
  Future<int?> length() async => reportedSize;
  @override
  Stream<Uint8List> readAsByteStream() async* {
    for (final chunk in chunks) {
      reads++;
      yield chunk;
    }
  }

  @override
  Future<Uint8List> readAsBytes() => throw StateError('Must stream the backup');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StudyBackup _replacement({List<BackupMedia> media = const [], String? icon}) =>
    StudyBackup(
      createdAt: DateTime.utc(2026, 10, 8, 10),
      appVersion: '0.1.8+9',
      plans: StudyPlanSnapshot(
        plans: [
          StudyPlan(
            id: 'custom_40',
            name: 'Imported',
            iconId: 'book',
            plannedSeconds: 600,
            customIconPath: icon,
          ),
        ],
        records: [],
        nextId: 41,
      ),
      settings: const AppSettings(localeCode: 'en'),
      media: media,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'oversized picked files are rejected before reading any content',
    () async {
      final file = _PickedBackup(maxBackupBytes + 1, [Uint8List(1)]);
      await expectLater(
        BackupFileAccess().readPickedBackup(file),
        throwsA(
          isA<BackupException>().having((e) => e.code, 'code', 'tooLarge'),
        ),
      );
      expect(file.reads, 0);
    },
  );

  test(
    'a file that grows past its reported size stops at the stream limit',
    () async {
      final chunk = Uint8List(8 * 1024 * 1024);
      final file = _PickedBackup(1, List.filled(10, chunk));
      await expectLater(
        BackupFileAccess().readPickedBackup(file),
        throwsA(
          isA<BackupException>().having((e) => e.code, 'code', 'tooLarge'),
        ),
      );
      expect(file.reads, 9);
    },
  );

  test(
    'chunked backups are joined and empty or unknown-size files are rejected',
    () async {
      final access = BackupFileAccess();
      final file = _PickedBackup(3, [
        Uint8List.fromList([1]),
        Uint8List.fromList([2, 3]),
      ]);
      expect(await access.readPickedBackup(file), [1, 2, 3]);
      for (final invalid in [
        _PickedBackup(null, []),
        _PickedBackup(0, []),
        _PickedBackup(1, []),
      ]) {
        await expectLater(
          access.readPickedBackup(invalid),
          throwsA(
            isA<BackupException>().having((e) => e.code, 'code', 'invalid'),
          ),
        );
      }
      expect(
        () => StudyBackup.decode(Uint8List(0)),
        throwsA(isA<BackupException>()),
      );
    },
  );

  test(
    'unknown local snapshot versions have a distinct error and keep originals',
    () async {
      final h = await BackupHarness.create();
      addTearDown(h.close);
      final planRaw = jsonEncode({'version': 99, 'plans': [], 'records': []});
      final settingsRaw = jsonEncode({'version': 99});
      expect(
        () => StudyPlanSnapshot.decode(planRaw),
        throwsA(isA<SnapshotVersionException>()),
      );
      expect(
        () => decodeSettingsSnapshot(settingsRaw),
        throwsA(isA<SnapshotVersionException>()),
      );
      h.planStorage.value = planRaw;
      h.settingsStorage.value = settingsRaw;
      final plans = await StudyPlanStore.load(storage: h.planStorage);
      final settings = await SettingsStore.load(storage: h.settingsStorage);
      addTearDown(plans.dispose);
      addTearDown(settings.dispose);
      expect(plans.hasLoadError, true);
      expect(settings.hasLoadError, true);
      expect(await plans.retrySave(), false);
      expect(await settings.retrySave(), false);
      expect(h.planStorage.value, planRaw);
      expect(h.settingsStorage.value, settingsRaw);
    },
  );

  test('failed plan and settings writes retry without editing', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    h.planStorage.failWrites = true;
    h.settingsStorage.failWrites = true;
    h.store.addPlan(name: 'Retained', iconId: 'book', plannedSeconds: 300);
    h.settings.update(
      h.settings.settings.copyWith(homeHeadline: 'Retained headline'),
    );
    expect(await h.store.flush(), false);
    expect(await h.settings.flush(), false);
    expect(h.store.hasSaveError, true);
    expect(h.store.hasUnsavedChanges, true);
    expect(h.settings.hasSaveError, true);
    h.planStorage.failWrites = false;
    h.settingsStorage.failWrites = false;
    expect(await h.store.retrySave(), true);
    expect(await h.settings.retrySave(), true);
    expect(
      StudyPlanSnapshot.decode(h.planStorage.value).plans.single.name,
      'Retained',
    );
    expect(
      decodeSettingsSnapshot(h.settingsStorage.value).homeHeadline,
      'Retained headline',
    );
    expect(h.store.hasUnsavedChanges, false);
    expect(h.settings.hasSaveError, false);
  });

  test('queued edits and retries persist the latest snapshot', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    final gate = Completer<void>();
    h.planStorage.gate = gate;
    h.planStorage.failWrite = 1;
    final plan = h.store.addPlan(
      name: 'First',
      iconId: 'book',
      plannedSeconds: 100,
    );
    await Future<void>.delayed(Duration.zero);
    h.store.updatePlan(plan.copyWith(name: 'Latest'));
    gate.complete();
    expect(await h.store.flush(), true);
    expect(h.planStorage.writes, 2);
    expect(
      StudyPlanSnapshot.decode(h.planStorage.value).plans.single.name,
      'Latest',
    );
    expect(h.store.hasSaveError, false);
  });

  test(
    'read errors and unknown snapshots remain protected from writes',
    () async {
      final plans = BackupPlanStorage()..failReads = true;
      final store = await StudyPlanStore.load(storage: plans);
      addTearDown(store.dispose);
      expect(store.hasLoadError, true);
      expect(await store.retrySave(), false);
      expect(plans.writes, 0);
      final disk = BackupSettingsStorage()..value = '{"version":99}';
      final settings = await SettingsStore.load(storage: disk);
      addTearDown(settings.dispose);
      settings.update(const AppSettings(localeCode: 'en'));
      expect(settings.hasLoadError, true);
      expect(await settings.flush(), false);
      expect(disk.value, '{"version":99}');
      expect(disk.writes, 0);
    },
  );

  test('complete roundtrip deduplicates images and restores settings, history and sound', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    final icon = await h.icon();
    final sound = await h.sound();
    final first = h.store.addPlan(
      name: 'Reading',
      iconId: 'book',
      plannedSeconds: 600,
      customIconPath: icon,
    );
    h.store.addPlan(
      name: 'Writing',
      iconId: 'edit',
      plannedSeconds: 900,
      customIconPath: icon,
    );
    h.settings.update(
      h.settings.settings.copyWith(
        soundSource: 'custom',
        customSoundPath: sound,
        customSoundName: 'my sound.wav',
        dailyResetHour: 4,
      ),
    );
    h.store.startOrResume(first.id);
    h.store.studySeconds(first.id, 23);
    final service = h.service();
    final backup = await service.capture();
    expect(backup.media.length, 2);
    expect(
      backup.plans.plans[0].customIconPath,
      backup.plans.plans[1].customIconPath,
    );
    expect(utf8.decode(backup.encode()), isNot(contains(h.directory.path)));
    expect(await service.export(backup), true);
    expect(h.files.savedName, startsWith('TimeManager-backup-20261008-'));
    final inspected = await service.inspect(h.files.saved!);
    h.store.clearAllData();
    h.settings.restoreDefaults();
    await service.restore(inspected);
    expect(h.store.plans.map((p) => p.name), ['Reading', 'Writing']);
    expect(h.store.records.single.studiedSeconds, 23);
    expect(h.settings.settings.dailyResetHour, 4);
    expect(h.settings.settings.soundSource, 'custom');
    final restoredIcon = h.store.plans.first.customIconPath!;
    expect(restoredIcon, isNot(icon));
    expect(h.store.plans.last.customIconPath, restoredIcon);
    expect(
      await File(restoredIcon).readAsBytes(),
      await File(icon).readAsBytes(),
    );
    expect(
      await File(h.settings.settings.customSoundPath!).readAsBytes(),
      backupTestWav(),
    );
    expect(h.store.plans.every((p) => !p.isRunning), true);
    expect(h.cancellations, greaterThan(0));
    expect(await h.files.readControl('transaction.json'), null);
  });

  test('capture includes unsaved edits and elapsed time without pausing live timer', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    h.planStorage.failWrites = true;
    final plan = h.store.addPlan(
      name: 'Unsaved',
      iconId: 'book',
      plannedSeconds: 100,
    );
    h.store.beginRunning(plan.id);
    h.now = h.now.add(const Duration(seconds: 17));
    expect(await h.store.flush(), false);
    final backup = await h.service().capture();
    expect(backup.plans.plans.single.studiedSeconds, 17);
    expect(backup.plans.plans.single.remainingSeconds, 83);
    expect(backup.plans.records.single.studiedSeconds, 17);
    expect(backup.plans.plans.single.isRunning, false);
    expect(h.store.plans.single.isRunning, true);
    expect(h.store.plans.single.studiedSeconds, 0);
    expect(await h.service().export(backup), true);
  });

  test('missing media keeps records and uses built-in references', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    h.store.addPlan(
      name: 'Missing picture',
      iconId: 'book',
      plannedSeconds: 50,
      customIconPath: '${h.directory.path}/custom_icons/missing.png',
    );
    h.settings.update(
      h.settings.settings.copyWith(
        soundSource: 'custom',
        customSoundPath: '${h.directory.path}/custom_sounds/missing.wav',
        customSoundName: 'lost.wav',
      ),
    );
    final backup = await h.service().capture();
    expect(backup.missingMedia, ['icon:Missing picture', 'sound:lost.wav']);
    expect(backup.media, isEmpty);
    expect(backup.plans.plans.single.customIconPath, null);
    expect(backup.settings.soundSource, 'builtin');
    expect(
      StudyBackup.decode(backup.encode()).missingMedia,
      backup.missingMedia,
    );
  });

  test(
    'deleted plan history, zero, future and malformed dates survive roundtrip',
    () async {
      final h = await BackupHarness.create();
      addTearDown(h.close);
      final records = [
        for (final date in [
          '2024-02-29',
          '2026-10-08',
          '2027-01-01',
          '2026-02-30',
          'invalid',
        ])
          StudyRecord(
            id: date,
            planId: 'custom_100',
            date: date,
            plannedSeconds: 100,
            studiedSeconds: 0,
          ),
      ];
      final backup = StudyBackup(
        createdAt: h.now,
        appVersion: '0.1.8+9',
        settings: const AppSettings(),
        plans: StudyPlanSnapshot(plans: [], records: records, nextId: 1),
      );
      await h.service().restore(backup);
      expect(h.store.records.map((r) => r.date), records.map((r) => r.date));
      expect(
        h.store.addPlan(name: 'New ID', iconId: 'book', plannedSeconds: 30).id,
        'custom_101',
      );
    },
  );

  test(
    'restored progress is paused and daily reset uses imported settings',
    () async {
      final h = await BackupHarness.create();
      addTearDown(h.close);
      h.now = DateTime(2026, 10, 9, 2);
      final plan =
          const StudyPlan(
                id: 'custom_1',
                name: 'Night reading',
                iconId: 'book',
                plannedSeconds: 100,
              )
              .withProgress(
                day: '2026-10-08',
                remainingSeconds: 70,
                studiedSeconds: 30,
                hasStartedToday: true,
                isCompletedToday: false,
              )
              .withSession(
                startedAt: DateTime(2026, 10, 8, 12),
                sessionId: 'old',
              );
      final backup = StudyBackup(
        createdAt: DateTime(2026, 10, 8, 12),
        appVersion: '0.1.8+9',
        settings: const AppSettings(dailyResetHour: 4),
        plans: StudyPlanSnapshot(plans: [plan], records: [], nextId: 2),
      );
      await h.service().restore(backup);
      expect(h.store.plans.single.remainingSeconds, 70);
      expect(h.store.plans.single.isRunning, false);
      h.now = DateTime(2026, 10, 9, 5);
      await h.service().restore(backup);
      expect(h.store.plans.single.hasStartedToday, false);
      expect(h.store.records.single.date, '2026-10-08');
      expect(h.store.records.single.studiedSeconds, 30);
    },
  );

  test('malformed, unknown version, duplicate IDs, foreign references and bad media are rejected', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    final service = h.service();
    await expectLater(
      service.inspect(Uint8List.fromList([255])),
      throwsA(isA<BackupException>()),
    );
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (value) => value['version'] = 99,
      (value) {
        final plans = value['plans'] as Map;
        final list = plans['plans'] as List;
        list.add(list.first);
      },
      (value) =>
          ((value['plans'] as Map)['plans'] as List).first['customIconPath'] =
              '/private/file.png',
      (value) =>
          ((value['plans'] as Map)['plans'] as List).first['studiedSeconds'] =
              -1,
      (value) => (value['settings'] as Map)['dailyResetHour'] = 25,
      (value) {
        final record = const StudyRecord(
          id: 'same',
          planId: 'custom_40',
          date: '2026-10-08',
          plannedSeconds: 600,
          studiedSeconds: 30,
        ).toJson();
        (value['plans'] as Map)['records'] = [record, record];
      },
      (value) {
        final media = {
          'id': 'media_1',
          'kind': 'icon',
          'extension': '.png',
          'bytes': base64Encode([1, 2, 3]),
        };
        value['media'] = [media, media];
      },
    ]) {
      final value = Map<String, dynamic>.from(_replacement().toJson());
      mutation(value);
      await expectLater(
        service.inspect(Uint8List.fromList(utf8.encode(jsonEncode(value)))),
        throwsA(isA<BackupException>()),
      );
    }
    final bad = _replacement(
      icon: 'media_1',
      media: [
        BackupMedia(
          id: 'media_1',
          kind: 'icon',
          extension: '.png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ],
    );
    await expectLater(
      service.inspect(bad.encode()),
      throwsA(isA<BackupException>()),
    );
    expect(h.planStorage.writes, 0);
    expect(h.settingsStorage.writes, 0);
  });

  test(
    'size limit and canceled file dialogs never replace current data',
    () async {
      final h = await BackupHarness.create();
      addTearDown(h.close);
      final service = h.service();
      expect(await service.chooseBackup(), null);
      h.files.cancelSave = true;
      expect(await service.export(_replacement()), false);
      await expectLater(
        service.inspect(Uint8List(maxBackupBytes + 1)),
        throwsA(isA<BackupException>()),
      );
      expect(h.planStorage.writes, 0);
      expect(h.settingsStorage.writes, 0);
    },
  );

  test('restore refuses unsaved data and duplicate submissions', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    h.planStorage.failWrites = true;
    h.store.addPlan(name: 'Original', iconId: 'book', plannedSeconds: 30);
    await h.store.flush();
    await expectLater(
      h.service().restore(_replacement()),
      throwsA(isA<BackupException>()),
    );
    expect(h.store.plans.single.name, 'Original');
    expect(await h.files.readControl('transaction.json'), null);
    h.planStorage.failWrites = false;
    await h.store.retrySave();
    final gate = Completer<void>();
    final entered = Completer<void>();
    final service = h.service(
      checkpoint: (phase) async {
        if (phase == 'prepared') {
          entered.complete();
          await gate.future;
        }
      },
    );
    final first = service.restore(_replacement());
    await entered.future;
    await expectLater(
      service.restore(_replacement()),
      throwsA(isA<BackupException>()),
    );
    expect(h.store.isReplacing, true);
    gate.complete();
    await first;
    expect(h.store.isReplacing, false);
  });

  test('previous copy rotates only after success and restores with fresh media paths', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    final icon = await h.icon();
    h.store.addPlan(
      name: 'Original',
      iconId: 'book',
      plannedSeconds: 60,
      customIconPath: icon,
    );
    final service = h.service();
    await service.restore(_replacement());
    final previous = (await service.previousBackup())!;
    expect(previous.plans.plans.single.name, 'Original');
    expect(previous.media.length, 1);
    final before = await h.files.readControl('previous.json');
    h.planStorage.failWrite = h.planStorage.writes + 1;
    await expectLater(
      service.restore(_replacement()),
      throwsA(isA<FileSystemException>()),
    );
    expect(await h.files.readControl('previous.json'), before);
    await service.restore(previous);
    expect(h.store.plans.single.name, 'Original');
    expect(h.store.plans.single.customIconPath, isNot(icon));
    expect(
      (await service.previousBackup())!.plans.plans.single.name,
      'Imported',
    );
  });

  for (final phase in [
    'prepared',
    'mediaWritten',
    'settingsWritten',
    'plansWritten',
    'committed',
    'previousRotated',
  ]) {
    test('process interruption at $phase recovers before loading', () async {
      final h = await BackupHarness.create();
      addTearDown(h.close);
      final icon = await h.icon();
      h.store.addPlan(
        name: 'Original',
        iconId: 'book',
        plannedSeconds: 60,
        customIconPath: icon,
      );
      final backup = _replacement(
        icon: 'media_1',
        media: [
          BackupMedia(
            id: 'media_1',
            kind: 'icon',
            extension: '.png',
            bytes: await backupTestPng(),
          ),
        ],
      );
      final service = h.service(
        checkpoint: (step) async {
          if (step == phase) throw _ProcessDeath();
        },
      );
      await expectLater(service.restore(backup), throwsA(isA<_ProcessDeath>()));
      expect(await h.files.readControl('transaction.json'), isNotNull);
      await h.service(live: false).recoverPending();
      expect(await h.files.readControl('transaction.json'), null);
      final snapshot = StudyPlanSnapshot.decode(h.planStorage.value);
      expect(
        snapshot.plans.single.name,
        ['committed', 'previousRotated'].contains(phase)
            ? 'Imported'
            : 'Original',
      );
      expect(await File(icon).exists(), true);
      expect(await File(snapshot.plans.single.customIconPath!).exists(), true);
    });
  }

  test('failed rollback keeps journal and original media until explicit recovery succeeds', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    final icon = await h.icon();
    h.store.addPlan(
      name: 'Original',
      iconId: 'book',
      plannedSeconds: 60,
      customIconPath: icon,
    );
    final service = h.service(
      checkpoint: (phase) async {
        if (phase == 'mediaWritten') h.settingsStorage.failWrites = true;
      },
    );
    await expectLater(
      service.restore(_replacement()),
      throwsA(isA<BackupException>()),
    );
    expect(service.requiresRecovery, true);
    expect(h.store.isReplacing, true);
    expect(await File(icon).exists(), true);
    expect(await h.files.isProtectedMedia(icon), true);
    h.settingsStorage.failWrites = false;
    await service.recoverPending();
    expect(service.requiresRecovery, false);
    expect(h.store.isReplacing, false);
    expect(h.store.plans.single.name, 'Original');
    expect(await h.files.readControl('transaction.json'), null);
  });

  for (final stage in ['candidate', 'settings', 'plans']) {
    test(
      'a failed $stage write preserves data and the last successful copy',
      () async {
        final h = await BackupHarness.create();
        addTearDown(h.close);
        h.store.addPlan(name: 'Original', iconId: 'book', plannedSeconds: 60);
        final service = h.service();
        await service.restore(_replacement());
        h.store.addPlan(
          name: 'Keep latest',
          iconId: 'book',
          plannedSeconds: 90,
        );
        await h.store.flush();
        final plansBefore = h.planStorage.value;
        final settingsBefore = h.settingsStorage.value;
        final previousBefore = await h.files.readControl('previous.json');
        switch (stage) {
          case 'candidate':
            h.files.failControl = 'candidate.json';
            h.files.failControlOccurrence =
                h.files.controlWrites['candidate.json']! + 1;
          case 'settings':
            h.settingsStorage.failWrite = h.settingsStorage.writes + 1;
          case 'plans':
            h.planStorage.failWrite = h.planStorage.writes + 1;
        }
        await expectLater(
          service.restore(_replacement()),
          throwsA(isA<FileSystemException>()),
        );
        expect(h.planStorage.value, plansBefore);
        expect(h.settingsStorage.value, settingsBefore);
        expect(await h.files.readControl('previous.json'), previousBefore);
        expect(await h.files.readControl('transaction.json'), null);
        expect(h.store.plans.last.name, 'Keep latest');
        expect(h.store.isReplacing, false);
      },
    );
  }

  for (final stage in ['rollbackSettingsWritten', 'rollbackPlansWritten']) {
    test('process interruption at $stage can repeat rollback safely', () async {
      final h = await BackupHarness.create();
      addTearDown(h.close);
      h.store.addPlan(name: 'Original', iconId: 'book', plannedSeconds: 60);
      await h.store.flush();
      h.planStorage.failWrite = h.planStorage.writes + 1;
      final service = h.service(
        checkpoint: (phase) async {
          if (phase == stage) throw _ProcessDeath();
        },
      );
      await expectLater(
        service.restore(_replacement()),
        throwsA(isA<_ProcessDeath>()),
      );
      expect(await h.files.readControl('transaction.json'), isNotNull);
      await h.service(live: false).recoverPending();
      expect(
        StudyPlanSnapshot.decode(h.planStorage.value).plans.single.name,
        'Original',
      );
      expect(await h.files.readControl('transaction.json'), null);
      expect(await h.files.readControl('previous.json'), null);
    });
  }

  for (final stage in ['committed', 'previousRotated']) {
    test(
      'post-commit $stage failure finishes on restart without reverting new data',
      () async {
        final h = await BackupHarness.create();
        addTearDown(h.close);
        h.store.addPlan(name: 'Original', iconId: 'book', plannedSeconds: 60);
        final service = h.service(
          checkpoint: (phase) async {
            if (phase == stage) {
              throw const FileSystemException('Housekeeping failed');
            }
          },
        );
        await service.restore(_replacement());
        expect(h.store.plans.single.name, 'Imported');
        expect(await h.files.readControl('transaction.json'), isNotNull);
        final restarted = h.service(live: false);
        expect(await restarted.recoverPending(), true);
        expect(
          StudyPlanSnapshot.decode(h.planStorage.value).plans.single.name,
          'Imported',
        );
        expect(
          (await restarted.previousBackup())!.plans.plans.single.name,
          'Original',
        );
        expect(await h.files.readControl('transaction.json'), null);
      },
    );
  }

  test('damaged originals are retained verbatim when replaced through startup recovery', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    h.planStorage.value = 'broken original';
    h.settingsStorage.value = '{"version":99}';
    final service = h.service(live: false);
    await service.restore(_replacement());
    final previous =
        jsonDecode((await h.files.readControl('previous.json'))!) as Map;
    expect(previous['oldPlans'], 'broken original');
    expect(previous['oldSettings'], '{"version":99}');
    expect(previous['backup'], null);
    await expectLater(
      service.previousBackup(),
      throwsA(isA<BackupException>()),
    );
    expect(
      StudyPlanSnapshot.decode(h.planStorage.value).plans.single.name,
      'Imported',
    );
  });
  for (final after in [false, true]) {
    for (final occurrence in [1, 2]) {
      test(
        'ambiguous journal write $occurrence after=$after respects commit boundary',
        () async {
          final h = await BackupHarness.create();
          addTearDown(h.close);
          h.store.addPlan(name: 'Original', iconId: 'book', plannedSeconds: 60);
          h.files.failControl = 'transaction.json';
          h.files.failControlOccurrence = occurrence;
          h.files.failAfterControlWrite = after;
          final service = h.service();
          if (occurrence == 2 && after) {
            await service.restore(_replacement());
            expect(h.store.plans.single.name, 'Imported');
            expect(
              (await service.previousBackup())!.plans.plans.single.name,
              'Original',
            );
          } else {
            await expectLater(
              service.restore(_replacement()),
              throwsA(isA<FileSystemException>()),
            );
            expect(h.store.plans.single.name, 'Original');
          }
          expect(await h.files.readControl('transaction.json'), null);
          expect(h.store.isReplacing, false);
          expect(service.requiresRecovery, false);
        },
      );
    }
  }

  test(
    'partial media write failure removes only new files and keeps originals',
    () async {
      final h = await BackupHarness.create();
      addTearDown(h.close);
      final oldIcon = await h.icon();
      h.store.addPlan(
        name: 'Original',
        iconId: 'book',
        plannedSeconds: 50,
        customIconPath: oldIcon,
      );
      h.files.failMediaWrite = true;
      final backup = _replacement(
        icon: 'media_1',
        media: [
          BackupMedia(
            id: 'media_1',
            kind: 'icon',
            extension: '.png',
            bytes: await backupTestPng(),
          ),
        ],
      );
      await expectLater(
        h.service().restore(backup),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(oldIcon).exists(), true);
      final files = await File(oldIcon).parent.list().toList();
      expect(files.map((f) => f.path), [oldIcon]);
      expect(h.store.plans.single.customIconPath, oldIcon);
    },
  );

  test('referenced files and recovery copies cannot be cleared during a transaction', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    final icon = await h.icon();
    h.store.addPlan(
      name: 'Protected',
      iconId: 'book',
      plannedSeconds: 50,
      customIconPath: icon,
    );
    final service = h.service(
      checkpoint: (phase) async {
        if (phase == 'prepared') throw _ProcessDeath();
      },
    );
    await expectLater(
      service.restore(_replacement()),
      throwsA(isA<_ProcessDeath>()),
    );
    expect(await h.files.isProtectedMedia(icon), true);
    await expectLater(
      h.files.clearRecoveryCopies(),
      throwsA(isA<BackupException>()),
    );
    await h.service(live: false).recoverPending();
    expect(await h.files.isProtectedMedia(icon), false);
    await h.service(live: false).restore(_replacement());
    expect(await h.files.readControl('previous.json'), isNotNull);
    await h.files.clearRecoveryCopies();
    expect(await h.files.readControl('previous.json'), null);
  });
}
