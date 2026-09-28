import 'dart:async';

import 'package:flutter/material.dart';

import '../data/study_icon_catalog.dart';
import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';

class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({
    super.key,
    required this.store,
    required this.planId,
    this.settings,
  });

  final StudyPlanStore store;
  final String planId;
  final SettingsStore? settings;

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_timer != null) _pause();
    }
  }

  void _start() {
    if (_timer != null) return;
    final plan = widget.store.planById(widget.planId);
    if (plan == null || plan.isCompletedToday) return;
    widget.store.startOrResume(widget.planId);
    _startTimer();
    setState(() {});
  }

  void _startTimer() {
    if (_timer != null) return;
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
        _stopTimer();
        if (current?.remainingSeconds == 0 &&
            mounted &&
            (widget.settings?.settings.completionAlertEnabled ?? true)) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('太棒了，今日学习计划完成！')));
        }
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _pause() async {
    _stopTimer();
    setState(() {});
    final saved = await widget.store.flush();
    if (!saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('学习进度暂未写入本地，请稍后重试')));
    }
  }

  Future<void> _adjustTime() async {
    if (_isLeaving) return;
    if (_timer != null) await _pause();
    if (!mounted) return;
    final plan = widget.store.planById(widget.planId);
    if (plan == null) return;
    final currentSeconds = plan.hasStartedToday
        ? plan.remainingSeconds
        : plan.plannedMinutes * 60;
    var input = '';
    final formKey = GlobalKey<FormState>();
    final minutes = await showDialog<int>(
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
              Text('当前剩余 ${_formatTime(currentSeconds, remaining: true)}'),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('adjust_minutes'),
                onChanged: (value) => input = value,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '新的剩余时间',
                  suffixText: '分钟',
                  border: OutlineInputBorder(),
                ),
                validator: (text) {
                  if (text == null || text.trim().isEmpty) {
                    return '请输入剩余分钟数';
                  }
                  final value = int.tryParse(text.trim());
                  if (value == null ||
                      value <= 0 ||
                      value > 0x7fffffffffffffff ~/ 60) {
                    return '请输入大于 0 的整数分钟数';
                  }
                  return null;
                },
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
                Navigator.of(dialogContext).pop(int.parse(input.trim()));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (!mounted || minutes == null) return;
    widget.store.adjustRemainingMinutes(widget.planId, minutes);
    final saved = await widget.store.flush();
    if (!saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('学习进度暂未写入本地，请稍后重试')));
    }
  }

  Future<void> _leavePage() async {
    if (_isLeaving) return;
    _isLeaving = true;
    _stopTimer();
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
    _stopTimer();
    widget.store.flush();
    super.dispose();
  }

  String _formatTime(int seconds, {bool remaining = false}) {
    if (widget.settings?.settings.showSeconds == false) {
      final minutes = remaining ? (seconds + 59) ~/ 60 : seconds ~/ 60;
      return '$minutes 分钟';
    }
    final minutes = seconds ~/ 60;
    final extraSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${extraSeconds.toString().padLeft(2, '0')}';
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
    final totalSeconds = plan.plannedMinutes * 60;
    final remainingSeconds = plan.hasStartedToday
        ? plan.remainingSeconds
        : totalSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习计时'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _isLeaving ? null : _adjustTime,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('调整时间'),
          ),
          const SizedBox(width: 8),
        ],
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
              '今日计划总时长 ${plan.plannedMinutes} 分钟',
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
                          _formatTime(remainingSeconds, remaining: true),
                          style: TextStyle(
                            fontSize:
                                widget.settings?.settings.showSeconds == false
                                ? 36
                                : 48,
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
            const SizedBox(height: 32),
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
                      _formatTime(plan.studiedSeconds),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            if (!completed)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLeaving
                      ? null
                      : _timer == null
                      ? _start
                      : _pause,
                  icon: Icon(
                    _timer == null
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                  label: Text(_timer == null ? '开始' : '暂停'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
