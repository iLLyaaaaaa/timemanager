import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import '../widgets/study_time_adjustment_dialog.dart';
import '../widgets/save_retry_banner.dart';
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
    this.autoStart = false,
  });

  final StudyPlanStore store;
  final String planId;
  final SettingsStore? settings;
  final DateTime Function()? now;
  final TimerAlertService? alerts;
  final ScreenStateService? screenState;
  final bool autoStart;

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _isLeaving = false;
  bool _isRunning = false;
  bool _operationBusy = false;
  bool _isAdjusting = false;
  bool _resumeAfterAdjustment = false;
  DateTime? _adjustmentDay;
  String? _resumeProgressDay;
  bool _away = false;
  bool _scheduledAlert = false;
  String? _activeSessionId;
  Future<bool>? _scheduleTask;
  int _scheduleGeneration = 0;
  late final TimerAlertService _alerts = widget.alerts ?? TimerAlertService();
  late final ScreenStateService _screenState =
      widget.screenState ?? ScreenStateService();
  bool _completionHandled = false;
  late final _settings =
      widget.settings ?? widget.store.settings ?? SettingsStore();
  DateTime _now() => widget.now?.call() ?? widget.store.currentTime;
  bool get _controlsBusy =>
      _isLeaving || _operationBusy || _isAdjusting || widget.store.isReplacing;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final plan = widget.store.planById(widget.planId);
    _isRunning = plan?.isRunning ?? false;
    _activeSessionId = plan?.sessionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.store.isReplacing) return;
      widget.store.reconcileRunning(widget.planId, now: _now());
      widget.store.refreshForToday();
      final current = widget.store.planById(widget.planId);
      if (current?.isRunning == true) {
        _isRunning = true;
        _activeSessionId = current!.sessionId;
        _scheduleCompletion();
        _startTimer();
        setState(() {});
      } else {
        _stopSession();
        if (widget.autoStart && current != null && !current.isCompletedToday) {
          _start();
        } else {
          setState(() {});
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _away = false;
      if (!_isAdjusting) _resumeAdjustmentIfValid();
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

  void _start({bool offerPermission = true}) {
    if (_isRunning || _controlsBusy || !_foreground || !mounted) return;
    widget.store.refreshForToday();
    final plan = widget.store.planById(widget.planId);
    if (plan == null || plan.isCompletedToday) return;
    final instant = _now();
    try {
      final seconds = plan.hasStartedToday
          ? plan.remainingSeconds
          : plan.plannedSeconds;
      if (seconds <= 0) {
        throw const FormatException('Invalid remaining duration');
      }
      final duration = Duration(seconds: seconds);
      if (duration.inSeconds != seconds) {
        throw const FormatException('Duration is too large');
      }
      instant.add(duration);
      widget.store.beginRunning(widget.planId, now: instant);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.timerStartFailed)),
      );
      return;
    }
    _activeSessionId = widget.store.planById(widget.planId)?.sessionId;
    _completionHandled = false;
    _isRunning = true;
    _scheduledAlert = false;
    _scheduleCompletion();
    unawaited(widget.store.flush());
    if (offerPermission && _settings.settings.timerAlertMode != 'none') {
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
      settings: _settings.settings,
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
          !current.isRunning ||
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
    final settings = _settings.settings;
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

  Future<bool> _pause({bool showFailure = true}) async {
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
    if (!saved && mounted && showFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.timeSaveFailed)),
      );
    }
    return saved;
  }

  Future<void> _pauseControl() async {
    if (_controlsBusy) return;
    setState(() => _operationBusy = true);
    try {
      await _pause(showFailure: false);
    } finally {
      if (mounted) setState(() => _operationBusy = false);
    }
  }

  void _resumeAdjustmentIfValid() {
    if (!_resumeAfterAdjustment ||
        _isAdjusting ||
        !mounted ||
        !_foreground ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _resumeAfterAdjustment = false;
    widget.store.refreshForToday();
    final plan = widget.store.planById(widget.planId);
    if (_isLeaving ||
        widget.store.isReplacing ||
        _settings.studyDate(_now()) != _adjustmentDay ||
        plan == null ||
        !plan.hasStartedToday ||
        plan.isCompletedToday ||
        plan.progressDay != _resumeProgressDay) {
      return;
    }
    _start(offerPermission: false);
  }

  Future<void> _adjustTime() async {
    if (_controlsBusy) return;
    _resumeAfterAdjustment = _isRunning;
    _adjustmentDay = _settings.studyDate(_now());
    setState(() => _isAdjusting = true);
    try {
      if (_isRunning) await _pause(showFailure: false);
      if (!mounted) return;
      widget.store.refreshForToday();
      final plan = widget.store.planById(widget.planId);
      if (plan == null) return;
      _resumeProgressDay = plan.progressDay;
      await showDialog<bool>(
        context: context,
        builder: (_) => StudyTimeAdjustmentDialog(
          initialSeconds: plan.hasStartedToday
              ? plan.remainingSeconds
              : plan.plannedSeconds,
          resumeAfterwards: _resumeAfterAdjustment,
          onApply: (seconds) async {
            if (!mounted) return null;
            widget.store.refreshForToday();
            if (widget.store.planById(widget.planId) == null ||
                widget.store.isReplacing ||
                _settings.studyDate(_now()) != _adjustmentDay) {
              _resumeAfterAdjustment = false;
              return AppLocalizations.of(context)!.timerAdjustmentExpired;
            }
            widget.store.adjustRemainingSeconds(widget.planId, seconds);
            await widget.store.flush();
            return null;
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAdjusting = false);
        _resumeAdjustmentIfValid();
      }
    }
  }

  Future<void> _leavePage() async {
    if (_controlsBusy) return;
    _resumeAfterAdjustment = false;
    setState(() => _isLeaving = true);
    final saved = _isRunning
        ? await _pause(showFailure: false)
        : await widget.store.retrySave();
    if (!mounted) return;
    if (!saved) {
      final l10n = AppLocalizations.of(context)!;
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('timer_unsaved_exit'),
          title: Text(l10n.timerUnsavedTitle),
          content: SingleChildScrollView(
            child: Text(l10n.timerUnsavedExitHint),
          ),
          actions: [
            TextButton(
              key: const ValueKey('stay_on_timer'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.stayOnTimer),
            ),
            FilledButton(
              key: const ValueKey('leave_unsaved_timer'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.keepChangesAndReturn),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (leave != true) {
        setState(() => _isLeaving = false);
        return;
      }
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
    if (widget.settings == null && widget.store.settings == null) {
      _settings.dispose();
    }
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
                leading: _backButton(context),
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

  Widget? _backButton(BuildContext context) {
    if (!Navigator.of(context).canPop()) return null;
    return IconButton(
      key: const ValueKey('timer_back'),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: _controlsBusy ? null : _leavePage,
      icon: const BackButtonIcon(),
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
        leading: _backButton(context),
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
            SaveRetryBanner(
              store: widget.store,
              settings: _settings,
              enabled: !_controlsBusy,
            ),
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
                    semanticsLabel: plan.name,
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
      bottomNavigationBar: Material(
        color: colors.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              12,
              AppTheme.pagePadding,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  key: const ValueKey('timer_main_action'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 60),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onPressed: _controlsBusy
                      ? null
                      : completed
                      ? _leavePage
                      : _isRunning
                      ? _pauseControl
                      : _start,
                  icon: Icon(
                    completed
                        ? Icons.home_outlined
                        : _isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    completed
                        ? l10n.returnHome
                        : _isRunning
                        ? l10n.pause
                        : plan.hasStartedToday
                        ? l10n.resumeTimer
                        : l10n.start,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('timer_adjust_time'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _controlsBusy ? null : _adjustTime,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.adjustTime, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
