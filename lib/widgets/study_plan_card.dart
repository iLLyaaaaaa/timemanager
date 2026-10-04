import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/study_plan.dart';
import '../theme/app_theme.dart';
import '../utils/study_duration.dart';
import 'study_plan_layout.dart';

class StudyPlanCard extends StatelessWidget {
  const StudyPlanCard({super.key, required this.plan, required this.onStart});

  final StudyPlan plan;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final status = plan.isCompletedToday
        ? l10n.completedToday
        : plan.hasStartedToday
        ? l10n.todayRemainingDuration(
            formatStudyDuration(plan.remainingSeconds),
          )
        : l10n.todayPlanDuration(formatStudyDuration(plan.plannedSeconds));

    return Card(
      key: ValueKey('plan_card_${plan.id}'),
      color: colors.surface,
      shape: AppTheme.cardShape(colors),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StudyPlanLayout(
          plan: plan,
          iconKey: ValueKey('plan_icon_${plan.id}'),
          contentBuilder: (context, stacked) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudyPlanTitle(name: plan.name),
              const SizedBox(height: 4),
              Text(
                status,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  color: colors.secondary,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppTheme.durationFeatures,
                ),
              ),
              if (plan.hasStartedToday)
                Text(
                  l10n.planDuration(formatStudyDuration(plan.plannedSeconds)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                    fontFeatures: AppTheme.durationFeatures,
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: stacked ? double.infinity : 112,
                  child: FilledButton(
                    key: ValueKey('start_plan_${plan.id}'),
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(
                      plan.isCompletedToday
                          ? l10n.viewProgress
                          : plan.hasStartedToday
                          ? l10n.continueStudy
                          : l10n.startStudy,
                      textAlign: TextAlign.center,
                    ),
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
