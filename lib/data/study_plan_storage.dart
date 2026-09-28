import 'package:shared_preferences/shared_preferences.dart';

abstract class StudyPlanStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesPlanStorage implements StudyPlanStorage {
  SharedPreferencesPlanStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'study_plans_v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(_key);

  @override
  Future<void> write(String value) => _preferences.setString(_key, value);
}
