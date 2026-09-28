import 'package:flutter/material.dart';

import '../data/study_icon_catalog.dart';
import '../models/study_plan.dart';

class StudyPlanCard extends StatelessWidget {
  const StudyPlanCard({
    super.key,
    required this.plan,
    required this.onStart,
    this.showSeconds = true,
  });

  final StudyPlan plan;
  final VoidCallback onStart;
  final bool showSeconds;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = plan.isCompletedToday
        ? '今日计划已完成'
        : plan.hasStartedToday
        ? _remainingText(plan.remainingSeconds)
        : '今日计划 ${plan.plannedMinutes} 分钟';

    return Card(
      key: ValueKey('plan_card_${plan.id}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    studyIconFor(plan.iconId).icon,
                    key: ValueKey('plan_icon_${plan.id}'),
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    plan.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: plan.hasStartedToday ? colors.primary : null,
                          fontWeight: plan.hasStartedToday
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                      if (plan.hasStartedToday) ...[
                        const SizedBox(height: 2),
                        Text(
                          '计划 ${plan.plannedMinutes} 分钟',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(onPressed: onStart, child: const Text('开始学习')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _remainingText(int seconds) {
    final minutes = seconds ~/ 60;
    final extraSeconds = seconds % 60;
    if (!showSeconds) return '今日剩余 ${(seconds + 59) ~/ 60} 分钟';
    if (extraSeconds == 0) return '今日剩余 $minutes 分钟';
    return '今日剩余 $minutes 分 $extraSeconds 秒';
  }
}
