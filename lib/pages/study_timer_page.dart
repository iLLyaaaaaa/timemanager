import 'dart:async';

import 'package:flutter/material.dart';

import '../data/study_icon_catalog.dart';
import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import '../widgets/study_duration_input.dart';

class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({
    super.key,
    required this.store,
    required this.planId,
    this.settings,
    this.now,
  });

  final StudyPlanStore store;
  final String planId;
  final SettingsStore? settings;
  final DateTime Function()? now;

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _isLeaving = false;
  bool _isRunning = false;
  DateTime? _backgroundedAt;

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
        _applyBackgroundElapsed();
        final plan = widget.store.planById(widget.planId);
        if (plan != null && plan.hasStartedToday && plan.remainingSeconds > 0) {
          _startTimer();
        } else {
          _finishSession(plan);
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
    _isRunning = true;
    _startTimer();
    setState(() {});
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

  void _finishSession(StudyPlan? plan) {
    _stopSession();
    if (mounted) setState(() {});
    if (plan?.isCompletedToday == true &&
        mounted &&
        (widget.settings?.settings.completionAlertEnabled ?? true)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('太棒了，今日学习计划完成！')));
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
    _applyBackgroundElapsed();
    _stopSession();
    setState(() {});
    final saved = await widget.store.flush();
    if (!saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('学习进度暂未写入本地，请稍后重试')));
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
        title: const Text('调整时间'),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前剩余 ${formatStudyDuration(currentSeconds)}'),
              const SizedBox(height: 16),
              StudyDurationInput(
                key: durationKey,
                initialSeconds: currentSeconds,
                label: '新的剩余时间',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext)
                    .pop(durationKey.currentState!.totalSeconds);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (!mounted || seconds == null) return;
    widget.store.adjustRemainingSeconds(widget.planId, seconds);
    final saved = await widget.store.flush();
    if (!saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('学习进度暂未写入本地，请稍后重试')));
    }
  }

  Future<void> _leavePage() async {
    if (_isLeaving) return;
    _isLeaving = true;
    _applyBackgroundElapsed();
    _stopSession();
    final saved = await widget.store.flush();
    if (!mounted) return;
    if (!saved) {
      _isLeaving = false;
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('学习进度暂未写入本地，请稍后重试')));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _applyBackgroundElapsed();
    _stopSession();
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
              appBar: AppBar(title: const Text('学习计时')),
              body: const Center(child: Text('这个计划已不存在')),
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
        title: const Text('学习计时'),
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
              '今日计划总时长 ${formatStudyDuration(plan.plannedSeconds)}',
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
                          '剩余时间',
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
                          completed ? '今日计划已完成' : '专注当下，继续加油',
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
                    _isRunning ? '暂停' : '开始',
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
              label: const Text('调整时间'),
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
                    const Text('已学习时间'),
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
