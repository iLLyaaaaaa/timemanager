import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/settings_store.dart';
import '../data/study_plan_store.dart';
import '../l10n/app_localizations.dart';
import '../models/study_record.dart';
import '../utils/study_duration.dart';
import '../utils/study_history.dart';
import '../widgets/app_section_card.dart';
import '../widgets/save_retry_banner.dart';
import '../widgets/study_scheme_picker.dart';
import 'weekly_schedule_page.dart';

class StudyCalendarPage extends StatefulWidget {
  const StudyCalendarPage({
    super.key,
    required this.store,
    required this.settings,
  });
  final StudyPlanStore store;
  final SettingsStore settings;
  @override
  State<StudyCalendarPage> createState() => _StudyCalendarPageState();
}

class _StudyCalendarPageState extends State<StudyCalendarPage> {
  late DateTime _day = widget.store.studyDate;
  late DateTime _month = DateTime.utc(_day.year, _day.month);
  final Set<DateTime> _selected = {};
  bool _selecting = false;
  bool _busy = false;
  bool _showSaveResult = false;
  List<DateTime> get _editableSelection =>
      _selected.where((d) => !d.isBefore(widget.store.studyDate)).toList();

  String _recordScheme(StudyRecord record) {
    return studyRecordSchemeName(context, widget.store, record);
  }

  String _dayLabel(DateTime day) {
    if (!day.isBefore(widget.store.studyDate)) {
      return studySchemeName(
        context,
        widget.store.schemeById(widget.store.schemeIdOn(day)),
      );
    }
    final records = widget.store
        .recordsOn(day)
        .where((r) => r.studiedSeconds > 0);
    return records.isEmpty
        ? AppLocalizations.of(context)!.noStudyRecords
        : records.map(_recordScheme).toSet().join(' · ');
  }

