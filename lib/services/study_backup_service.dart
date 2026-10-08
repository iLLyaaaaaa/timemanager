import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/settings_store.dart';
import '../data/study_plan_storage.dart';
import '../data/study_plan_store.dart';
import '../data/study_snapshot.dart';
import '../models/app_settings.dart';
import '../models/study_plan.dart';
import '../models/study_backup.dart';
import 'backup_file_access.dart';
import 'timer_alert_service.dart';

Uint8List _encodeBackup(StudyBackup backup) => backup.encode();
String _encodeSnapshot(StudyPlanSnapshot snapshot) => snapshot.encode();
String _encodePreviousCopy((String, String, String, StudyBackup?) copy) =>
    jsonEncode({
      'version': 1,
      'id': copy.$1,
      'oldPlans': copy.$2,
      'oldSettings': copy.$3,
      'backup': copy.$4?.toJson(),
    });

class StudyBackupService {
  StudyBackupService({
    required this.planStorage,
    required this.settingsStorage,
    this.store,
    this.settings,
    BackupFileAccess? files,
    DateTime Function()? now,
    Future<void> Function()? cancelNotifications,
    this.checkpoint,
  }) : files = files ?? BackupFileAccess(),
       _now = now ?? DateTime.now,
       _cancelNotifications = cancelNotifications ?? _cancelAllNotifications;

  factory StudyBackupService.forStores(
    StudyPlanStore store,
    SettingsStore settings, {
    BackupFileAccess? files,
    Future<void> Function()? cancelNotifications,
  }) => StudyBackupService(
    store: store,
    settings: settings,
    planStorage: store.storage ?? _MemoryPlanStorage(store.snapshot.encode()),
    settingsStorage:
        settings.storage ??
        _MemorySettingsStorage(jsonEncode(settings.settings.toJson())),
    files: files,
    now: () => store.currentTime,
    cancelNotifications: cancelNotifications,
  );

  final StudyPlanStorage planStorage;
  final AppSettingsStorage settingsStorage;
  final StudyPlanStore? store;
  final SettingsStore? settings;
  final BackupFileAccess files;
  final DateTime Function() _now;
  final Future<void> Function() _cancelNotifications;

  /// Transaction boundaries are injectable to simulate failures/process death.
  final Future<void> Function(String)? checkpoint;
  bool _busy = false;
  bool requiresRecovery = false;
  DateTime get currentTime => _now();

  static Future<void> _cancelAllNotifications() async {
    final alerts = TimerAlertService();
    try {
      await alerts.cancelAllCompletions();
    } finally {
      await alerts.dispose();
    }
  }

  Future<void> _step(String name) async => await checkpoint?.call(name);

  Future<StudyBackup> capture() async {
    if (_busy || requiresRecovery) throw const BackupException('busy');
    if (store?.hasLoadError == true || settings?.hasLoadError == true) {
      throw const BackupException('read');
    }
    final instant = _now();
    final values =
        settings?.settings ??
        decodeSettingsSnapshot(await settingsStorage.read());
    final snapshot =
        (store?.snapshot ?? StudyPlanSnapshot.decode(await planStorage.read()))
            .pausedAt(instant, settings: values);
    return _capture(snapshot, values, instant);
  }

