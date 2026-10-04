import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/study_plan_store.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import '../utils/study_history.dart';
import '../widgets/study_history_view.dart';
import '../widgets/study_plan_layout.dart';
import '../widgets/app_section_card.dart';
import '../theme/app_theme.dart';
import 'study_review_page.dart';

class StudyStatisticsPage extends StatefulWidget {
  const StudyStatisticsPage({super.key, required this.store});

  final StudyPlanStore store;

  @override
  State<StudyStatisticsPage> createState() => _StudyStatisticsPageState();
}

class _StudyStatisticsPageState extends State<StudyStatisticsPage> {
  bool _showHistory = false;
  bool _restoredView = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restoredView) {
      _showHistory =
          PageStorage.maybeOf(context)
                  ?.readState(context, identifier: 'statistics_show_history')
              as bool? ??
          false;
      _restoredView = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
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
      key: PageStorageKey('statistics_scroll_$_showHistory'),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        12,
        AppTheme.pagePadding,
        24,
      ),
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.today_outlined),
              label: Text(AppLocalizations.of(context)!.statisticsToday),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.history_rounded),
              label: Text(AppLocalizations.of(context)!.recentWeek),
            ),
          ],
          selected: {_showHistory},
          onSelectionChanged: (selection) {
            PageStorage.maybeOf(context)?.writeState(
              context,
              selection.single,
              identifier: 'statistics_show_history',
            );
            setState(() => _showHistory = selection.single);
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('open_study_review'),
            onPressed: store.hasLoadError
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StudyReviewPage(store: store),
                    ),
                  ),
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(AppLocalizations.of(context)!.studyReview),
          ),
        ),
        const SizedBox(height: 16),
        if (_showHistory)
          StudyHistoryView(
            summary: StudyHistorySummary.recentWeek(
              records: store.records,
              lastDay:
                  store.settings?.studyDate(store.currentTime) ??
                  store.currentTime,
            ),
          )
        else ...[
          AppSectionCard(
            highlighted: true,
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
                const SizedBox(height: 20),
                AppMetricGrid(
                  children: [
                    AppMetric(
                      label: AppLocalizations.of(context)!.plannedTime,
                      value: formatStudyDuration(plannedSeconds),
                      foreground: colors.onPrimaryContainer,
                    ),
                    AppMetric(
                      label: AppLocalizations.of(context)!.studiedTime,
                      value: formatStudyDuration(studiedSeconds),
                      foreground: colors.onPrimaryContainer,
                    ),
                    AppMetric(
                      label: AppLocalizations.of(context)!.remainingTime,
                      value: formatStudyDuration(remainingSeconds),
                      foreground: colors.onPrimaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!
                      .overviewCompletion(_percent(completion)),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completion.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: colors.primary,
                    backgroundColor: colors.onPrimaryContainer.withValues(
                      alpha: 0.1,
                    ),
                  ),
                ),
              ],
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
              const SizedBox(height: AppTheme.cardSpacing),
            ],
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
    final remaining = plan.hasStartedToday
        ? plan.remainingSeconds
        : plan.plannedSeconds;
    final completion = _completion(plan.studiedSeconds, plan.plannedSeconds);
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final detailStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.4,
      color: colors.onSurfaceVariant,
      fontFeatures: AppTheme.durationFeatures,
    );
    return Card(
      key: ValueKey('statistics_${plan.id}'),
      color: colors.surface,
      shape: AppTheme.cardShape(colors),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudyPlanLayout(
              plan: plan,
              iconKey: ValueKey('statistics_icon_${plan.id}'),
              contentBuilder: (context, stacked) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StudyPlanTitle(name: plan.name),
                  const SizedBox(height: 6),
                  Text(
                    l10n.planCompletion(_percent(completion)),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.statPlanned(formatStudyDuration(plan.plannedSeconds)),
                    style: detailStyle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.statStudied(formatStudyDuration(plan.studiedSeconds)),
                    style: detailStyle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.statRemaining(formatStudyDuration(remaining)),
                    style: detailStyle,
                  ),
                  if (plan.studiedSeconds > plan.plannedSeconds) ...[
                    const SizedBox(height: 3),
                    Text(
                      l10n.statOver(
                        formatStudyDuration(
                          plan.studiedSeconds - plan.plannedSeconds,
                        ),
                      ),
                      style: detailStyle,
                    ),
                  ],
                ],
              ),
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
