import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';

import '../l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../models/study_plan.dart';

/// Owns the single preview player and OS scheduled completion alerts.
class TimerAlertService {
  TimerAlertService({
    AudioPlayer? player,
    FlutterLocalNotificationsPlugin? notifications,
  }) : _player = player ?? AudioPlayer(),
       _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  final AudioPlayer _player;
  final FlutterLocalNotificationsPlugin _notifications;
  Future<void>? _initialization;
  final Map<String, int> _generation = {};

  Future<void> _initialize() => _initialization ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<bool> notificationsEnabled() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _initialize();
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _initialize();
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> exactAlarmsEnabled() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _initialize();
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestExactAlarmPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _initialize();
      return await _android?.requestExactAlarmsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> preview(int sound) async {
    if (sound < 1 || sound > 5) return;
    await _player.stop();
    await _player.setAudioContext(
      AudioContextConfig(respectSilence: true).build(),
    );
    await _player.play(AssetSource('sounds/timer_bell_$sound.wav'));
  }

  Future<void> stopPreview() => _player.stop();

  Future<void> complete(AppSettings settings) async {
    try {
      switch (settings.timerAlertMode) {
        case 'sound':
          await preview(settings.selectedAlertSound);
        case 'vibration':
          if (await Vibration.hasVibrator()) {
            await Vibration.vibrate(pattern: [0, 160, 110, 160]);
          }
        case 'none':
          break;
      }
    } catch (_) {
      // A missing audio device or denied OS capability must never stop progress.
    }
  }

  static int _notificationId(String planId) {
    var hash = 2166136261;
    for (final codeUnit in planId.codeUnits) {
      hash = ((hash ^ codeUnit) * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> scheduleBackgroundCompletion({
    required StudyPlan plan,
    required AppSettings settings,
    required AppLocalizations l10n,
  }) async {
    final generation = (_generation[plan.id] ?? 0) + 1;
    _generation[plan.id] = generation;
    if (plan.remainingSeconds <= 0 || settings.timerAlertMode == 'none') return;
    try {
      await _initialize();
      if (!await notificationsEnabled()) return;
      final android = _android;
      final exact = await android?.canScheduleExactNotifications() ?? false;
      if (_generation[plan.id] != generation) return;
      final sound = settings.selectedAlertSound.clamp(1, 5);
      final soundMode = settings.timerAlertMode == 'sound';
      final details = AndroidNotificationDetails(
        soundMode ? 'timer_sound_${sound}_v1' : 'timer_vibration_v1',
        soundMode ? 'Timer Sound $sound' : 'Timer Vibration',
        importance: Importance.high,
        priority: Priority.high,
        playSound: soundMode,
        sound: soundMode
            ? RawResourceAndroidNotificationSound('timer_bell_$sound')
            : null,
        enableVibration: !soundMode,
        vibrationPattern: soundMode
            ? null
            : Int64List.fromList([0, 160, 110, 160]),
      );
      await _notifications.zonedSchedule(
        id: _notificationId(plan.id),
        scheduledDate: tz.TZDateTime.now(tz.UTC)
            .add(Duration(seconds: plan.remainingSeconds)),
        notificationDetails: NotificationDetails(android: details),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: l10n.studyCompleteTitle,
        body: l10n.notificationBody(plan.name),
      );
      if (_generation[plan.id] != generation) {
        await _notifications.cancel(id: _notificationId(plan.id));
      }
    } catch (_) {
      // The countdown still works if notifications are unavailable.
    }
  }

  Future<void> cancelBackgroundCompletion(String planId) async {
    _generation[planId] = (_generation[planId] ?? 0) + 1;
    try {
      await _initialize();
      await _notifications.cancel(id: _notificationId(planId));
    } catch (_) {
      // Notification APIs can be unavailable on tests and non-Android hosts.
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