  Future<StudyBackup> _capture(
    StudyPlanSnapshot snapshot,
    AppSettings values,
    DateTime instant,
  ) async {
    final assets = <BackupMedia>[];
    final missing = <String>[];
    final references = <String, String?>{};
    var total = 0;
    Future<String?> media(String? path, String kind, String label) async {
      if (path == null) return null;
      final key = '$kind:${p.normalize(path)}';
      if (!references.containsKey(key)) {
        Uint8List? bytes;
        try {
          bytes = await files.readMedia(path, kind);
        } catch (_) {
          bytes = null;
        }
        final extension = p.extension(path).toLowerCase();
        if (bytes != null &&
            (kind == 'icon'
                    ? const ['.jpg', '.jpeg', '.png', '.webp']
                    : const ['.wav'])
                .contains(extension)) {
          final item = BackupMedia(
            id: 'media_${assets.length + 1}',
            kind: kind,
            extension: extension,
            bytes: bytes,
          );
          try {
            await files.validateMedia(item);
            total += bytes.length;
            if (total > maxBackupBytes * 3 ~/ 4) {
              throw const BackupException('tooLarge');
            }
            assets.add(item);
            references[key] = item.id;
          } on BackupException catch (error) {
            if (error.code == 'tooLarge') rethrow;
            references[key] = null;
          }
        } else {
          references[key] = null;
        }
      }
      if (references[key] == null) missing.add('$kind:$label');
      return references[key];
    }

    final plans = <StudyPlan>[];
    for (final plan in snapshot.plans) {
      final id = await media(plan.customIconPath, 'icon', plan.name);
      plans.add(plan.copyWith(customIconPath: id, clearCustomIcon: id == null));
    }
    final sound = await media(
      values.customSoundPath,
      'sound',
      values.customSoundName ?? '',
    );
    return StudyBackup(
      createdAt: instant,
      appVersion: '0.1.8+9',
      plans: StudyPlanSnapshot(
        plans: plans,
        records: snapshot.records,
        nextId: snapshot.nextId,
      ),
      settings: values.copyWith(
        customSoundPath: sound,
        clearCustomSound: sound == null,
        soundSource: sound == null ? 'builtin' : values.soundSource,
      ),
      media: assets,
      missingMedia: missing,
    );
  }

  Future<bool> export(StudyBackup backup) async {
    if (_busy || requiresRecovery) throw const BackupException('busy');
    _busy = true;
    try {
      final bytes = await compute(_encodeBackup, backup);
      final time = backup.createdAt.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      final filename =
          'TimeManager-backup-${time.year}${two(time.month)}${two(time.day)}-'
          '${two(time.hour)}${two(time.minute)}${two(time.second)}.json';
      return await files.saveBackup(bytes, filename);
    } finally {
      _busy = false;
    }
  }

  Future<StudyBackup?> chooseBackup() async {
    if (_busy || requiresRecovery) throw const BackupException('busy');
    final bytes = await files.pickBackup();
    return bytes == null ? null : inspect(bytes);
  }

  Future<StudyBackup> inspect(Uint8List bytes) async {
    final backup = await compute(StudyBackup.decode, bytes);
    for (final media in backup.media) {
      await files.validateMedia(media);
    }
    return backup;
  }

