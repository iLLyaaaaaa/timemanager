import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/study_backup.dart';
import '../data/study_snapshot.dart';

/// System file dialogs and app-private files, injectable for tests.
class BackupFileAccess {
  BackupFileAccess({this.rootDirectory});
  Directory? rootDirectory;
  Future<Directory> get root async =>
      rootDirectory ??= await getApplicationSupportDirectory();

  Future<Uint8List?> pickBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    return readPickedBackup(file);
  }

  Future<Uint8List> readPickedBackup(PlatformFile file) async {
    final size = file.lengthSync() ?? await file.length();
    if (size == null || size <= 0) throw const BackupException('invalid');
    if (size > maxBackupBytes) {
      throw const BackupException('tooLarge');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (builder.length + chunk.length > maxBackupBytes) {
        throw const BackupException('tooLarge');
      }
      builder.add(chunk);
    }
    if (builder.isEmpty) throw const BackupException('invalid');
    return builder.takeBytes();
  }

  Future<bool> saveBackup(Uint8List bytes, String filename) async =>
      await FilePicker.saveFile(
        fileName: filename,
        bytes: bytes,
        mimeType: 'application/json',
      ) !=
      null;

  Future<String?> _safeMedia(String path, String kind) async {
    final directory = Directory(p.join((await root).path, 'custom_${kind}s'));
    final normalized = p.normalize(p.absolute(path));
    if (!p.isWithin(directory.path, normalized)) return null;
    final file = File(normalized);
    if (!await file.exists()) return null;
    final realRoot = await directory.resolveSymbolicLinks();
    final realFile = await file.resolveSymbolicLinks();
    return p.isWithin(realRoot, realFile) ? realFile : null;
  }

  Future<Uint8List?> readMedia(String path, String kind) async {
    final safe = await _safeMedia(path, kind);
    if (safe == null) return null;
    final file = File(safe);
    final length = await file.length();
    if (length <= 0 || length > (kind == 'icon' ? 8 : 50) * 1024 * 1024) {
      return null;
    }
    return file.readAsBytes();
  }

  Future<void> validateMedia(BackupMedia media) async {
    if (media.kind == 'icon') {
      try {
        final codec = await ui.instantiateImageCodec(
          media.bytes,
          targetWidth: 512,
          targetHeight: 512,
          allowUpscaling: false,
        );
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      } catch (_) {
        throw const BackupException('media');
      }
    } else {
      _validateWav(media.bytes);
    }
  }

  void _validateWav(Uint8List bytes) {
    if (bytes.length < 44 ||
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      throw const BackupException('media');
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(4, Endian.little) + 8 > bytes.length) {
      throw const BackupException('media');
    }
    int? byteRate;
    var audioBytes = 0;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final name = ascii.decode(
        bytes.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      final size = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (start + size > bytes.length) throw const BackupException('media');
      if (name == 'fmt ') {
        if (size < 16 ||
            data.getUint16(start, Endian.little) != 1 ||
            !const [1, 2].contains(data.getUint16(start + 2, Endian.little)) ||
            data.getUint16(start + 14, Endian.little) != 16) {
          throw const BackupException('media');
        }
        final channels = data.getUint16(start + 2, Endian.little);
        final sampleRate = data.getUint32(start + 4, Endian.little);
        byteRate = data.getUint32(start + 8, Endian.little);
        if (sampleRate == 0 ||
            byteRate != sampleRate * channels * 2 ||
            data.getUint16(start + 12, Endian.little) != channels * 2) {
          throw const BackupException('media');
        }
      } else if (name == 'data') {
        audioBytes += size;
      }
      offset = start + size + (size.isOdd ? 1 : 0);
    }
    if (byteRate == null || audioBytes == 0 || audioBytes > byteRate * 30) {
      throw const BackupException('media');
    }
  }

  Future<String> newMediaPath(BackupMedia media) async {
    final directory = Directory(
      p.join((await root).path, 'custom_${media.kind}s'),
    );
    await directory.create(recursive: true);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    return p.join(directory.path, 'restore_$id${media.extension}');
  }

  Future<void> writeMedia(String path, Uint8List bytes) async {
    if (!await isRestoreMediaPath(path)) {
      throw const BackupException('recovery');
    }
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<bool> isRestoreMediaPath(String path) async {
    final base = (await root).path;
    return ['custom_icons', 'custom_sounds'].any(
      (kind) =>
          p.isWithin(p.join(base, kind), path) &&
          p.dirname(p.normalize(path)) == p.join(base, kind) &&
          RegExp(r'^restore_[0-9]+_[0-9]+\.(jpg|jpeg|png|webp|wav)$')
              .hasMatch(p.basename(path)),
    );
  }

  Future<void> deleteMedia(
    String path, {
    Set<String> protected = const {},
  }) async {
    if (protected.contains(path)) return;
    for (final kind in ['icon', 'sound']) {
      final safe = await _safeMedia(path, kind);
      if (safe != null) {
        await File(safe).delete();
        return;
      }
    }
  }

  Future<File> _control(String name) async {
    if (!const [
      'transaction.json',
      'candidate.json',
      'previous.json',
    ].contains(name)) {
      throw const BackupException('recovery');
    }
    final directory = Directory(p.join((await root).path, 'backup_recovery'));
    await directory.create(recursive: true);
    return File(p.join(directory.path, name));
  }

  Future<String?> readControl(String name) async {
    final file = await _control(name);
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> writeControl(String name, String value) async {
    final file = await _control(name);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(value, flush: true);
    await temp.rename(file.path);
  }

  Future<void> deleteControl(String name) async {
    final file = await _control(name);
    if (await file.exists()) await file.delete();
  }

  Future<void> promotePrevious() async {
    final file = await _control('candidate.json');
    if (await file.exists()) {
      await file.rename((await _control('previous.json')).path);
    }
  }

  Future<bool> isProtectedMedia(String path) async {
    final raw = await readControl('transaction.json');
    if (raw == null) return false;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      for (final prefix in ['old', 'new']) {
        final plans = StudyPlanSnapshot.decode(
          value['${prefix}Plans'] as String,
        );
        final settings = decodeSettingsSnapshot(
          value['${prefix}Settings'] as String,
        );
        if (plans.plans.any((plan) => plan.customIconPath == path) ||
            settings.customSoundPath == path) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<void> clearRecoveryCopies() async {
    if (await readControl('transaction.json') != null) {
      throw const BackupException('recovery');
    }
    for (final name in ['previous.json', 'candidate.json']) {
      await deleteControl(name);
      final temp = File('${(await _control(name)).path}.tmp');
      if (await temp.exists()) await temp.delete();
    }
  }
}
