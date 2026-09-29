import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/study_plan_store.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import '../widgets/study_plan_icon.dart';

class StudyStatisticsPage extends StatelessWidget {
  const StudyStatisticsPage({super.key, required this.store});

  final StudyPlanStore store;

  @override
  Widget build(BuildContext context) {
    final plans = store.plans;
    final plannedSeconds = plans.fold<int>(
      0,
      (sum, plan) => sum + plan.plannedSeconds,
    );
    final studiedSeconds = plans.fold<int>(
      0,
      (sum, plan) => sum + plan.studiedSeconds,
    );
    final remainingSeconds = plans.fold<int>(
      0,
      (sum, plan) =>
          sum +
          (plan.hasStartedToday ? plan.remainingSeconds : plan.plannedSeconds),
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
                  AppLocalizations.of(context)!.todayOverview,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!
                      .overviewPlanned(formatStudyDuration(plannedSeconds)),
                ),
                Text(
                  AppLocalizations.of(context)!
                      .overviewStudied(formatStudyDuration(studiedSeconds)),
                ),
                Text(
                  AppLocalizations.of(context)!
                      .overviewRemaining(formatStudyDuration(remainingSeconds)),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!
                      .overviewCompletion(_percent(completion)),
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
          AppLocalizations.of(context)!.planProgress,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (plans.isEmpty)
          Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(AppLocalizations.of(context)!.noPlans),
            ),
          )
        else
          for (final plan in plans) ...[
            _PlanStatisticsCard(plan: plan),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}

class _PlanStatisticsCard extends StatelessWidget {
  const _PlanStatisticsCard({required this.plan});

  final StudyPlan plan;

  @override
  Widget build(BuildContext context) {
    final plannedSeconds = plan.plannedSeconds;
    final remainingSeconds = plan.hasStartedToday
        ? plan.remainingSeconds
        : plannedSeconds;
    final completion = _completion(plan.studiedSeconds, plannedSeconds);
    final colors = Theme.of(context).colorScheme;
    final detailStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontSize: 14, height: 1.25, color: colors.onSurfaceVariant);

    return Card(
      key: ValueKey('statistics_${plan.id}'),
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.08),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudyPlanIcon(
                  key: ValueKey('statistics_icon_${plan.id}'),
                  plan: plan,
                  tileSize: StudyPlanIcon.cardTileSize,
                  color: colors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: colors.onSurface,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _percent(completion),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!
                            .statPlanned(formatStudyDuration(plannedSeconds)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: detailStyle,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppLocalizations.of(context)!.statStudied(
                          formatStudyDuration(plan.studiedSeconds),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: detailStyle,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.statRemaining(formatStudyDuration(remainingSeconds)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: detailStyle,
                      ),
                      if (plan.studiedSeconds > plannedSeconds) ...[
                        const SizedBox(height: 3),
                        Text(
                          AppLocalizations.of(context)!.statOver(
                            formatStudyDuration(
                              plan.studiedSeconds - plannedSeconds,
                            ),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: detailStyle,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: completion.clamp(0.0, 1.0),
                minHeight: 8,
                color: colors.primary,
                backgroundColor: colors.surfaceContainerHighest,
              ),
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
