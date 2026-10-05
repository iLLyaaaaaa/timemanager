import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/study_duration.dart';
import '../utils/study_history.dart';
import '../utils/study_plan_breakdown.dart';
import 'app_section_card.dart';

String _percentage(BuildContext context, double fraction) {
  final format = NumberFormat.percentPattern(
    AppLocalizations.of(context)!.localeName,
  )..maximumFractionDigits = 1;
  return format.format(fraction);
}

class StudyPeriodComparisonCard extends StatelessWidget {
  const StudyPeriodComparisonCard({super.key, required this.comparison});
  final StudyPeriodComparison comparison;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final previous = comparison.previous;
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    final delta = comparison.secondsChange;
    final change = delta > 0
        ? l10n.reviewTimeIncreased(formatStudyDuration(delta))
        : delta < 0
        ? l10n.reviewTimeDecreased(formatStudyDuration(-delta))
        : l10n.reviewTimeUnchanged;
    final percent = comparison.relativeChange;
    return AppSectionCard(
      key: const ValueKey('review_comparison'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reviewPeriodComparison,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.reviewComparisonPeriod(
              previous.dayCount,
              dateFormat.format(previous.startDay),
              dateFormat.format(previous.endDay),
            ),
            key: const ValueKey('review_comparison_dates'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            change,
            key: const ValueKey('review_comparison_change'),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontFeatures: AppTheme.durationFeatures),
          ),
          const SizedBox(height: 8),
          Text(
            percent == null
                ? l10n.reviewNoPreviousStudy
                : l10n.reviewChangePercent(
                    '${percent > 0 ? '+' : ''}${_percentage(context, percent)}',
                  ),
            key: const ValueKey('review_comparison_percent'),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.reviewPreviousTotal(
              formatStudyDuration(previous.totalStudiedSeconds),
            ),
            key: const ValueKey('review_comparison_total'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class StudyPlanTimeTile extends StatelessWidget {
  const StudyPlanTimeTile({
    super.key,
    required this.entry,
    required this.totalSeconds,
  });

  final StudyPlanTime entry;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final share = totalSeconds <= 0 ? 0.0 : entry.seconds / totalSeconds;
    final percent = _percentage(context, share);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.name,
          semanticsLabel: entry.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              formatStudyDuration(entry.seconds),
              key: ValueKey('review_plan_time_${entry.id}'),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontFeatures: AppTheme.durationFeatures),
            ),
            Text(
              l10n.reviewTimeShare(percent),
              key: ValueKey('review_plan_share_${entry.id}'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: share.clamp(0, 1),
              minHeight: 6,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        ),
      ],
    );
  }
}

class StudyPlanBreakdownCard extends StatelessWidget {
  const StudyPlanBreakdownCard({
    super.key,
    required this.entries,
    required this.totalSeconds,
    required this.onViewAll,
  });

  final List<StudyPlanTime> entries;
  final int totalSeconds;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSectionCard(
      key: const ValueKey('review_plan_breakdown'),
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: const PageStorageKey('review_plan_breakdown_expansion'),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Text(
          l10n.reviewPlanBreakdown,
          key: const ValueKey('review_breakdown_title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.reviewBreakdownExplanation,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (entries.isEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.reviewNoRangeStudy),
              ] else ...[
                for (final entry in entries.take(3)) ...[
                  const Divider(height: 32),
                  StudyPlanTimeTile(entry: entry, totalSeconds: totalSeconds),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const ValueKey('review_view_all_plans'),
                    onPressed: onViewAll,
                    child: Text(
                      l10n.reviewAllPlanTimes(entries.length),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
