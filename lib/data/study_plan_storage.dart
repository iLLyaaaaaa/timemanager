import 'package:shared_preferences/shared_preferences.dart';

abstract class StudyPlanStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesPlanStorage implements StudyPlanStorage {
  SharedPreferencesPlanStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'study_plans_v5';
  static const _previousKey = 'study_plans_v4';
  static const _olderKey = 'study_plans_v3';
  static const _legacyKey = 'study_plans_v1';
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
