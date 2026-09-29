import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const _soundChannel = MethodChannel('timemanager/notification_sound');
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

  Future<void> previewCustom(String path) async {
    if (!await File(path).exists()) {
      throw const FormatException('Missing sound');
    }
    await _player.stop();
    await _player.setAudioContext(
      AudioContextConfig(respectSilence: true).build(),
    );
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stopPreview() => _player.stop();

  Future<void> complete(AppSettings settings) async {
    try {
      switch (settings.timerAlertMode) {
        case 'sound':
          if (settings.soundSource == 'custom' &&
              settings.customSoundPath != null) {
            try {
              await previewCustom(settings.customSoundPath!);
            } catch (_) {
              await preview(settings.selectedAlertSound);
            }
          } else {
            await preview(settings.selectedAlertSound);
          }
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

  static int notificationIdForSession(String sessionId) {
    var hash = 2166136261;
    for (final codeUnit in sessionId.codeUnits) {
      hash = ((hash ^ codeUnit) * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('TimeManager alert: $message');
  }

  Future<bool> scheduleBackgroundCompletion({
    required StudyPlan plan,
    required AppSettings settings,
    required AppLocalizations l10n,
  }) async {
    final sessionId = plan.sessionId;
    if (sessionId == null) return false;
    final generation = (_generation[sessionId] ?? 0) + 1;
    _generation[sessionId] = generation;
    final notificationId = notificationIdForSession(sessionId);
    if (plan.remainingSeconds <= 0 ||
        settings.timerAlertMode == 'none' ||
        plan.targetEndTime == null) {
      return false;
    }
    try {
      await _initialize();
      if (!await notificationsEnabled()) {
        _log('schedule skipped: notifications disabled, id=$notificationId');
        return false;
      }
      final android = _android;
      final exact = await android?.canScheduleExactNotifications() ?? false;
      if (_generation[sessionId] != generation) return false;
      final sound = settings.selectedAlertSound.clamp(1, 5);
      final soundMode = settings.timerAlertMode == 'sound';
      AndroidNotificationSound? notificationSound;
      var channelId = 'timer_vibration_v2';
      var channelName = 'Timer Vibration';
      if (soundMode) {
        channelId = 'timer_sound_${sound}_v2';
        channelName = 'Timer Sound $sound';
        notificationSound = RawResourceAndroidNotificationSound(
          'timer_bell_$sound',
        );
        final path = settings.customSoundPath;
        if (settings.soundSource == 'custom' && path != null) {
          try {
            final uri = await _soundChannel.invokeMethod<String>(
              'contentUriForSound',
              {'path': path},
            );
            if (uri == null || uri.isEmpty) throw const FormatException();
            channelId =
                'timer_custom_${notificationIdForSession(path).toRadixString(16)}_v1';
            channelName = 'Timer Custom Sound';
            notificationSound = UriAndroidNotificationSound(uri);
          } catch (error) {
            _log(
              'custom sound unavailable; using built-in sound (${error.runtimeType})',
            );
          }
        }
      }
      if (_generation[sessionId] != generation) return false;
      final details = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: soundMode,
        sound: notificationSound,
        enableVibration: !soundMode,
        vibrationPattern: soundMode
            ? null
            : Int64List.fromList([0, 500, 250, 500]),
      );
      _log(
        'schedule id=$notificationId target=${plan.targetEndTime!.toIso8601String()} '
        'mode=${settings.timerAlertMode} channel=$channelId exact=$exact',
      );
      await _notifications.zonedSchedule(
        id: notificationId,
        scheduledDate: tz.TZDateTime.from(plan.targetEndTime!, tz.UTC),
        notificationDetails: NotificationDetails(android: details),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: l10n.studyCompleteTitle,
        body: l10n.notificationBody(plan.name),
        payload: plan.id,
      );
      if (_generation[sessionId] != generation) {
        await _notifications.cancel(id: notificationId);
        return false;
      }
      return true;
    } catch (error) {
      _log('schedule failed id=$notificationId (${error.runtimeType})');
      return false;
    }
  }

  Future<void> cancelBackgroundCompletion(String sessionId) async {
    _generation[sessionId] = (_generation[sessionId] ?? 0) + 1;
    final id = notificationIdForSession(sessionId);
    _log('cancel id=$id');
    try {
      await _initialize();
      await _notifications.cancel(id: id);
    } catch (error) {
      _log('cancel failed id=$id (${error.runtimeType})');
    }
  }

  Future<void> cancelAllCompletions() async {
    for (final sessionId in _generation.keys.toList()) {
      _generation[sessionId] = _generation[sessionId]! + 1;
    }
    try {
      await _initialize();
      await _notifications.cancelAll();
    } catch (_) {
      // Notification APIs can be unavailable on tests and non-Android hosts.
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
