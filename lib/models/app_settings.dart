import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.completionAlertEnabled = true,
    this.dailyResetHour = 0,
    this.dailyResetMinute = 0,
    this.defaultPlanSeconds = 3600,
    this.confirmBeforeDelete = true,
    this.homeHeadline = '每天进步一点点',
    this.homeHeadlineCustomized = false,
    this.localeCode = 'zh',
    this.timerAlertMode = 'sound',
    this.selectedAlertSound = 1,
    this.soundSource = 'builtin',
    this.customSoundPath,
    this.customSoundName,
  });

  final ThemeMode themeMode;
  final bool completionAlertEnabled;
  final int dailyResetHour;
  final int dailyResetMinute;
  final int defaultPlanSeconds;
  final bool confirmBeforeDelete;
  final String homeHeadline;
  final bool homeHeadlineCustomized;
  final String localeCode;
  final String timerAlertMode;
  final int selectedAlertSound;
  final String soundSource;
  final String? customSoundPath;
  final String? customSoundName;

  DateTime studyDate(DateTime timestamp) {
    final beforeReset =
        timestamp.hour * 60 + timestamp.minute <
        dailyResetHour * 60 + dailyResetMinute;
    return DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day - (beforeReset ? 1 : 0),
    );
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? completionAlertEnabled,
    int? dailyResetHour,
    int? dailyResetMinute,
    int? defaultPlanSeconds,
    bool? confirmBeforeDelete,
    String? homeHeadline,
    bool? homeHeadlineCustomized,
    String? localeCode,
    String? timerAlertMode,
    int? selectedAlertSound,
    String? soundSource,
    String? customSoundPath,
    String? customSoundName,
    bool clearCustomSound = false,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    completionAlertEnabled:
        completionAlertEnabled ?? this.completionAlertEnabled,
    dailyResetHour: dailyResetHour ?? this.dailyResetHour,
    dailyResetMinute: dailyResetMinute ?? this.dailyResetMinute,
    defaultPlanSeconds: defaultPlanSeconds ?? this.defaultPlanSeconds,
    confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
    homeHeadline: homeHeadline ?? this.homeHeadline,
    homeHeadlineCustomized:
        homeHeadlineCustomized ??
        (homeHeadline != null ? true : this.homeHeadlineCustomized),
    localeCode: localeCode ?? this.localeCode,
    timerAlertMode: timerAlertMode ?? this.timerAlertMode,
    selectedAlertSound: selectedAlertSound ?? this.selectedAlertSound,
    soundSource: soundSource ?? this.soundSource,
    customSoundPath: clearCustomSound
        ? null
        : customSoundPath ?? this.customSoundPath,
    customSoundName: clearCustomSound
        ? null
        : customSoundName ?? this.customSoundName,
  );

  Map<String, Object?> toJson() => {
    'version': 4,
    'themeMode': themeMode.name,
    'completionAlertEnabled': completionAlertEnabled,
    'dailyResetHour': dailyResetHour,
    'dailyResetMinute': dailyResetMinute,
    'defaultPlanSeconds': defaultPlanSeconds,
    'confirmBeforeDelete': confirmBeforeDelete,
    'homeHeadline': homeHeadline,
    'homeHeadlineCustomized': homeHeadlineCustomized,
    'localeCode': localeCode,
    'timerAlertMode': timerAlertMode,
    'selectedAlertSound': selectedAlertSound,
    'soundSource': soundSource,
    'customSoundPath': customSoundPath,
    'customSoundName': customSoundName,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('version') &&
        json['version'] != 2 &&
        json['version'] != 3 &&
        json['version'] != 4) {
      throw const FormatException('Unknown settings version');
    }
    final mode = json['themeMode'];
    final hour = json['dailyResetHour'];
    final minute = json['dailyResetMinute'];
    final seconds = json['defaultPlanSeconds'];
    final legacyMinutes = json['defaultPlanMinutes'];
    final headline = json['homeHeadline'];
    if (headline != null &&
        (headline is! String ||
            headline.trim().isEmpty ||
            headline.characters.length > 40)) {
      throw const FormatException('Invalid home headline');
    }
    if (seconds != null && (seconds is! int || seconds <= 0)) {
      throw const FormatException('Invalid default plan duration');
    }
    if (seconds == null &&
        legacyMinutes != null &&
        (legacyMinutes is! int ||
            legacyMinutes <= 0 ||
            legacyMinutes > 0x7fffffffffffffff ~/ 60)) {
      throw const FormatException('Invalid legacy default plan duration');
    }
    return AppSettings(
      themeMode:
          ThemeMode.values.where((item) => item.name == mode).firstOrNull ??
          ThemeMode.system,
      completionAlertEnabled: json['completionAlertEnabled'] is bool
          ? json['completionAlertEnabled'] as bool
          : true,
      dailyResetHour: hour is int && hour >= 0 && hour < 24 ? hour : 0,
      dailyResetMinute: minute is int && minute >= 0 && minute < 60
          ? minute
          : 0,
      defaultPlanSeconds: seconds is int && seconds > 0
          ? seconds
          : legacyMinutes is int &&
                legacyMinutes > 0 &&
                legacyMinutes <= 0x7fffffffffffffff ~/ 60
          ? legacyMinutes * 60
          : 3600,
      confirmBeforeDelete: json['confirmBeforeDelete'] is bool
          ? json['confirmBeforeDelete'] as bool
          : true,
      homeHeadline: headline is String ? headline : '每天进步一点点',
      homeHeadlineCustomized: json['homeHeadlineCustomized'] is bool
          ? json['homeHeadlineCustomized'] as bool
          : headline is String && headline != '每天进步一点点',
      localeCode: json['localeCode'] == 'en' ? 'en' : 'zh',
      timerAlertMode:
          const ['sound', 'vibration', 'none'].contains(json['timerAlertMode'])
          ? json['timerAlertMode'] as String
          : json['completionAlertEnabled'] == false
          ? 'none'
          : 'sound',
      selectedAlertSound:
          json['selectedAlertSound'] is int &&
              (json['selectedAlertSound'] as int) >= 1 &&
              (json['selectedAlertSound'] as int) <= 5
          ? json['selectedAlertSound'] as int
          : 1,
      soundSource:
          json['soundSource'] == 'custom' && json['customSoundPath'] is String
          ? 'custom'
          : 'builtin',
      customSoundPath: json['customSoundPath'] is String
          ? json['customSoundPath'] as String
          : null,
      customSoundName: json['customSoundName'] is String
          ? json['customSoundName'] as String
          : null,
    );
  }
}
