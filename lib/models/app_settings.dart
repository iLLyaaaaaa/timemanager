import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.showSeconds = true,
    this.completionAlertEnabled = true,
    this.dailyResetHour = 0,
    this.dailyResetMinute = 0,
    this.defaultPlanMinutes = 60,
    this.confirmBeforeDelete = true,
  });

  final ThemeMode themeMode;
  final bool showSeconds;
  final bool completionAlertEnabled;
  final int dailyResetHour;
  final int dailyResetMinute;
  final int defaultPlanMinutes;
  final bool confirmBeforeDelete;

  // Background timing is fixed to pause until reliable background execution exists.
  bool get pauseWhenBackgrounded => true;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? showSeconds,
    bool? completionAlertEnabled,
    int? dailyResetHour,
    int? dailyResetMinute,
    int? defaultPlanMinutes,
    bool? confirmBeforeDelete,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    showSeconds: showSeconds ?? this.showSeconds,
    completionAlertEnabled:
        completionAlertEnabled ?? this.completionAlertEnabled,
    dailyResetHour: dailyResetHour ?? this.dailyResetHour,
    dailyResetMinute: dailyResetMinute ?? this.dailyResetMinute,
    defaultPlanMinutes: defaultPlanMinutes ?? this.defaultPlanMinutes,
    confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
  );

  Map<String, Object> toJson() => {
    'themeMode': themeMode.name,
    'showSeconds': showSeconds,
    'completionAlertEnabled': completionAlertEnabled,
    'dailyResetHour': dailyResetHour,
    'dailyResetMinute': dailyResetMinute,
    'defaultPlanMinutes': defaultPlanMinutes,
    'confirmBeforeDelete': confirmBeforeDelete,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final mode = json['themeMode'];
    final hour = json['dailyResetHour'];
    final minute = json['dailyResetMinute'];
    final minutes = json['defaultPlanMinutes'];
    return AppSettings(
      themeMode:
          ThemeMode.values.where((item) => item.name == mode).firstOrNull ??
          ThemeMode.system,
      showSeconds: json['showSeconds'] is bool
          ? json['showSeconds'] as bool
          : true,
      completionAlertEnabled: json['completionAlertEnabled'] is bool
          ? json['completionAlertEnabled'] as bool
          : true,
      dailyResetHour: hour is int && hour >= 0 && hour < 24 ? hour : 0,
      dailyResetMinute: minute is int && minute >= 0 && minute < 60
          ? minute
          : 0,
      defaultPlanMinutes:
          minutes is int && minutes > 0 && minutes <= 0x7fffffffffffffff ~/ 60
          ? minutes
          : 60,
      confirmBeforeDelete: json['confirmBeforeDelete'] is bool
          ? json['confirmBeforeDelete'] as bool
          : true,
    );
  }
}
