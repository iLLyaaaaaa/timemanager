import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import 'study_plan_icon.dart';
import '../theme/app_theme.dart';

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
      shape: AppTheme.cardShape(colors),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudyPlanIcon(
                  plan: plan,
                  key: ValueKey('plan_icon_${plan.id}'),
                  tileSize: StudyPlanIcon.cardTileSize,
                  color: colors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
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
                          AppLocalizations.of(context)!.planDuration(
                            formatStudyDuration(plan.plannedSeconds),
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 14,
                                color: colors.onSurfaceVariant,
                                fontFeatures: AppTheme.durationFeatures,
                              ),
                        ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width:
                              (constraints.maxWidth -
                                      StudyPlanIcon.cardTileSize -
                                      12)
                                  .clamp(0.0, 112.0),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              plan.isCompletedToday
                                  ? AppLocalizations.of(context)!.viewProgress
                                  : plan.hasStartedToday
                                  ? AppLocalizations.of(context)!.continueStudy
                                  : AppLocalizations.of(context)!.startStudy,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
