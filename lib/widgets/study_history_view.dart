import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../utils/study_duration.dart';
import '../utils/study_history.dart';
import '../theme/app_theme.dart';
import 'app_section_card.dart';

class StudyHistoryView extends StatelessWidget {
  const StudyHistoryView({super.key, required this.summary});

  final StudyHistorySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    final longestDay = summary.days.fold<int>(
      0,
      (longest, day) =>
          day.studiedSeconds > longest ? day.studiedSeconds : longest,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionCard(
          highlighted: true,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.historyTotal,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 8),
                Text(
                  key: const ValueKey('history_total'),
                  formatStudyDuration(summary.totalStudiedSeconds),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                    fontFeatures: AppTheme.durationFeatures,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.historyActiveDays(summary.activeDays),
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.historyDateRange(
                    dateFormat.format(summary.days.last.date),
                    dateFormat.format(summary.days.first.date),
                  ),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.dailyStudyDuration,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var index = 0; index < summary.days.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                _HistoryDayRow(
                  day: summary.days[index],
                  isToday: index == 0,
                  progress: longestDay == 0
                      ? 0
                      : summary.days[index].studiedSeconds / longestDay,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (summary.activeDays == 0) ...[
          Text(l10n.noRecentStudy),
          const SizedBox(height: 8),
        ],
        Text(
          '${l10n.historyExplanation}\n${l10n.historyBarExplanation}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _HistoryDayRow extends StatelessWidget {
  const _HistoryDayRow({
    required this.day,
    required this.isToday,
    required this.progress,
  });

  final StudyHistoryDay day;
  final bool isToday;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.MMMd(l10n.localeName).format(day.date),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isToday ? colors.primary : colors.onSurface,
                      ),
                    ),
                    Text(
                      isToday
                          ? l10n.statisticsToday
                          : DateFormat.EEEE(l10n.localeName).format(day.date),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.tight,
                child: Text(
                  formatStudyDuration(day.studiedSeconds),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTheme.durationFeatures,
                    color: day.studiedSeconds > 0
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              key: ValueKey(
                'history_bar_${day.date.toIso8601String().substring(0, 10)}',
              ),
              value: progress,
              minHeight: 6,
              color: isToday ? colors.primary : colors.secondary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
