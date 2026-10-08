import 'dart:convert';
import 'dart:typed_data';

import '../data/study_snapshot.dart';
import 'app_settings.dart';

const maxBackupBytes = 64 * 1024 * 1024;

class BackupException implements Exception {
  const BackupException(this.code);
  final String code;
  @override
  String toString() => 'BackupException($code)';
}

class BackupMedia {
  const BackupMedia({
    required this.id,
    required this.kind,
    required this.extension,
    required this.bytes,
  });
  final String id;
  final String kind;
  final String extension;
  final Uint8List bytes;
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'extension': extension,
    'bytes': base64Encode(bytes),
  };
}

class StudyBackup {
  StudyBackup({
    required this.createdAt,
    required this.appVersion,
    required this.plans,
    required this.settings,
    Iterable<BackupMedia> media = const [],
    Iterable<String> missingMedia = const [],
  }) : media = List.unmodifiable(media),
       missingMedia = List.unmodifiable(missingMedia);
  final DateTime createdAt;
  final String appVersion;
  final StudyPlanSnapshot plans;
  final AppSettings settings;
  final List<BackupMedia> media;
  final List<String> missingMedia;

  Map<String, Object?> toJson() => {
    'format': 'timemanager-backup',
    'version': 1,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'plans': plans.toJson(),
    'settings': settings.toJson(),
    'media': media.map((m) => m.toJson()).toList(),
    'missingMedia': missingMedia,
  };

  Uint8List encode() {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
    if (bytes.length > maxBackupBytes) throw const BackupException('tooLarge');
    return bytes;
  }

  static StudyBackup decode(Uint8List bytes) {
    if (bytes.isEmpty) throw const BackupException('invalid');
    if (bytes.length > maxBackupBytes) {
      throw const BackupException('tooLarge');
    }
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic> ||
          value['format'] != 'timemanager-backup') {
        throw const BackupException('invalid');
      }
      if (value['version'] != 1) throw const BackupException('version');
      if (value['createdAt'] is! String ||
          value['appVersion'] is! String ||
          value['plans'] is! Map ||
          value['settings'] is! Map ||
          value['media'] is! List ||
          (value['plans'] as Map)['version'] != 5 ||
          (value['settings'] as Map)['version'] != 4) {
        throw const BackupException('invalid');
      }
      final createdAt = DateTime.tryParse(value['createdAt'] as String);
      if (createdAt == null) throw const BackupException('invalid');
      final planJson = value['plans'] as Map;
      if (planJson['nextId'] is! int ||
          (planJson['nextId'] as int) <= 0 ||
          planJson['plans'] is! List ||
          planJson['records'] is! List) {
        throw const BackupException('invalid');
      }
      for (final plan in planJson['plans'] as List) {
        if (plan is! Map ||
            plan['plannedSeconds'] is! int ||
            (plan['plannedSeconds'] as int) <= 0 ||
            plan['iconId'] is! String ||
            (plan['iconId'] as String).isEmpty ||
            plan['remainingSeconds'] is! int ||
            (plan['remainingSeconds'] as int) < 0 ||
            plan['studiedSeconds'] is! int ||
            (plan['studiedSeconds'] as int) < 0 ||
            plan['hasStartedToday'] is! bool ||
            plan['isCompletedToday'] is! bool ||
            plan['pauseWhenBackgrounded'] is! bool ||
            (plan['progressDay'] != null && plan['progressDay'] is! String) ||
            (plan['customIconPath'] != null &&
                plan['customIconPath'] is! String)) {
          throw const BackupException('invalid');
        }
      }
      final snapshot = StudyPlanSnapshot.decode(jsonEncode(value['plans']));
      final settingsJson = Map<String, dynamic>.from(value['settings'] as Map);
      _validateSettings(settingsJson);
      final settings = decodeSettingsSnapshot(jsonEncode(settingsJson));
      final assets = <BackupMedia>[];
      final ids = <String>{};
      for (final item in value['media'] as List) {
        if (item is! Map ||
            item['id'] is! String ||
            item['bytes'] is! String ||
            !RegExp(r'^media_[0-9]+$').hasMatch(item['id'] as String) ||
            !ids.add(item['id'] as String) ||
            !const ['icon', 'sound'].contains(item['kind']) ||
            !(item['kind'] == 'icon'
                    ? const ['.jpg', '.jpeg', '.png', '.webp']
                    : const ['.wav'])
                .contains(item['extension'])) {
          throw const BackupException('invalid');
        }
        final data = base64Decode(item['bytes'] as String);
        if (data.isEmpty ||
            data.length > (item['kind'] == 'icon' ? 8 : 50) * 1024 * 1024) {
          throw const BackupException('invalid');
        }
        assets.add(
          BackupMedia(
            id: item['id'] as String,
            kind: item['kind'] as String,
            extension: item['extension'] as String,
            bytes: data,
          ),
        );
      }
      final byId = {for (final asset in assets) asset.id: asset};
      final used = <String>{};
      void reference(String? id, String kind) {
        if (id == null) return;
        if (byId[id]?.kind != kind) throw const BackupException('invalid');
        used.add(id);
      }

