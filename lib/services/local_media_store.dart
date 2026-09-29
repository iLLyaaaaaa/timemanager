import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SavedLocalMedia {
  const SavedLocalMedia(this.path, this.name);
  final String path;
  final String name;
}

class PickedLocalSound {
  const PickedLocalSound(this.path, this.name, this.duration);
  final String path;
  final String name;
  final Duration duration;
}

class UnsupportedNcmSound implements Exception {
  const UnsupportedNcmSound();
}

/// Copies SAF selections into durable, app-private files. Null means cancelled.
class LocalMediaStore {
  static const _audioChannel = MethodChannel('timemanager/audio_trim');

  static void validateSoundName(String name) {
    final extension = p.extension(name).toLowerCase();
    if (extension == '.ncm') throw const UnsupportedNcmSound();
    if (!const ['.mp3', '.wav', '.m4a', '.ogg'].contains(extension)) {
      throw const FormatException('Unsupported audio');
    }
  }

  Future<Directory> _directory(String kind) async {
    final root = await getApplicationSupportDirectory();
    return Directory(p.join(root.path, kind))..createSync(recursive: true);
  }

  Future<String> _uniquePath(String kind, String extension) async {
    final Directory directory;
    if (kind == 'media_work') {
      directory = Directory(p.join((await getTemporaryDirectory()).path, kind));
      await directory.create(recursive: true);
    } else {
      directory = await _directory(kind);
    }
    final unique =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    return p.join(directory.path, '$unique$extension');
  }

  Future<SavedLocalMedia?> chooseIcon({required String cropTitle}) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (picked == null) return null;
    final extension = p.extension(picked.name).toLowerCase();
    if (!const ['.png', '.jpg', '.jpeg', '.webp'].contains(extension)) {
      throw const FormatException('Unsupported image');
    }
    if ((picked.lengthSync() ?? await picked.length() ?? 0) > 8 * 1024 * 1024) {
      throw const FormatException('Image too large');
    }
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
      throw const FormatException('Invalid image');
    }
    final codec = await ui.instantiateImageCodec(bytes);
    codec.dispose();
    final input = File(await _uniquePath('media_work', extension));
    await input.writeAsBytes(bytes, flush: true);
    String? croppedPath;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: input.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: cropTitle,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: cropTitle,
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );
      if (cropped == null) return null;
      croppedPath = cropped.path;
      final resultBytes = await File(cropped.path).readAsBytes();
      if (resultBytes.isEmpty || resultBytes.length > 8 * 1024 * 1024) {
        throw const FormatException('Invalid cropped image');
      }
      final resultCodec = await ui.instantiateImageCodec(resultBytes);
      resultCodec.dispose();
      final destination = File(await _uniquePath('custom_icons', '.jpg'));
      await destination.writeAsBytes(resultBytes, flush: true);
      return SavedLocalMedia(destination.path, picked.name);
    } finally {
      await _deleteIfExists(input.path);
      if (croppedPath != null) await _deleteIfExists(croppedPath);
    }
  }

  Future<PickedLocalSound?> chooseSound() async {
    // FileType.any permits a precise NCM explanation instead of hiding it.
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) return null;
    validateSoundName(picked.name);
    final extension = p.extension(picked.name).toLowerCase();
    final size = picked.lengthSync() ?? await picked.length() ?? 0;
    if (size <= 0 || size > 50 * 1024 * 1024) {
      throw const FormatException('Invalid audio size');
    }
    final input = File(await _uniquePath('media_work', extension));
    try {
      if (picked.path != null) {
        await File(picked.path!).copy(input.path);
      } else {
        await input.writeAsBytes(await picked.readAsBytes(), flush: true);
      }
      final durationMs = await _audioChannel.invokeMethod<int>('probe', {
        'inputPath': input.path,
      });
      if (durationMs == null || durationMs < 1000) {
        throw const FormatException('Invalid audio');
      }
      return PickedLocalSound(
        input.path,
        picked.name,
        Duration(milliseconds: durationMs),
      );
    } catch (_) {
      await _deleteIfExists(input.path);
      rethrow;
    }
  }

  Future<SavedLocalMedia> saveTrimmedSound(
    PickedLocalSound picked, {
    required int startMilliseconds,
    required int endMilliseconds,
  }) async {
    if (startMilliseconds < 0 ||
        endMilliseconds <= startMilliseconds ||
        endMilliseconds > picked.duration.inMilliseconds ||
        endMilliseconds - startMilliseconds > 30000) {
      throw const FormatException('Invalid sound selection');
    }
    final output = File(await _uniquePath('custom_sounds', '.wav'));
    try {
      await _audioChannel.invokeMethod<void>('trim', {
        'inputPath': picked.path,
        'outputPath': output.path,
        'startMs': startMilliseconds,
        'endMs': endMilliseconds,
      });
      if (!await output.exists() || await output.length() <= 44) {
        throw const FormatException('Empty sound');
      }
      return SavedLocalMedia(output.path, picked.name);
    } catch (_) {
      await _deleteIfExists(output.path);
      rethrow;
    }
  }

  Future<void> deleteTemporarySound(PickedLocalSound picked) =>
      _deleteIfExists(picked.path);

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteIfManaged(String? filePath, String kind) async {
    if (filePath == null) return;
    final directory = await _directory(kind);
    if (!p.isWithin(directory.path, filePath)) return;
    await _deleteIfExists(filePath);
  }

  Future<void> clearAll() async {
    for (final kind in ['custom_icons', 'custom_sounds']) {
      final directory = await _directory(kind);
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }
}
