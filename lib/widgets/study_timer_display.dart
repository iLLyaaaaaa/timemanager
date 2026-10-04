import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/study_duration.dart';

class StudyTimerDisplay extends StatelessWidget {
  const StudyTimerDisplay({
    super.key,
    required this.remainingSeconds,
    required this.plannedSeconds,
    required this.completed,
  });

  final int remainingSeconds;
  final int plannedSeconds;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final heightLimit = MediaQuery.sizeOf(context).height * 0.4;
        final diameter = constraints.maxWidth.clamp(
          0.0,
          heightLimit < 280 ? heightLimit : 280.0,
        );
        return Center(
          child: SizedBox.square(
            dimension: diameter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (remainingSeconds / plannedSeconds).clamp(0.0, 1.0),
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    color: colors.primary,
                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.remainingTime,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatStudyDuration(remainingSeconds),
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                            fontFeatures: AppTheme.durationFeatures,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        completed
                            ? l10n.completedToday
                            : l10n.focusEncouragement,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
