import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../models/app_settings.dart';
import '../utils/study_duration.dart';
import '../widgets/study_duration_input.dart';
import '../services/timer_alert_service.dart';
import '../widgets/study_plan_icon.dart';
import '../services/screen_state_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/study_timer_display.dart';

class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({
    super.key,
    required this.store,
    required this.planId,
    this.settings,
    this.now,
    this.alerts,
    this.screenState,
  });

  final StudyPlanStore store;
  final String planId;
  final SettingsStore? settings;
  final DateTime Function()? now;
  final TimerAlertService? alerts;
  final ScreenStateService? screenState;

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _isLeaving = false;
  bool _isRunning = false;
  bool _away = false;
  bool _scheduledAlert = false;
  String? _activeSessionId;
  Future<bool>? _scheduleTask;
  int _scheduleGeneration = 0;
  late final TimerAlertService _alerts = widget.alerts ?? TimerAlertService();
  late final ScreenStateService _screenState =
      widget.screenState ?? ScreenStateService();
  bool _completionHandled = false;
  DateTime _now() => widget.now?.call() ?? widget.store.currentTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final plan = widget.store.planById(widget.planId);
    _isRunning = plan?.isRunning ?? false;
    _activeSessionId = plan?.sessionId;
    if (_isRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scheduleCompletion();
          _startTimer();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _away = false;
      if (_isRunning) {
        widget.store.reconcileRunning(widget.planId, now: _now());
        final plan = widget.store.planById(widget.planId);
        if (plan?.isRunning == true) {
          _scheduleCompletion();
          _startTimer();
        } else {
          unawaited(_finishSession(plan, fromBackground: true));
        }
        if (mounted) setState(() {});
        unawaited(widget.store.flush());
      }
      return;
    }
    if (!_isRunning) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_handleAway());
    }
  }

  Future<void> _handleAway() async {
    if (_away || !_isRunning) return;
    _away = true;
    _stopTimer();
    final locked = await _screenState.isScreenLocked();
    if (!mounted || !_isRunning || !_away) return;
    final plan = widget.store.planById(widget.planId);
    if (!locked && (plan?.pauseWhenBackgrounded ?? true)) {
      await _pause();
    } else {
      widget.store.reconcileRunning(widget.planId, now: _now());
      await widget.store.flush();
    }
  }

  void _start() {
    if (_isRunning) return;
    final plan = widget.store.planById(widget.planId);
    if (plan == null || plan.isCompletedToday) return;
    widget.store.beginRunning(widget.planId, now: _now());
    _activeSessionId = widget.store.planById(widget.planId)?.sessionId;
    _completionHandled = false;
    _isRunning = true;
    _scheduledAlert = false;
    _scheduleCompletion();
    unawaited(widget.store.flush());
    if ((widget.settings?.settings.timerAlertMode ?? 'sound') != 'none') {
      unawaited(_offerBackgroundPermission());
    }
    _startTimer();
    setState(() {});
  }

  void _scheduleCompletion() {
    if (_scheduleTask != null || _scheduledAlert) return;
    final plan = widget.store.planById(widget.planId);
    if (plan == null || !mounted || plan.sessionId == null) return;
    final sessionId = plan.sessionId!;
    final generation = ++_scheduleGeneration;
    final task = _alerts.scheduleBackgroundCompletion(
      plan: plan,
      settings: widget.settings?.settings ?? const AppSettings(),
      l10n: AppLocalizations.of(context)!,
    );
    _scheduleTask = task;
    unawaited(
      task.then((scheduled) {
        if (_activeSessionId == sessionId &&
            _scheduleGeneration == generation) {
          _scheduledAlert = scheduled;
          _scheduleTask = null;
        }
      }),
    );
  }

  Future<void> _offerBackgroundPermission() async {
    if (await _alerts.notificationsEnabled() &&
        await _alerts.exactAlarmsEnabled()) {
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.notificationPermissionHint),
        action: SnackBarAction(
          label: l10n.notificationPermissionAction,
          onPressed: () => unawaited(_requestBackgroundPermission()),
        ),
      ),
    );
  }

  Future<void> _requestBackgroundPermission() async {
    if (await _alerts.requestNotificationPermission()) {
      await _alerts.requestExactAlarmPermission();
    }
    final pending = _scheduleTask;
    if (pending != null) await pending;
    if (!mounted || !_isRunning || _activeSessionId == null) return;
    await _alerts.cancelBackgroundCompletion(_activeSessionId!);
    _scheduleGeneration++;
    _scheduledAlert = false;
    _scheduleTask = null;
    _scheduleCompletion();
  }

  void _startTimer() {
    if (_timer != null || !_isRunning || _away) return;
    final plan = widget.store.planById(widget.planId);
    if (plan == null || !plan.hasStartedToday || plan.remainingSeconds == 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      widget.store.reconcileRunning(widget.planId, now: _now());
      final current = widget.store.planById(widget.planId);
      if (current == null ||
          !current.hasStartedToday ||
          current.remainingSeconds == 0) {
        unawaited(_finishSession(current));
      }
    });
  }

  Future<void> _finishSession(
    StudyPlan? plan, {
    bool fromBackground = false,
  }) async {
    if (_completionHandled || !_isRunning) return;
    _completionHandled = true;
    _stopSession();
    if (mounted) setState(() {});
    final settings = widget.settings?.settings ?? const AppSettings();
    final scheduled = await (_scheduleTask ?? Future.value(_scheduledAlert));
    _activeSessionId = null;
    _scheduleTask = null;
    if (plan?.isCompletedToday == true &&
        mounted &&
        settings.timerAlertMode != 'none' &&
        !fromBackground &&
        !scheduled) {
      unawaited(_alerts.complete(settings));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.completeSnack)),
      );
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _stopSession() {
    _stopTimer();
    _isRunning = false;
  }

  Future<void> _pause() async {
    final sessionId =
        _activeSessionId ?? widget.store.planById(widget.planId)?.sessionId;
    widget.store.pauseRunning(widget.planId, now: _now());
    _scheduleGeneration++;
    _activeSessionId = null;
    _scheduleTask = null;
    _scheduledAlert = false;
    _stopSession();
    if (mounted) setState(() {});
    if (sessionId != null) {
      await _alerts.cancelBackgroundCompletion(sessionId);
    }
    final saved = await widget.store.flush();
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.timeSaveFailed)),
      );
    }
  }

  Future<void> _adjustTime() async {
    if (_isLeaving) return;
    if (_isRunning) await _pause();
    if (!mounted) return;
    final plan = widget.store.planById(widget.planId);
    if (plan == null) return;
    final currentSeconds = plan.hasStartedToday
        ? plan.remainingSeconds
        : plan.plannedSeconds;
    final formKey = GlobalKey<FormState>();
    final durationKey = GlobalKey<StudyDurationInputState>();
    final seconds = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.adjustTime),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!
                    .currentRemaining(formatStudyDuration(currentSeconds)),
              ),
              const SizedBox(height: 16),
              StudyDurationInput(
                key: durationKey,
                initialSeconds: currentSeconds,
                label: AppLocalizations.of(context)!.newRemainingTime,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext)
                    .pop(durationKey.currentState!.totalSeconds);
              }
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
    if (!mounted || seconds == null) return;
    widget.store.adjustRemainingSeconds(widget.planId, seconds);
    final saved = await widget.store.flush();
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.timeSaveFailed)),
      );
    }
  }

  Future<void> _leavePage() async {
    if (_isLeaving) return;
    _isLeaving = true;
    if (_isRunning) await _pause();
    final saved = await widget.store.flush();
    if (!mounted) return;
    if (!saved) {
      _isLeaving = false;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.timeSaveFailed)),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Explicit navigation pauses in _leavePage. Android can destroy this
    // page while an allowed background session is running; its OS alarm and
    // persisted target end time must survive that widget disposal.
    _stopSession();
    if (widget.alerts == null) unawaited(_alerts.dispose());
    widget.store.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leavePage();
      },
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final plan = widget.store.planById(widget.planId);
          if (plan == null) {
            return Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(context)!.studyTimer),
              ),
              body: Center(
                child: Text(AppLocalizations.of(context)!.planMissing),
              ),
            );
          }
          return _buildTimer(context, plan);
        },
      ),
    );
  }

  Widget _buildTimer(BuildContext context, StudyPlan plan) {
    final accent = Theme.of(context).colorScheme.primary;
    final completed = plan.isCompletedToday;
    final totalSeconds = plan.plannedSeconds;
    final remainingSeconds = plan.hasStartedToday
        ? plan.remainingSeconds
        : totalSeconds;
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final status = completed
        ? l10n.timerCompleteState
        : _isRunning
        ? l10n.timerRunningState
        : plan.hasStartedToday
        ? l10n.timerPausedState
        : l10n.timerReadyState;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.studyTimer),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            16,
            AppTheme.pagePadding,
            32,
          ),
          children: [
            Row(
              children: [
                StudyPlanIcon(
                  plan: plan,
                  key: const ValueKey('timer_plan_icon'),
                  size: 48,
                  color: accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    plan.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: AppTheme.transitionDuration(context),
                child: Container(
                  key: ValueKey(status),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _isRunning
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _isRunning
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            StudyTimerDisplay(
              remainingSeconds: remainingSeconds,
              plannedSeconds: totalSeconds,
              completed: completed,
            ),
            const SizedBox(height: 28),
            if (!completed)
              SizedBox(
                height: 60,
                child: FilledButton.icon(
                  onPressed: _isLeaving
                      ? null
                      : _isRunning
                      ? _pause
                      : _start,
                  icon: Icon(
                    _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _isRunning
                        ? AppLocalizations.of(context)!.pause
                        : AppLocalizations.of(context)!.start,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isLeaving ? null : _adjustTime,
              icon: const Icon(Icons.edit_outlined),
              label: Text(AppLocalizations.of(context)!.adjustTime),
            ),
            const SizedBox(height: 24),
            AppSectionCard(
              child: AppMetricGrid(
                children: [
                  AppMetric(
                    label: l10n.plannedTime,
                    value: formatStudyDuration(plan.plannedSeconds),
                  ),
                  AppMetric(
                    label: l10n.studiedTime,
                    value: formatStudyDuration(plan.studiedSeconds),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