      for (final plan in snapshot.plans) {
        reference(plan.customIconPath, 'icon');
      }
      reference(settings.customSoundPath, 'sound');
      if (used.length != assets.length ||
          (settings.soundSource == 'custom' &&
              settings.customSoundPath == null)) {
        throw const BackupException('invalid');
      }
      final missing = value['missingMedia'] ?? <String>[];
      if (missing is! List || missing.any((m) => m is! String)) {
        throw const BackupException('invalid');
      }
      // Import never reconstructs elapsed time after the backup was captured.
      final paused = StudyPlanSnapshot(
        plans: snapshot.plans.map(
          (p) => p.withProgress(
            day: p.progressDay,
            remainingSeconds: p.remainingSeconds,
            studiedSeconds: p.studiedSeconds,
            hasStartedToday: p.hasStartedToday,
            isCompletedToday: p.isCompletedToday,
            clearRunning: true,
          ),
        ),
        records: snapshot.records,
        nextId: snapshot.nextId,
      );
      return StudyBackup(
        createdAt: createdAt,
        appVersion: value['appVersion'] as String,
        plans: paused,
        settings: settings,
        media: assets,
        missingMedia: missing.cast<String>(),
      );
    } on BackupException {
      rethrow;
    } on FormatException {
      throw const BackupException('invalid');
    } on TypeError {
      throw const BackupException('invalid');
    } on ArgumentError {
      throw const BackupException('invalid');
    }
  }

  static void _validateSettings(Map<String, dynamic> value) {
    if (!const ['system', 'light', 'dark'].contains(value['themeMode']) ||
        !const ['zh', 'en'].contains(value['localeCode']) ||
        !const [
          'sound',
          'vibration',
          'none',
        ].contains(value['timerAlertMode']) ||
        !const ['custom', 'builtin'].contains(value['soundSource'])) {
      throw const BackupException('invalid');
    }
    for (final key in [
      'completionAlertEnabled',
      'confirmBeforeDelete',
      'homeHeadlineCustomized',
    ]) {
      if (value[key] is! bool) throw const BackupException('invalid');
    }
    for (final (key, min, max) in [
      ('dailyResetHour', 0, 23),
      ('dailyResetMinute', 0, 59),
      ('selectedAlertSound', 1, 5),
      ('defaultPlanSeconds', 1, 0x7fffffffffffffff),
    ]) {
      if (value[key] is! int ||
          (value[key] as int) < min ||
          (value[key] as int) > max) {
        throw const BackupException('invalid');
      }
    }
    if (value['homeHeadline'] is! String ||
        (value['customSoundPath'] != null &&
            value['customSoundPath'] is! String) ||
        (value['customSoundName'] != null &&
            value['customSoundName'] is! String)) {
      throw const BackupException('invalid');
    }
  }
}
