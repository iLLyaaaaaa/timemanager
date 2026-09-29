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
  });

  final ThemeMode themeMode;
  final bool completionAlertEnabled;
  final int dailyResetHour;
  final int dailyResetMinute;
  final int defaultPlanSeconds;
  final bool confirmBeforeDelete;
  final String homeHeadline;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? completionAlertEnabled,
    int? dailyResetHour,
    int? dailyResetMinute,
    int? defaultPlanSeconds,
    bool? confirmBeforeDelete,
    String? homeHeadline,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    completionAlertEnabled:
        completionAlertEnabled ?? this.completionAlertEnabled,
    dailyResetHour: dailyResetHour ?? this.dailyResetHour,
    dailyResetMinute: dailyResetMinute ?? this.dailyResetMinute,
    defaultPlanSeconds: defaultPlanSeconds ?? this.defaultPlanSeconds,
    confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
    homeHeadline: homeHeadline ?? this.homeHeadline,
  );

  Map<String, Object> toJson() => {
    'version': 2,
    'themeMode': themeMode.name,
    'completionAlertEnabled': completionAlertEnabled,
    'dailyResetHour': dailyResetHour,
    'dailyResetMinute': dailyResetMinute,
    'defaultPlanSeconds': defaultPlanSeconds,
    'confirmBeforeDelete': confirmBeforeDelete,
    'homeHeadline': homeHeadline,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('version') && json['version'] != 2) {
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
    );
  }
}
