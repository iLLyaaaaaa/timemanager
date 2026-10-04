import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/study_plan_store.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/study_duration.dart';
import '../utils/study_history.dart';
import '../widgets/app_section_card.dart';
import '../widgets/study_review_calendar.dart';

enum _ReviewView { calendar, range }

enum _ReviewRange { last30, last7, thisMonth, custom }

class StudyReviewPage extends StatefulWidget {
  const StudyReviewPage({super.key, required this.store});
  final StudyPlanStore store;

  @override
  State<StudyReviewPage> createState() => _StudyReviewPageState();
}

class _StudyReviewPageState extends State<StudyReviewPage>
    with WidgetsBindingObserver {
  _ReviewView _view = _ReviewView.calendar;
  _ReviewRange _range = _ReviewRange.last30;
  DateTime? _month;
  DateTimeRange? _customRange;
  final _calendarScroll = ScrollController();
  final _rangeScroll = ScrollController();
  final _pageStorage = PageStorageBucket();
  Timer? _dateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen(widget.store);
    _scheduleDateRefresh();
  }

  void _listen(StudyPlanStore store) {
    store.addListener(_refresh);
    store.settings?.addListener(_refresh);
  }

  void _unlisten(StudyPlanStore store) {
    store.removeListener(_refresh);
    store.settings?.removeListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant StudyReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      _unlisten(oldWidget.store);
      _listen(widget.store);
      _scheduleDateRefresh();
    }
  }

  void _refresh() {
    if (!mounted) return;
    _scheduleDateRefresh();
    setState(() {});
  }

  // Refresh the date projection at the user's next reset boundary, including
  // when the page remains open without any running session. No stored data is changed.
  void _scheduleDateRefresh() {
    _dateTimer?.cancel();
    final now = widget.store.currentTime;
    final settings = widget.store.settings?.settings;
    final hour = settings?.dailyResetHour ?? 0;
    final minute = settings?.dailyResetMinute ?? 0;
    DateTime reset(int dayOffset) => now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + dayOffset, hour, minute)
        : DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
    var next = reset(0);
    if (!next.isAfter(now)) next = reset(1);
    _dateTimer = Timer(
      next.difference(now) + const Duration(milliseconds: 1),
      _refresh,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _unlisten(widget.store);
    _calendarScroll.dispose();
    _rangeScroll.dispose();
    super.dispose();
  }

  StudyHistoryIndex _history() => StudyHistoryIndex(
    records: widget.store.records,
    lastDay:
        widget.store.settings?.studyDate(widget.store.currentTime) ??
        widget.store.currentTime,
  );

  DateTime _shownMonth(StudyHistoryIndex history) {
    final current = DateTime.utc(history.lastDay.year, history.lastDay.month);
    return _month == null || _month!.isAfter(current) ? current : _month!;
  }

  DateTimeRange _selectedRange(StudyHistoryIndex history) {
    final today = history.lastDay;
    return switch (_range) {
      _ReviewRange.last7 => DateTimeRange(
        start: offsetStudyDay(today, -6),
        end: today,
      ),
      _ReviewRange.last30 => DateTimeRange(
        start: offsetStudyDay(today, -29),
        end: today,
      ),
      _ReviewRange.thisMonth => DateTimeRange(
        start: DateTime.utc(today.year, today.month),
        end: today,
      ),
      _ReviewRange.custom => DateTimeRange(
        start: _customRange!.start.isAfter(today) ? today : _customRange!.start,
        end: _customRange!.end.isAfter(today) ? today : _customRange!.end,
      ),
    };
  }

  Future<void> _chooseRange(StudyHistoryIndex history) async {
    final initial = _selectedRange(history);
    var first = offsetStudyDay(history.lastDay, -29);
    for (final candidate in [
      history.earliestDay,
      DateTime.utc(history.lastDay.year, history.lastDay.month),
      initial.start,
    ]) {
      if (candidate != null && candidate.isBefore(first)) first = candidate;
    }
    DateTime localDate(DateTime day) => DateTime(day.year, day.month, day.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: localDate(first),
      lastDate: localDate(history.lastDay),
      currentDate: localDate(history.lastDay),
      initialDateRange: DateTimeRange(
        start: localDate(initial.start),
        end: localDate(initial.end),
      ),
      builder: (context, child) => KeyedSubtree(
        key: const ValueKey('review_date_picker'),
        child: child!,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _customRange = DateTimeRange(
        start: studyCalendarDate(picked.start),
        end: studyCalendarDate(picked.end),
      );
      _range = _ReviewRange.custom;
    });
    if (_rangeScroll.hasClients) _rangeScroll.jumpTo(0);
  }

  void _openDay(DateTime day) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: _StudyReviewDaySheet(store: widget.store, day: day),
      ),
    );
  }

  Widget _growth(StudyHistoryIndex history) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return AppSectionCard(
      key: const ValueKey('review_growth'),
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppMetricGrid(
            children: [
              AppMetric(
                label: l10n.reviewCurrentStreak,
                value: l10n.reviewStudyDays(history.currentStreakDays),
                valueKey: const ValueKey('review_current_streak'),
                foreground: colors.onPrimaryContainer,
              ),
              AppMetric(
                label: l10n.reviewLongestStreak,
                value: l10n.reviewStudyDays(history.longestStreakDays),
                valueKey: const ValueKey('review_longest_streak'),
                foreground: colors.onPrimaryContainer,
              ),
            ],
          ),
          if (!history.hasStudiedToday) ...[
            const SizedBox(height: 12),
            Text(
              l10n.reviewNotStudiedToday,
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
          ],
          if (!history.hasStudyHistory) ...[
            const SizedBox(height: 8),
            Text(
              l10n.reviewNoHistory,
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.reviewStreakExplanation,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onPrimaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _calendarHeader(StudyHistoryIndex history, DateTime month) {
    final l10n = AppLocalizations.of(context)!;
    final currentMonth = DateTime.utc(
      history.lastDay.year,
      history.lastDay.month,
    );
    final monthEnd = DateTime.utc(month.year, month.month + 1, 0);
    final summary = history.summarize(
      startDay: month,
      endDay: monthEnd.isAfter(history.lastDay) ? history.lastDay : monthEnd,
    );
    void changeMonth(int offset) {
      setState(() => _month = DateTime.utc(month.year, month.month + offset));
      if (_calendarScroll.hasClients) _calendarScroll.jumpTo(0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMM(l10n.localeName).format(month),
                key: const ValueKey('review_month_title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              key: const ValueKey('review_previous_month'),
              tooltip: l10n.reviewPreviousMonth,
              onPressed: month.year == 1 && month.month == 1
                  ? null
                  : () => changeMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              key: const ValueKey('review_next_month'),
              tooltip: l10n.reviewNextMonth,
              onPressed: month == currentMonth ? null : () => changeMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('review_current_month'),
            onPressed: () {
              setState(() => _month = null);
              if (_calendarScroll.hasClients) _calendarScroll.jumpTo(0);
            },
            child: Text(l10n.reviewBackToMonth),
          ),
        ),
        AppSectionCard(
          child: AppMetricGrid(
            children: [
              AppMetric(
                label: l10n.reviewMonthTotal,
                value: formatStudyDuration(summary.totalStudiedSeconds),
                valueKey: const ValueKey('review_month_total'),
              ),
              AppMetric(
                label: l10n.reviewActiveDays,
                value: l10n.reviewStudyDays(summary.activeDays),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const StudyHeatLegend(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _rangeHeader(StudyHistoryIndex history) {
    final l10n = AppLocalizations.of(context)!;
    final selected = _selectedRange(history);
    final summary = history.summarize(
      startDay: selected.start,
      endDay: selected.end,
    );
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in _ReviewRange.values)
              ChoiceChip(
                key: ValueKey('review_range_${option.name}'),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                showCheckmark: false,
                selected: _range == option,
                label: Text(switch (option) {
                  _ReviewRange.last7 => l10n.recentWeek,
                  _ReviewRange.last30 => l10n.reviewLast30Days,
                  _ReviewRange.thisMonth => l10n.reviewThisMonth,
                  _ReviewRange.custom => l10n.reviewCustomRange,
                }),
                onSelected: (_) {
                  if (option == _ReviewRange.custom) {
                    _chooseRange(history);
                  } else {
                    setState(() => _range = option);
                    if (_rangeScroll.hasClients) _rangeScroll.jumpTo(0);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.historyDateRange(
                  dateFormat.format(selected.start),
                  dateFormat.format(selected.end),
                ),
                key: const ValueKey('review_range_dates'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              AppMetricGrid(
                children: [
                  AppMetric(
                    label: l10n.reviewTotal,
                    value: formatStudyDuration(summary.totalStudiedSeconds),
                    valueKey: const ValueKey('review_range_total'),
                  ),
                  AppMetric(
                    label: l10n.reviewActiveDays,
                    value: l10n.reviewStudyDays(summary.activeDays),
                  ),
                  AppMetric(
                    label: l10n.historyDailyAverage,
                    value: formatStudyDuration(summary.averageDailySeconds),
                    valueKey: const ValueKey('review_range_average'),
                  ),
                  AppMetric(
                    label: l10n.historyBestDay,
                    value: summary.longestStudyDay == null
                        ? '—'
                        : formatStudyDuration(
                            summary.longestStudyDay!.studiedSeconds,
                          ),
                    valueKey: const ValueKey('review_range_best'),
                  ),
                ],
              ),
              if (summary.longestStudyDay != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.historyBestDayDate(
                    dateFormat.format(summary.longestStudyDay!.date),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.reviewAverageExplanation(summary.dayCount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.dailyStudyDuration,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final history = _history();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.studyReview)),
      body: widget.store.hasLoadError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                child: Text(l10n.planLoadFailed, textAlign: TextAlign.center),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final grid =
                    constraints.maxWidth - AppTheme.pagePadding * 2 >=
                        7 * 48 + 6 * 2 &&
                    MediaQuery.textScalerOf(context).scale(14) / 14 <= 1.2;
                final month = _shownMonth(history);
                final range = _selectedRange(history);
                final summary = history.summarize(
                  startDay: range.start,
                  endDay: range.end,
                );
                return PageStorage(
                  bucket: _pageStorage,
                  child: CustomScrollView(
                    key: PageStorageKey('review_${_view.name}_scroll'),
                    controller: _view == _ReviewView.calendar
                        ? _calendarScroll
                        : _rangeScroll,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.pagePadding,
                          12,
                          AppTheme.pagePadding,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _growth(history),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<_ReviewView>(
                                  key: const ValueKey('review_view_selector'),
                                  showSelectedIcon: false,
                                  segments: [
                                    ButtonSegment(
                                      value: _ReviewView.calendar,
                                      label: Text(l10n.reviewCalendar),
                                    ),
                                    ButtonSegment(
                                      value: _ReviewView.range,
                                      label: Text(l10n.reviewRange),
                                    ),
                                  ],
                                  selected: {_view},
                                  onSelectionChanged: (selected) =>
                                      setState(() => _view = selected.single),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _view == _ReviewView.calendar
                                  ? _calendarHeader(history, month)
                                  : _rangeHeader(history),
                            ],
                          ),
                        ),
                      ),
                      if (_view == _ReviewView.calendar && grid)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.pagePadding,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: AppSectionCard(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: StudyReviewCalendar(
                                month: month,
                                history: history,
                                onDaySelected: _openDay,
                              ),
                            ),
                          ),
                        ),
                      if (_view == _ReviewView.range || !grid)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.pagePadding,
                          ),
                          sliver: SliverList.builder(
                            itemCount: _view == _ReviewView.range
                                ? summary.dayCount
                                : DateTime.utc(
                                    month.year,
                                    month.month + 1,
                                    0,
                                  ).day,
                            itemBuilder: (context, index) {
                              final day = _view == _ReviewView.range
                                  ? summary.dayAt(index)
                                  : DateTime.utc(
                                      month.year,
                                      month.month,
                                      index + 1,
                                    );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppSectionCard(
                                  padding: EdgeInsets.zero,
                                  child: StudyReviewDayTile(
                                    key: ValueKey(
                                      '${_view == _ReviewView.range ? 'range' : 'calendar'}_day_${studyDayKey(day)}',
                                    ),
                                    day: day,
                                    history: history,
                                    onPressed: () => _openDay(day),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.pagePadding,
                          16,
                          AppTheme.pagePadding,
                          24,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            l10n.historyExplanation,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _DayPlanTime {
  const _DayPlanTime(this.id, this.name, this.seconds);
  final String id;
  final String name;
  final int seconds;
}

class _StudyReviewDaySheet extends StatelessWidget {
  const _StudyReviewDaySheet({required this.store, required this.day});
  final StudyPlanStore store;
  final DateTime day;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      store,
      if (store.settings != null) store.settings!,
    ]),
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      final history = StudyHistoryIndex(
        records: store.records,
        lastDay:
            store.settings?.studyDate(store.currentTime) ?? store.currentTime,
      );
      final names = {for (final plan in store.plans) plan.id: plan.name};
      final entries = <_DayPlanTime>[];
      var deletedSeconds = 0;
      var deletedCount = 0;
      for (final entry in history.planSecondsOn(day).entries) {
        if (entry.value <= 0) continue;
        final name = names[entry.key];
        if (name == null) {
          deletedSeconds += entry.value;
          deletedCount++;
        } else {
          entries.add(_DayPlanTime(entry.key, name, entry.value));
        }
      }
      if (deletedCount > 0) {
        entries.add(
          _DayPlanTime(
            '',
            l10n.reviewDeletedPlans(deletedCount),
            deletedSeconds,
          ),
        );
      }
      entries.sort((a, b) {
        final time = b.seconds.compareTo(a.seconds);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          0,
          AppTheme.pagePadding,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMMd(l10n.localeName).format(day),
                    key: const ValueKey('review_day_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('review_close_day'),
                  tooltip: l10n.reviewClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reviewDayTotal(
                formatStudyDuration(history.studiedSecondsOn(day)),
              ),
              key: const ValueKey('review_day_total'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('review_day_entries'),
                itemCount: entries.isEmpty ? 1 : entries.length,
                itemBuilder: (context, index) => entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(l10n.reviewNoDayRecords),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entries[index].name,
                                semanticsLabel: entries[index].name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatStudyDuration(entries[index].seconds),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontFeatures: AppTheme.durationFeatures,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reviewRecordNamesHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    },
  );
}
