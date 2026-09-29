import 'package:flutter/material.dart';

import '../data/study_icon_catalog.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';

class StudyPlanCard extends StatelessWidget {
  const StudyPlanCard({super.key, required this.plan, required this.onStart});

  final StudyPlan plan;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = plan.isCompletedToday
        ? '今日计划已完成'
        : plan.hasStartedToday
        ? '今日剩余 ${formatStudyDuration(plan.remainingSeconds)}'
        : '今日计划 ${formatStudyDuration(plan.plannedSeconds)}';

    return Card(
      key: ValueKey('plan_card_${plan.id}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 92,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  studyIconFor(plan.iconId).icon,
                  key: ValueKey('plan_icon_${plan.id}'),
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: plan.hasStartedToday ? colors.primary : null,
                        fontWeight: plan.hasStartedToday
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                    if (plan.hasStartedToday)
                      Text(
                        '计划 ${formatStudyDuration(plan.plannedSeconds)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 104,
                height: 48,
                child: FilledButton(
                  key: ValueKey('start_plan_${plan.id}'),
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    plan.isCompletedToday
                        ? '查看进度'
                        : plan.hasStartedToday
                        ? '继续学习'
                        : '开始学习',
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