  static Map<String, dynamic> _control(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['id'] is! String ||
        value['oldPlans'] is! String ||
        value['oldSettings'] is! String) {
      throw const BackupException('recovery');
    }
    return value;
  }

  static StudyBackup _previousBackup(String raw) {
    final value = _control(raw);
    if (value['backup'] == null) {
      throw const BackupException('previousUnreadable');
    }
    return StudyBackup.decode(
      Uint8List.fromList(utf8.encode(jsonEncode(value['backup']))),
    );
  }

  Future<StudyBackup?> previousBackup() async {
    if (_busy || requiresRecovery) throw const BackupException('busy');
    await recoverPending();
    final raw = await files.readControl('previous.json');
    if (raw == null) return null;
    final backup = await compute(_previousBackup, raw);
    for (final media in backup.media) {
      await files.validateMedia(media);
    }
    return backup;
  }

  static Future<Set<String>> _references(String plansRaw, String settingsRaw) =>
      compute(_collectReferences, (plansRaw, settingsRaw));

  static Set<String> _collectReferences((String, String) raw) {
    final paths = <String>{};
    try {
      paths.addAll(
        StudyPlanSnapshot.decode(raw.$1).plans
            .map((p) => p.customIconPath)
            .whereType<String>(),
      );
      final sound = decodeSettingsSnapshot(raw.$2).customSoundPath;
      if (sound != null) paths.add(sound);
    } on FormatException {
      /* Damaged originals are retained, never normalized. */
    }
    return paths;
  }

  Future<void> _install(String planRaw, String settingsRaw) async {
    if (store == null || settings == null) return;
    final values = decodeSettingsSnapshot(settingsRaw);
    final snapshot = await compute(StudyPlanSnapshot.decode, planRaw);
    settings!.acceptRestoredSettings(values);
    store!.acceptRestoredSnapshot(snapshot);
  }

  void _unlock() {
    if (store?.isReplacing == true) store!.endReplacement();
    if (settings?.isReplacing == true) settings!.endReplacement();
  }

  Future<void> restore(StudyBackup input) async {
    if (_busy || requiresRecovery) throw const BackupException('busy');
    _busy = true;
    var prepared = false;
    var committed = false;
    try {
      await recoverPending();
      // Revalidate at the service boundary, including callers outside the UI.
      final backup = await inspect(await compute(_encodeBackup, input));
      if (store != null && !store!.hasLoadError && !await store!.retrySave()) {
        throw const BackupException('save');
      }
      if (settings != null &&
          !settings!.hasLoadError &&
          !await settings!.retrySave()) {
        throw const BackupException('save');
      }
      store?.beginReplacement();
      settings?.beginReplacement();
      final instant = _now();
      var oldPlans =
          await planStorage.read() ?? StudyPlanSnapshot.decode(null).encode();
      var oldSettings =
          await settingsStorage.read() ??
          jsonEncode(const AppSettings().toJson());
      StudyBackup? previous;
      try {
        final values = settings?.hasLoadError == false
            ? settings!.settings
            : decodeSettingsSnapshot(oldSettings);
        final snapshot =
            (store?.hasLoadError == false
                    ? store!.snapshot
                    : StudyPlanSnapshot.decode(oldPlans))
                .pausedAt(instant, settings: values);
        oldPlans = await compute(_encodeSnapshot, snapshot);
        oldSettings = jsonEncode(values.toJson());
        previous = await _capture(snapshot, values, instant);
      } on FormatException {
        /* Keep both original raw snapshots on corruption. */
      }
      final oldPreviousRaw = await files.readControl('previous.json');
      final obsolete = <String>{};
      if (oldPreviousRaw != null) {
        final prior = await compute(_control, oldPreviousRaw);
        obsolete.addAll(
          await _references(
            prior['oldPlans'] as String,
            prior['oldSettings'] as String,
          ),
        );
      }
      final destinations = <String, String>{};
      for (final media in backup.media) {
        destinations[media.id] = await files.newMediaPath(media);
      }
      final newPlans = StudyPlanSnapshot(
        plans: backup.plans.plans.map((plan) {
          final path = destinations[plan.customIconPath];
          return plan.copyWith(
            customIconPath: path,
            clearCustomIcon: path == null,
          );
        }),
        records: backup.plans.records,
        nextId: backup.plans.nextId,
      );
      final sound = destinations[backup.settings.customSoundPath];
      final newSettings = backup.settings.copyWith(
        customSoundPath: sound,
        clearCustomSound: sound == null,
      );
      final planRaw = await compute(
        _encodeSnapshot,
        newPlans.pausedAt(instant, settings: newSettings, resetDay: true),
      );
      final settingsRaw = jsonEncode(newSettings.toJson());
      final id =
          '${instant.microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
      if (previous != null) await compute(_encodeBackup, previous);
      await files.writeControl(
        'candidate.json',
        await compute(_encodePreviousCopy, (
          id,
          oldPlans,
          oldSettings,
          previous,
        )),
      );
      final journal = <String, Object?>{
        'version': 1,
        'id': id,
        'phase': 'prepared',
        'oldPlans': oldPlans,
        'oldSettings': oldSettings,
        'newPlans': planRaw,
        'newSettings': settingsRaw,
        'newFiles': destinations.values.toList(),
        'obsoleteFiles': obsolete.toList(),
      };
      prepared = true;
      requiresRecovery = true;
      await files.writeControl(
        'transaction.json',
        await compute(jsonEncode, journal),
      );
      await _step('prepared');
      await _cancelNotifications();
      for (final media in backup.media) {
        await files.writeMedia(destinations[media.id]!, media.bytes);
      }
      await _step('mediaWritten');
      await settingsStorage.write(settingsRaw);
      await _step('settingsWritten');
      await planStorage.write(planRaw);
      await _step('plansWritten');
      journal['phase'] = 'committed';
      await files.writeControl(
        'transaction.json',
        await compute(jsonEncode, journal),
      );
      committed = true;
      requiresRecovery = false;
      await _install(planRaw, settingsRaw);
      try {
        await _step('committed');
        await _finishCommitted(journal);
      } on Exception {
        // Both data snapshots are committed; startup can finish housekeeping.
      }
    } on Exception {
      if (prepared && !committed) {
        try {
          if (await recoverPending()) return;
        } on Exception {
          throw const BackupException('recovery');
        }
      } else if (!prepared) {
        try {
          await files.deleteControl('candidate.json');
        } on Exception {
          /* Retain orphan. */
        }
      }
      rethrow;
    } finally {
      _busy = false;
      if (!requiresRecovery) _unlock();
    }
  }

  Future<void> _finishCommitted(Map<String, dynamic> journal) async {
    final candidateRaw = await files.readControl('candidate.json');
    if (candidateRaw != null) {
      if ((await compute(_control, candidateRaw))['id'] != journal['id']) {
        throw const BackupException('recovery');
      }
      await files.promotePrevious();
    } else {
      final previousRaw = await files.readControl('previous.json');
      if (previousRaw == null ||
          (await compute(_control, previousRaw))['id'] != journal['id']) {
        throw const BackupException('recovery');
      }
    }
    await _step('previousRotated');
    final protected =
        (await _references(
          journal['oldPlans'] as String,
          journal['oldSettings'] as String,
        ))..addAll(
          await _references(
            await planStorage.read() ?? journal['newPlans'] as String,
            await settingsStorage.read() ?? journal['newSettings'] as String,
          ),
        );
    for (final path in (journal['obsoleteFiles'] as List).cast<String>()) {
      await files.deleteMedia(path, protected: protected);
    }
    await files.deleteControl('transaction.json');
  }

  Future<bool> recoverPending() async {
    final raw = await files.readControl('transaction.json');
    if (raw == null) {
      requiresRecovery = false;
      return false;
    }
    requiresRecovery = true;
    try {
      final journal = await compute(_control, raw);
      if (!const ['prepared', 'committed'].contains(journal['phase']) ||
          journal['newPlans'] is! String ||
          journal['newSettings'] is! String ||
          journal['newFiles'] is! List ||
          journal['obsoleteFiles'] is! List) {
        throw const BackupException('recovery');
      }
      final paths = (journal['newFiles'] as List).cast<String>();
      for (final path in paths) {
        if (!await files.isRestoreMediaPath(path)) {
          throw const BackupException('recovery');
        }
      }
      if (store != null && !store!.isReplacing) {
        await store!.flush();
        store!.beginReplacement();
      }
      if (settings != null && !settings!.isReplacing) {
        await settings!.flush();
        settings!.beginReplacement();
      }
      await _cancelNotifications();
      if (journal['phase'] == 'committed') {
        await _finishCommitted(journal);
        if (store != null && settings != null) {
          if (!store!.isReplacing) store!.beginReplacement();
          if (!settings!.isReplacing) settings!.beginReplacement();
          await _install(
            await planStorage.read() ?? journal['newPlans'] as String,
            await settingsStorage.read() ?? journal['newSettings'] as String,
          );
        }
      } else {
        await settingsStorage.write(journal['oldSettings'] as String);
        await _step('rollbackSettingsWritten');
        await planStorage.write(journal['oldPlans'] as String);
        await _step('rollbackPlansWritten');
        await _install(
          journal['oldPlans'] as String,
          journal['oldSettings'] as String,
        );
        final protected = await _references(
          journal['oldPlans'] as String,
          journal['oldSettings'] as String,
        );
        final previousRaw = await files.readControl('previous.json');
        if (previousRaw != null) {
          final previous = await compute(_control, previousRaw);
          protected.addAll(
            await _references(
              previous['oldPlans'] as String,
              previous['oldSettings'] as String,
            ),
          );
        }
        for (final path in paths) {
          await files.deleteMedia(path, protected: protected);
        }
        await files.deleteControl('candidate.json');
        await files.deleteControl('transaction.json');
      }
      requiresRecovery = false;
      _unlock();
      return journal['phase'] == 'committed';
    } on Exception {
      throw const BackupException('recovery');
    }
  }
}

class _MemoryPlanStorage implements StudyPlanStorage {
  _MemoryPlanStorage(this.value);
  String value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class _MemorySettingsStorage implements AppSettingsStorage {
  _MemorySettingsStorage(this.value);
  String value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
