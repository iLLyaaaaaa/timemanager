import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/settings_store.dart';
import '../data/study_plan_store.dart';
import '../l10n/app_localizations.dart';
import '../widgets/save_retry_banner.dart';
import '../widgets/study_scheme_picker.dart';

class WeeklySchedulePage extends StatefulWidget {
  const WeeklySchedulePage({
    super.key,
    required this.store,
    required this.settings,
  });
  final StudyPlanStore store;
  final SettingsStore settings;
  @override
  State<WeeklySchedulePage> createState() => _WeeklySchedulePageState();
}

class _WeeklySchedulePageState extends State<WeeklySchedulePage> {
  bool _busy = false;

  Future<void> _assign(List<int> days, String title) async {
    if (_busy || widget.store.isReplacing) return;
    final selected = await showStudySchemePicker(
      context,
      widget.store,
      title: title,
      currentId: widget.store.weeklyAssignments[days.first],
    );
    if (selected == null || !mounted || widget.store.isReplacing) return;
    setState(() => _busy = true);
    try {
      widget.store.setWeeklyAssignments({
        for (final day in days) day: selected.schemeId,
      });
      final saved = await widget.store.flush();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? AppLocalizations.of(context)!.scheduleSaved
                  : AppLocalizations.of(context)!.dataSaveFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.weeklySchedule)),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SaveRetryBanner(
              store: widget.store,
              settings: widget.settings,
              enabled: !_busy,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const ValueKey('assign_workdays'),
                  onPressed: _busy || widget.store.isReplacing
                      ? null
                      : () => _assign([1, 2, 3, 4, 5], l10n.workdays),
                  child: Text(l10n.workdays),
                ),
                OutlinedButton(
                  key: const ValueKey('assign_weekends'),
                  onPressed: _busy || widget.store.isReplacing
                      ? null
                      : () => _assign([6, 7], l10n.weekendDays),
                  child: Text(l10n.weekendDays),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (var day = 1; day <= 7; day++)
              Card(
                child: ListTile(
                  key: ValueKey('weekly_day_$day'),
                  title: Text(
                    DateFormat.EEEE(l10n.localeName)
                        .format(DateTime.utc(2026, 1, 4 + day)),
                  ),
                  subtitle: Text(
                    studySchemeName(
                      context,
                      widget.store.schemeById(
                        widget.store.weeklyAssignments[day],
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _busy || widget.store.isReplacing
                      ? null
                      : () => _assign(
                          [day],
                          DateFormat.EEEE(l10n.localeName)
                              .format(DateTime.utc(2026, 1, 4 + day)),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
