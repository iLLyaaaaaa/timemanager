import 'package:flutter/material.dart';

import '../data/study_icon_catalog.dart';
import '../data/study_plan_store.dart';
import '../models/study_plan.dart';

class StudyStatisticsPage extends StatelessWidget {
  const StudyStatisticsPage({
    super.key,
    required this.store,
    this.showSeconds = true,
  });

  final StudyPlanStore store;
  final bool showSeconds;

  @override
  Widget build(BuildContext context) {
    final plans = store.plans;
    final plannedSeconds = plans.fold<int>(
      0,
      (sum, plan) => sum + plan.plannedMinutes * 60,
    );
    final studiedSeconds = plans.fold<int>(
      0,
      (sum, plan) => sum + plan.studiedSeconds,
    );
    final remainingSeconds = plans.fold<int>(
      0,
      (sum, plan) =>
          sum +
          (plan.hasStartedToday
              ? plan.remainingSeconds
              : plan.plannedMinutes * 60),
    );
    final completion = _completion(studiedSeconds, plannedSeconds);
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: colors.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日总览',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text('今日计划总时长：${_duration(plannedSeconds, showSeconds)}'),
                Text('今日已学习：${_duration(studiedSeconds, showSeconds)}'),
                Text('今日剩余：${_duration(remainingSeconds, showSeconds)}'),
                const SizedBox(height: 12),
                Text(
                  '今日完成率：${_percent(completion)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completion.clamp(0.0, 1.0),
                  minHeight: 7,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '各计划进度',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (plans.isEmpty)
          const Card(
            elevation: 0,
            child: Padding(padding: EdgeInsets.all(24), child: Text('还没有学习计划')),
          )
        else
          for (final plan in plans) ...[
            _PlanStatisticsCard(plan: plan, showSeconds: showSeconds),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _PlanStatisticsCard extends StatelessWidget {
  const _PlanStatisticsCard({required this.plan, required this.showSeconds});

  final StudyPlan plan;
  final bool showSeconds;

  @override
  Widget build(BuildContext context) {
    final plannedSeconds = plan.plannedMinutes * 60;
    final remainingSeconds = plan.hasStartedToday
        ? plan.remainingSeconds
        : plannedSeconds;
    final completion = _completion(plan.studiedSeconds, plannedSeconds);
    final colors = Theme.of(context).colorScheme;

    return Card(
      key: ValueKey('statistics_${plan.id}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(studyIconFor(plan.iconId).icon, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(_percent(completion)),
              ],
            ),
            const SizedBox(height: 12),
            Text('计划：${_duration(plannedSeconds, showSeconds)}'),
            Text('已学习：${_duration(plan.studiedSeconds, showSeconds)}'),
            Text('剩余：${_duration(remainingSeconds, showSeconds)}'),
            if (plan.studiedSeconds > plannedSeconds)
              Text(
                '超出计划：${_duration(plan.studiedSeconds - plannedSeconds, showSeconds)}',
              ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: completion.clamp(0.0, 1.0),
              minHeight: 7,
            ),
          ],
        ),
      ),
    );
  }
}

double _completion(int studiedSeconds, int plannedSeconds) {
  if (plannedSeconds == 0) return 0;
  return studiedSeconds / plannedSeconds;
}

String _percent(double value) {
  final percentage = value * 100;
  final decimals = percentage == percentage.roundToDouble() ? 0 : 1;
  return '${percentage.toStringAsFixed(decimals)}%';
}

String _duration(int seconds, bool showSeconds) {
  final minutes = seconds ~/ 60;
  final extraSeconds = seconds % 60;
  if (!showSeconds) return '$minutes 分钟';
  if (extraSeconds == 0) return '$minutes 分钟';
  return '$minutes 分 $extraSeconds 秒';
}
