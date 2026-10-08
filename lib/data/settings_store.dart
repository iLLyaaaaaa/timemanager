import 'dart:convert';

import 'snapshot_writer.dart';
import 'study_snapshot.dart';

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

  static const _key = 'app_settings_v4';
  static const _previousKey = 'app_settings_v3';
  static const _olderKey = 'app_settings_v2';
  static const _legacyKey = 'app_settings_v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() async =>
      await _preferences.getString(_key) ??
      await _preferences.getString(_previousKey) ??
      await _preferences.getString(_olderKey) ??
      await _preferences.getString(_legacyKey);

  @override
  Future<void> write(String value) => _preferences.setString(_key, value);
}

class SettingsStore extends ChangeNotifier {
  SettingsStore({this.storage, this._settings = const AppSettings()});

  final AppSettingsStorage? storage;
  AppSettings _settings;
  late final _writer = SnapshotWriter(storage?.write)
    ..addListener(_notifyPersistence);
  bool _hasLoadError = false;
  bool _isReplacing = false;
  bool _disposed = false;

  static Future<SettingsStore> load({
    required AppSettingsStorage storage,
  }) async {
    try {
      final raw = await storage.read();
      final store = SettingsStore(
        storage: storage,
        settings: decodeSettingsSnapshot(raw),
      );
      if (raw != null) store._scheduleWrite();
      return store;
    } catch (_) {
      return SettingsStore(storage: storage).._hasLoadError = true;
    }
  }

  bool get hasLoadError => _hasLoadError;
  bool get isSaving => _writer.isSaving;
  bool get hasSaveError => _writer.hasSaveError;
  bool get hasUnsavedChanges => _writer.hasUnsavedChanges;
  bool get isReplacing => _isReplacing;
  void _notifyPersistence() {
    if (!_disposed) notifyListeners();
  }

  void beginReplacement() {
    if (_isReplacing || isSaving) throw StateError('Store is busy');
    _isReplacing = true;
    _notifyPersistence();
  }

  void acceptRestoredSettings(AppSettings value) {
    if (!_isReplacing) throw StateError('Replacement is not active');
    _settings = value;
    _hasLoadError = false;
    _writer.acceptPersisted();
  }

  void endReplacement() {
    _isReplacing = false;
    _notifyPersistence();
  }

  AppSettings get settings => _settings;

  DateTime studyDate(DateTime timestamp) {
    return _settings.studyDate(timestamp);
  }

  void update(AppSettings value) {
    if (_isReplacing) throw StateError('Data replacement is active');
    _settings = value;
    notifyListeners();
    _scheduleWrite();
  }

  void restoreDefaults() => update(const AppSettings());

  void _scheduleWrite() {
    if (_hasLoadError || _isReplacing) return;
    _writer.enqueue(jsonEncode(_settings.toJson()));
  }

  Future<bool> flush() async => !_hasLoadError && await _writer.flush();
  Future<bool> retrySave() async => !_hasLoadError && await _writer.retry();

  @override
  void dispose() {
    _disposed = true;
    _writer.dispose();
    super.dispose();
  }
}
