import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import 'study_plan_icon.dart';

class StudyPlanCard extends StatelessWidget {
  const StudyPlanCard({super.key, required this.plan, required this.onStart});

  final StudyPlan plan;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = plan.isCompletedToday
        ? AppLocalizations.of(context)!.completedToday
        : plan.hasStartedToday
        ? AppLocalizations.of(
            context,
          )!.todayRemainingDuration(formatStudyDuration(plan.remainingSeconds))
        : AppLocalizations.of(context)!
              .todayPlanDuration(formatStudyDuration(plan.plannedSeconds));

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
                child: StudyPlanIcon(
                  plan: plan,
                  key: ValueKey('plan_icon_${plan.id}'),
                  size: 29,
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
                        AppLocalizations.of(context)!.planDuration(
                          formatStudyDuration(plan.plannedSeconds),
                        ),
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
                        ? AppLocalizations.of(context)!.viewProgress
                        : plan.hasStartedToday
                        ? AppLocalizations.of(context)!.continueStudy
                        : AppLocalizations.of(context)!.startStudy,
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
