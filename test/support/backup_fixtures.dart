import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_storage.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/services/backup_file_access.dart';
import 'package:hello_app/services/study_backup_service.dart';
import 'package:path/path.dart' as p;

class BackupPlanStorage implements StudyPlanStorage {
  String? value;
  bool failReads = false;
  bool failWrites = false;
  int? failWrite;
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<String?> read() async {
    if (failReads) throw const FileSystemException('Simulated read failure');
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    await gate?.future;
    if (failWrites || writes == failWrite) {
      throw const FileSystemException('Simulated write failure');
    }
    this.value = value;
  }
}

class BackupSettingsStorage implements AppSettingsStorage {
  String? value;
  bool failReads = false;
  bool failWrites = false;
  int? failWrite;
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<String?> read() async {
    if (failReads) throw const FileSystemException('Simulated read failure');
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    await gate?.future;
    if (failWrites || writes == failWrite) {
      throw const FileSystemException('Simulated write failure');
    }
    this.value = value;
  }
}

class BackupTestFiles extends BackupFileAccess {
  BackupTestFiles(Directory root) : super(rootDirectory: root);
  Uint8List? selected;
  Uint8List? saved;
  String? savedName;
  bool cancelSave = false;
  int saves = 0;
  Completer<void>? saveGate;
  String? failControl;
  int failControlOccurrence = 1;
  bool failAfterControlWrite = false;
  bool failMediaWrite = false;
  final controlWrites = <String, int>{};
  @override
  Future<void> writeControl(String name, String value) async {
    final number = controlWrites.update(name, (n) => n + 1, ifAbsent: () => 1);
    if (name == failControl && number == failControlOccurrence) {
      if (failAfterControlWrite) await super.writeControl(name, value);
      throw const FileSystemException('Simulated control write failure');
    }
    await super.writeControl(name, value);
  }

  @override
  Future<void> writeMedia(String path, Uint8List bytes) async {
    if (failMediaWrite) {
      await super.writeMedia(path, Uint8List.fromList([1]));
      throw const FileSystemException('Simulated partial media write failure');
    }
    await super.writeMedia(path, bytes);
  }

  @override
  Future<Uint8List?> pickBackup() async => selected;
  @override
  Future<bool> saveBackup(Uint8List bytes, String filename) async {
    saves++;
    await saveGate?.future;
    if (cancelSave) return false;
    saved = bytes;
    savedName = filename;
    return true;
  }
}

class BackupHarness {
  BackupHarness._(this.directory) : files = BackupTestFiles(directory) {
    settings = SettingsStore(storage: settingsStorage);
    store = StudyPlanStore(
      storage: planStorage,
      settings: settings,
      now: () => now,
    );
  }
  static Future<BackupHarness> create() async => BackupHarness._(
    await Directory.systemTemp.createTemp('timemanager_backup_'),
  );
  final Directory directory;
  final BackupTestFiles files;
  final planStorage = BackupPlanStorage();
  final settingsStorage = BackupSettingsStorage();
  late final SettingsStore settings;
  late final StudyPlanStore store;
  DateTime now = DateTime(2026, 10, 8, 12);
  int cancellations = 0;

  StudyBackupService service({
    Future<void> Function(String)? checkpoint,
    bool live = true,
  }) => StudyBackupService(
    planStorage: planStorage,
    settingsStorage: settingsStorage,
    store: live ? store : null,
    settings: live ? settings : null,
    files: files,
    now: () => now,
    cancelNotifications: () async {
      cancellations++;
    },
    checkpoint: checkpoint,
  );

  Future<String> icon({String name = 'test.png'}) async {
    final file = File(p.join(directory.path, 'custom_icons', name));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await backupTestPng());
    return file.path;
  }

  Future<String> sound() async {
    final file = File(p.join(directory.path, 'custom_sounds', 'test.wav'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(backupTestWav());
    return file.path;
  }

  Future<void> close() async {
    await Future.wait([store.flush(), settings.flush()]);
    store.dispose();
    settings.dispose();
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    final root = await directory.resolveSymbolicLinks();
    if (!p.isWithin(temp, root) ||
        !p.basename(root).startsWith('timemanager_backup_')) {
      throw StateError('Unexpected fixture cleanup path');
    }
    await directory.delete(recursive: true);
  }
}

Future<Uint8List> backupTestPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 2, 2),
    ui.Paint()..color = const ui.Color(0xff6a5acd),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Uint8List backupTestWav() {
  const rate = 8000;
  final bytes = Uint8List(44 + rate * 2);
  final data = ByteData.sublistView(bytes);
  void text(int at, String value) =>
      bytes.setRange(at, at + value.length, value.codeUnits);
  text(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, rate * 2, Endian.little);
  return bytes;
}