  void _chooseDay(DateTime day) {
    if (_busy) return;
    if (_selecting && day.isBefore(widget.store.studyDate)) return;
    setState(() {
      _day = day;
      if (_selecting) {
        if (!_selected.add(day)) _selected.remove(day);
      }
    });
    if (!_selecting &&
        (MediaQuery.sizeOf(context).width < 360 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2)) {
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _details(),
          ),
        ),
      );
    }
  }

  Future<void> _saveChange(VoidCallback change) async {
    if (_busy || widget.store.isReplacing) return;
    setState(() {
      _busy = true;
      _showSaveResult = false;
    });
    try {
      change();
      await widget.store.flush();
      if (mounted) setState(() => _showSaveResult = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(List<DateTime> dates) async {
    if (_busy || dates.isEmpty || widget.store.isReplacing) return;
    final result = await showStudySchemePicker(
      context,
      widget.store,
      title: AppLocalizations.of(context)!.assignScheme,
      currentId: dates.length == 1
          ? widget.store.schemeIdOn(dates.single)
          : null,
    );
    if (result == null || !mounted) return;
    final valid = dates
        .where((d) => !d.isBefore(widget.store.studyDate))
        .toList();
    if (valid.isNotEmpty) {
      await _saveChange(() => widget.store.assignDates(valid, result.schemeId));
    }
  }

  Future<void> _range() async {
    if (_busy || widget.store.isReplacing) return;
    final range = await showDateRangePicker(
      context: context,
      firstDate: widget.store.studyDate,
      currentDate: widget.store.studyDate,
      lastDate: DateTime(2100, 12, 31),
      helpText: AppLocalizations.of(context)!.selectDateRange,
    );
    if (range == null || !mounted || widget.store.isReplacing) return;
    setState(() {
      _selected.clear();
      for (
        var day = studyCalendarDate(range.start);
        !day.isAfter(studyCalendarDate(range.end));
        day = offsetStudyDay(day, 1)
      ) {
        _selected.add(day);
      }
      _selecting = true;
      _day = studyCalendarDate(range.start);
      _month = DateTime.utc(_day.year, _day.month);
    });
  }

  Future<void> _jumpMonth() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      currentDate: widget.store.studyDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (day == null || !mounted) return;
    setState(() {
      _day = studyCalendarDate(day);
      _month = DateTime.utc(day.year, day.month);
    });
  }

  Widget _calendar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final leading = _month.weekday - 1;
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    if (compact) {
      return Column(
        children: [
          for (var number = 1; number <= count; number++)
            _dateTile(DateTime.utc(_month.year, _month.month, number)),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            for (var weekday = 1; weekday <= 7; weekday++)
              Expanded(
                child: Text(
                  DateFormat.E(l10n.localeName)
                      .format(DateTime.utc(2026, 1, 4 + weekday)),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          key: const ValueKey('schedule_month_grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          primary: false,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
            mainAxisExtent: 72,
          ),
          itemCount: ((leading + count + 6) ~/ 7) * 7,
          itemBuilder: (context, index) {
            final number = index - leading + 1;
            if (number < 1 || number > count) return const SizedBox.shrink();
            final day = DateTime.utc(_month.year, _month.month, number);
            final label = _dayLabel(day);
            final selected = _selecting ? _selected.contains(day) : _day == day;
            final colors = Theme.of(context).colorScheme;
            return Tooltip(
              message:
                  '${DateFormat.yMMMMd(l10n.localeName).format(day)} · $label',
              child: OutlinedButton(
                key: ValueKey('schedule_day_${studyDayKey(day)}'),
                onPressed:
                    _busy ||
                        (_selecting && day.isBefore(widget.store.studyDate))
                    ? null
                    : () => _chooseDay(day),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(2),
                  minimumSize: const Size(44, 48),
                  backgroundColor: selected
                      ? colors.primaryContainer
                      : colors.surface,
                  foregroundColor: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurface,
                  side: BorderSide(
                    color: selected || day == widget.store.studyDate
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$number'),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (!day.isBefore(widget.store.studyDate))
                      Icon(
                        widget.store.dateOverrides.containsKey(studyDayKey(day))
                            ? Icons.push_pin
                            : Icons.circle,
                        size: 8,
                        color: studySchemeColor(
                          context,
                          widget.store.schemeIdOn(day),
                        ),
                      )
                    else if (widget.store
                        .recordsOn(day)
                        .any((r) => r.studiedSeconds > 0))
                      const Icon(Icons.check, size: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _dateTile(DateTime day) => ListTile(
    key: ValueKey('schedule_day_${studyDayKey(day)}'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    selected: _selecting ? _selected.contains(day) : day == _day,
    leading: _selecting
        ? Icon(
            _selected.contains(day)
                ? Icons.check_box
                : Icons.check_box_outline_blank,
          )
        : Text('${day.day}'),
    title: Text(
      DateFormat.MMMEd(AppLocalizations.of(context)!.localeName).format(day),
    ),
    subtitle: Text(_dayLabel(day)),
    onTap: _busy || (_selecting && day.isBefore(widget.store.studyDate))
        ? null
        : () => _chooseDay(day),
  );

  Widget _details() {
    final l10n = AppLocalizations.of(context)!;
    final past = _day.isBefore(widget.store.studyDate);
    final scheme = widget.store.schemeById(widget.store.schemeIdOn(_day));
    final records = widget.store
        .recordsOn(_day)
        .where((r) => r.studiedSeconds > 0)
        .toList();
    final tasks = widget.store.plansForScheme(scheme?.id);
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DateFormat.yMMMMEEEEd(l10n.localeName).format(_day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (past) ...[
            Text(l10n.pastDateReadOnly),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l10n.noStudyRecords),
              ),
          ] else ...[
            Text(
              studySchemeName(context, scheme),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              widget.store.dateOverrides.containsKey(studyDayKey(_day))
                  ? l10n.dateOverride
                  : l10n.weeklyDefault,
            ),
            const SizedBox(height: 12),
            if (scheme == null) Text(l10n.restDayHint),
            for (final task in tasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(task.name),
                trailing: Text(formatStudyDuration(task.plannedSeconds)),
              ),
          ],
          if (records.isNotEmpty) ...[
            const Divider(),
            Text(l10n.studiedTime),
            for (final record in records)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  record.planName ??
                      widget.store.planById(record.planId)?.name ??
                      l10n.reviewDeletedPlans(1),
                ),
                subtitle: Text(_recordScheme(record)),
                trailing: Text(formatStudyDuration(record.studiedSeconds)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _batchActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dates = _editableSelection;
    final disabled = _busy || widget.store.isReplacing;
    final saved = !widget.store.hasUnsavedChanges && !widget.store.hasLoadError;
    return Material(
      key: const ValueKey('schedule_batch_actions'),
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.selectedDateCount(dates.length)),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    key: const ValueKey('select_schedule_range'),
                    onPressed: disabled ? null : _range,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(l10n.selectDateRange),
                  ),
                  TextButton(
                    key: const ValueKey('clear_schedule_selection'),
                    onPressed: disabled || _selected.isEmpty
                        ? null
                        : () => setState(_selected.clear),
                    child: Text(l10n.clearSelection),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const ValueKey('assign_batch_dates'),
                    onPressed: disabled || dates.isEmpty
                        ? null
                        : () => _assign(dates),
                    child: Text(l10n.assignScheme),
                  ),
                  OutlinedButton(
                    key: const ValueKey('restore_batch_dates'),
                    onPressed: disabled || dates.isEmpty
                        ? null
                        : () => _saveChange(
                            () => widget.store.restoreWeeklyDates(
                              _editableSelection,
                            ),
                          ),
                    child: Text(l10n.restoreWeeklySchedule),
                  ),
                ],
              ),
              if (_showSaveResult)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      saved ? l10n.scheduleSaved : l10n.dataSaveFailed,
                      style: TextStyle(
                        color: saved
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.store, widget.settings]),
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('select_schedule_dates'),
                      onPressed: _busy || widget.store.isReplacing
                          ? null
                          : () => setState(() {
                              _selecting = !_selecting;
                              _selected.clear();
                              _showSaveResult = false;
                            }),
                      icon: Icon(
                        _selecting ? Icons.check : Icons.checklist_rounded,
                      ),
                      label: Text(_selecting ? l10n.done : l10n.bulkSchedule),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('weekly_schedule'),
                      onPressed: _busy || widget.store.isReplacing
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => WeeklySchedulePage(
                                  store: widget.store,
                                  settings: widget.settings,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.repeat),
                      label: Text(l10n.weeklySchedule),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const PageStorageKey('schedule_scroll'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                SaveRetryBanner(
                  store: widget.store,
                  settings: widget.settings,
                  enabled: !_busy,
                ),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('schedule_previous_month'),
                      tooltip: MaterialLocalizations.of(context)
                          .previousMonthTooltip,
                      onPressed: _month.year == 1970 && _month.month == 1
                          ? null
                          : () => setState(
                              () => _month = DateTime.utc(
                                _month.year,
                                _month.month - 1,
                              ),
                            ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: _jumpMonth,
                        child: Text(
                          DateFormat.yMMMM(l10n.localeName).format(_month),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('schedule_next_month'),
                      tooltip: MaterialLocalizations.of(context)
                          .nextMonthTooltip,
                      onPressed: _month.year == 2100 && _month.month == 12
                          ? null
                          : () => setState(
                              () => _month = DateTime.utc(
                                _month.year,
                                _month.month + 1,
                              ),
                            ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                if (_selecting)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l10n.selectDates),
                  ),
                _calendar(context),
                if (!_selecting) ...[const SizedBox(height: 20), _details()],
              ],
            ),
          ),
          if (_selecting) _batchActions(context),
        ],
      ),
    );
  }
}
