import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

abstract class AppSettingsStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesSettingsStorage implements AppSettingsStorage {
  SharedPreferencesSettingsStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'app_settings_v2';
  static const _legacyKey = 'app_settings_v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() async =>
      await _preferences.getString(_key) ??
      await _preferences.getString(_legacyKey);

  @override
  Future<void> write(String value) => _preferences.setString(_key, value);
}

class SettingsStore extends ChangeNotifier {
  SettingsStore({this.storage, this._settings = const AppSettings()});

  final AppSettingsStorage? storage;
  AppSettings _settings;
  String? _pendingSnapshot;
  Future<void>? _writeTask;
  Object? _lastWriteError;

  static Future<SettingsStore> load({
    required AppSettingsStorage storage,
  }) async {
    final saved = await storage.read();
    if (saved == null) return SettingsStore(storage: storage);
    try {
      final decoded = jsonDecode(saved);
      if (decoded is Map<String, dynamic>) {
        final store = SettingsStore(
          storage: storage,
          settings: AppSettings.fromJson(decoded),
        );
        store._scheduleWrite();
        return store;
      }
    } on FormatException {
      // Keep defaults when a saved value is malformed.
    } on TypeError {
      // Keep defaults when saved fields have incompatible types.
    }
    return SettingsStore(storage: storage);
  }

  AppSettings get settings => _settings;

  DateTime studyDate(DateTime timestamp) {
    final resetMinutes =
        _settings.dailyResetHour * 60 + _settings.dailyResetMinute;
    final currentMinutes = timestamp.hour * 60 + timestamp.minute;
    return currentMinutes < resetMinutes
        ? DateTime(timestamp.year, timestamp.month, timestamp.day - 1)
        : DateTime(timestamp.year, timestamp.month, timestamp.day);
  }

  void update(AppSettings value) {
    _settings = value;
    notifyListeners();
    _scheduleWrite();
  }

  void restoreDefaults() => update(const AppSettings());

  void _scheduleWrite() {
    final target = storage;
    if (target == null) return;
    _pendingSnapshot = jsonEncode(_settings.toJson());
    _writeTask ??= _drainWrites(target);
  }

  Future<void> _drainWrites(AppSettingsStorage target) async {
    while (_pendingSnapshot != null) {
      final snapshot = _pendingSnapshot!;
      _pendingSnapshot = null;
      try {
        await target.write(snapshot);
        _lastWriteError = null;
      } catch (error) {
        _lastWriteError = error;
      }
    }
    _writeTask = null;
  }

  Future<bool> flush() async {
    while (_writeTask != null) {
      await _writeTask;
    }
    return _lastWriteError == null;
  }
}
