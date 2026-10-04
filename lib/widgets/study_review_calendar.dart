import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/study_duration.dart';
import '../utils/study_history.dart';

Color studyHeatColor(ColorScheme colors, int level) => switch (level) {
  0 => colors.surfaceContainerHighest,
  1 => colors.primaryContainer,
  2 => colors.secondaryContainer,
  3 => colors.secondary,
  _ => colors.primary,
};

Color _heatForeground(ColorScheme colors, int level) => switch (level) {
  0 => colors.onSurfaceVariant,
  1 => colors.onPrimaryContainer,
  2 => colors.onSecondaryContainer,
  3 => colors.onSecondary,
  _ => colors.onPrimary,
};

class StudyReviewCalendar extends StatelessWidget {
  const StudyReviewCalendar({
    super.key,
    required this.month,
    required this.history,
    required this.onDaySelected,
  });

  final DateTime month;
  final StudyHistoryIndex history;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final leading = month.weekday - 1;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final cells = ((leading + days + 6) ~/ 7) * 7;
    return Column(
      children: [
        Row(
          children: [
            for (var weekday = 0; weekday < 7; weekday++)
              Expanded(
                child: Text(
                  DateFormat.E(l10n.localeName)
                      .format(offsetStudyDay(month, weekday - leading)),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          key: const ValueKey('review_month_grid'),
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: cells,
          itemBuilder: (context, cell) {
            final dayNumber = cell - leading + 1;
            if (dayNumber < 1 || dayNumber > days) {
              return const SizedBox.shrink();
            }
            final day = DateTime.utc(month.year, month.month, dayNumber);
            final future = day.isAfter(history.lastDay);
            final seconds = history.studiedSecondsOn(day);
            final level = studyHeatLevel(seconds);
            final description = future
                ? l10n.reviewFutureDay(
                    DateFormat.yMMMMd(l10n.localeName).format(day),
                  )
                : l10n.reviewDayDescription(
                    DateFormat.yMMMMd(l10n.localeName).format(day),
                    formatStudyDuration(seconds),
                  );
            return Tooltip(
              message: description,
              excludeFromSemantics: true,
              child: TextButton(
                key: ValueKey('calendar_day_${studyDayKey(day)}'),
                onPressed: future ? null : () => onDaySelected(day),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                  backgroundColor: studyHeatColor(colors, level),
                  foregroundColor: _heatForeground(colors, level),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: day == history.lastDay
                      ? BorderSide(color: colors.primary, width: 2)
                      : BorderSide.none,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$dayNumber', semanticsLabel: description),
                    if (seconds > 0)
                      ExcludeSemantics(
                        child: Icon(
                          Icons.circle,
                          size: 4,
                          color: _heatForeground(colors, level),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class StudyHeatLegend extends StatelessWidget {
  const StudyHeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final labels = [
      l10n.reviewHeatNone,
      l10n.reviewHeat15,
      l10n.reviewHeat30,
      l10n.reviewHeat60,
      l10n.reviewHeatOver60,
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (var level = 0; level < labels.length; level++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: studyHeatColor(colors, level),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Text(labels[level], style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}

class StudyReviewDayTile extends StatelessWidget {
  const StudyReviewDayTile({
    super.key,
    required this.day,
    required this.history,
    required this.onPressed,
  });

  final DateTime day;
  final StudyHistoryIndex history;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final future = day.isAfter(history.lastDay);
    final seconds = history.studiedSecondsOn(day);
    final date = DateFormat.yMMMEd(l10n.localeName).format(day);
    final description = future
        ? l10n.reviewFutureDay(date)
        : l10n.reviewDayDescription(date, formatStudyDuration(seconds));
    return TextButton(
      onPressed: future ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: studyHeatColor(colors, studyHeatLevel(seconds)),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(date, semanticsLabel: description)),
              if (!future) const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              future ? l10n.reviewFutureLabel : formatStudyDuration(seconds),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFeatures: AppTheme.durationFeatures,
                color: future ? colors.onSurfaceVariant : colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
