import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/study_icon_catalog.dart';
import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../models/app_settings.dart';
import '../utils/study_duration.dart';
import '../widgets/study_duration_input.dart';
import '../services/timer_alert_service.dart';

class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({
    super.key,
    required this.store,
    required this.planId,
    this.settings,
    this.now,
    this.alerts,
  });

  final StudyPlanStore store;
  final String planId;
  final SettingsStore? settings;
  final DateTime Function()? now;
  final TimerAlertService? alerts;

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _isLeaving = false;
  bool _isRunning = false;
  DateTime? _backgroundedAt;
  late final TimerAlertService _alerts = widget.alerts ?? TimerAlertService();
  bool _completionHandled = false;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_backgroundedAt != null && _isRunning) {
        unawaited(_alerts.cancelBackgroundCompletion(widget.planId));
        _applyBackgroundElapsed();
        final plan = widget.store.planById(widget.planId);
        if (plan != null && plan.hasStartedToday && plan.remainingSeconds > 0) {
          _startTimer();
        } else {
          _finishSession(plan, fromBackground: true);
        }
        if (mounted) setState(() {});
        unawaited(widget.store.flush());
      }
      return;
    }
    if (!_isRunning) return;
    if (state == AppLifecycleState.detached) {
      _applyBackgroundElapsed();
      _stopSession();
      unawaited(widget.store.flush());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final plan = widget.store.planById(widget.planId);
      if (plan?.pauseWhenBackgrounded ?? true) {
        unawaited(_pause());
      } else if (_backgroundedAt == null) {
        _backgroundedAt = _now();
        _stopTimer();
        if (plan != null && mounted) {
          unawaited(
            _alerts.scheduleBackgroundCompletion(
              plan: plan,
              settings: widget.settings?.settings ?? const AppSettings(),
              l10n: AppLocalizations.of(context)!,
            ),
          );
        }
        unawaited(widget.store.flush());
      }
    }
  }

  void _applyBackgroundElapsed() {
    final started = _backgroundedAt;
    _backgroundedAt = null;
    if (started == null) return;
    final seconds = _now().difference(started).inSeconds;
    if (seconds > 0) widget.store.studySeconds(widget.planId, seconds);
  }

  void _start() {
    if (_isRunning) return;
    final plan = widget.store.planById(widget.planId);
    if (plan == null || plan.isCompletedToday) return;
    widget.store.startOrResume(widget.planId);
    _completionHandled = false;
    _isRunning = true;
    if (!plan.pauseWhenBackgrounded) {
      unawaited(_offerBackgroundPermission());
    }
    _startTimer();
    setState(() {});
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
  }

  void _startTimer() {
    if (_timer != null || !_isRunning || _backgroundedAt != null) return;
    final plan = widget.store.planById(widget.planId);
    if (plan == null || !plan.hasStartedToday || plan.remainingSeconds == 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      widget.store.studyOneSecond(widget.planId);
      final current = widget.store.planById(widget.planId);
      if (current == null ||
          !current.hasStartedToday ||
          current.remainingSeconds == 0) {
        _finishSession(current);
      }
    });
  }

  void _finishSession(StudyPlan? plan, {bool fromBackground = false}) {
    if (_completionHandled || !_isRunning) return;
    _completionHandled = true;
    _stopSession();
    if (mounted) setState(() {});
    final settings = widget.settings?.settings ?? const AppSettings();
    if (plan?.isCompletedToday == true &&
        mounted &&
        settings.timerAlertMode != 'none' &&
        !fromBackground) {
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
    _backgroundedAt = null;
    _isRunning = false;
  }

  Future<void> _pause() async {
    unawaited(_alerts.cancelBackgroundCompletion(widget.planId));
    _applyBackgroundElapsed();
    _stopSession();
    setState(() {});
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
    unawaited(_alerts.cancelBackgroundCompletion(widget.planId));
    _applyBackgroundElapsed();
    _stopSession();
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
    _applyBackgroundElapsed();
    _stopSession();
    unawaited(_alerts.cancelBackgroundCompletion(widget.planId));
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.studyTimer),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Row(
              children: [
                Icon(
                  studyIconFor(plan.iconId).icon,
                  key: const ValueKey('timer_plan_icon'),
                  size: 32,
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
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)!
                  .todayPlanTotal(formatStudyDuration(plan.plannedSeconds)),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: (remainingSeconds / totalSeconds).clamp(
                          0.0,
                          1.0,
                        ),
                        strokeWidth: 12,
                        color: accent,
                        backgroundColor: accent.withValues(alpha: 0.12),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.remainingTime,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatStudyDuration(remainingSeconds),
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          completed
                              ? AppLocalizations.of(context)!.completedToday
                              : AppLocalizations.of(context)!
                                    .focusEncouragement,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.studiedTime),
                    Text(
                      formatStudyDuration(plan.studiedSeconds),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
