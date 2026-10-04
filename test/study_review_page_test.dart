import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_storage.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/l10n/app_localizations.dart';
import 'package:hello_app/models/study_plan.dart';
import 'package:hello_app/models/study_record.dart';
import 'package:hello_app/pages/study_review_page.dart';
import 'package:hello_app/pages/study_statistics_page.dart';

import 'support/localized_app.dart';

class _Storage implements StudyPlanStorage {
  String? value;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
    writes++;
  }
}

Future<StudyPlanStore> _fixture({
  SettingsStore? settings,
  DateTime Function()? now,
}) {
  const plans = [
    StudyPlan(
      id: 'one',
      name: '高等数学 Advanced Mathematics',
      iconId: 'calculate',
      plannedSeconds: 7200,
      progressDay: '2026-10-04',
      remainingSeconds: 3600,
      studiedSeconds: 3600,
      hasStartedToday: true,
    ),
    StudyPlan(
      id: 'two',
      name: 'Python',
      iconId: 'code',
      plannedSeconds: 1800,
      progressDay: '2026-10-04',
      remainingSeconds: 900,
      studiedSeconds: 900,
      hasStartedToday: true,
    ),
  ];
  StudyRecord record(
    String date,
    String planId,
    int seconds, [
    int planned = 60,
  ]) => StudyRecord(
    id: '${date}_$planId',
    planId: planId,
    date: date,
    plannedSeconds: planned,
    studiedSeconds: seconds,
  );
  final storage = _Storage()
    ..value = jsonEncode({
      'version': 5,
      'nextId': 1,
      'plans': plans.map((plan) => plan.toJson()).toList(),
      'records': [
        record('2026-10-04', 'one', 3600, 7200),
        record('2026-10-04', 'two', 900, 1800),
        record('2026-10-04', 'deleted1', 100),
        record('2026-10-04', 'deleted2', 50),
        record('2026-10-03', 'one', 3000),
        record('2026-10-03', 'two', 500),
        record('2026-10-02', 'one', 900),
        record('2026-09-30', 'deleted1', 100),
        record('2026-10-05', 'future', 10000),
        record('not-a-date', 'invalid', 10000),
      ].map((record) => record.toJson()).toList(),
    });
  return StudyPlanStore.load(
    storage: storage,
    settings: settings,
    now: now ?? () => DateTime(2026, 10, 4, 12),
  );
}

void _phone(WidgetTester tester, [double width = 390]) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

Future<void> _top(WidgetTester tester) async {
  _position(tester).jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> _rangeView(WidgetTester tester, [String label = '范围统计']) async {
  await _top(tester);
  await _tap(tester, find.text(label));
}

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data;

void main() {
  testWidgets(
    'statistics opens review and returns to the selected history view',
    (tester) async {
      final store = await _fixture();
      addTearDown(store.dispose);
      try {
        await tester.pumpWidget(
          localizedApp(
            home: Scaffold(body: StudyStatisticsPage(store: store)),
          ),
        );
        await tester.tap(find.text('近 7 天'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open_study_review')));
        await tester.pumpAndSettle();
        expect(find.byType(StudyReviewPage), findsOneWidget);
        expect(_text(tester, 'review_current_streak'), '3 天');
        expect(_text(tester, 'review_longest_streak'), '3 天');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(StudyReviewPage), findsNothing);
        expect(find.byKey(const ValueKey('history_total')), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('calendar navigation, accessible dates and sorted day details', (
    tester,
  ) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final store = await _fixture();
    addTearDown(store.dispose);
    try {
      await tester.pumpWidget(
        localizedApp(home: StudyReviewPage(store: store)),
      );
      await tester.pumpAndSettle();
      final day = find.byKey(const ValueKey('calendar_day_2026-10-04'));
      await tester.scrollUntilVisible(
        day,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(day);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review_month_grid')), findsOneWidget);
      expect(tester.getSize(day).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(day).height, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(day).label, contains('2026年10月4日'));
      expect(tester.getSemantics(day).label, contains('01:17:30'));
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('calendar_day_2026-10-05')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(day);
      await tester.pumpAndSettle();
      expect(_text(tester, 'review_day_total'), '当日累计学习：01:17:30');
      final titles = find.descendant(
        of: find.byKey(const ValueKey('review_day_entries')),
        matching: find.byType(Text),
      );
      final values = tester
          .widgetList<Text>(titles)
          .map((text) => text.data)
          .toList();
      expect(values, [
        '高等数学 Advanced Mathematics',
        '01:00:00',
        'Python',
        '15:00',
        '已删除计划（2 项）',
        '02:30',
      ]);
      store.updatePlan(store.plans.first.copyWith(name: '数学新名称'));
      await tester.pumpAndSettle();
      expect(find.text('数学新名称'), findsOneWidget);
      store.deletePlan('two');
      await tester.pumpAndSettle();
      expect(find.text('已删除计划（3 项）'), findsOneWidget);
      expect(_text(tester, 'review_day_total'), '当日累计学习：01:17:30');
      await tester.tap(find.byKey(const ValueKey('review_close_day')));
      await tester.pumpAndSettle();
      await _top(tester);
      await _tap(tester, find.byKey(const ValueKey('review_previous_month')));
      expect(_text(tester, 'review_month_title'), '2026年9月');
      await _tap(tester, find.byKey(const ValueKey('calendar_day_2026-09-01')));
      expect(find.text('这一天还没有学习时长记录。'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('review_close_day')));
      await tester.pumpAndSettle();
      await _top(tester);
      await _tap(tester, find.byKey(const ValueKey('review_current_month')));
      expect(_text(tester, 'review_month_title'), '2026年10月');
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('review_next_month')))
            .onPressed,
        isNull,
      );
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('range presets update totals and lazily include zero days', (
    tester,
  ) async {
    _phone(tester);
    final store = await _fixture();
    addTearDown(store.dispose);
    try {
      await tester.pumpWidget(
        localizedApp(home: StudyReviewPage(store: store)),
      );
      await tester.pumpAndSettle();
      await _rangeView(tester);
      expect(_text(tester, 'review_range_total'), '02:32:30');
      expect(find.byKey(const ValueKey('range_day_2026-09-05')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('review_range_thisMonth')));
      expect(_text(tester, 'review_range_total'), '02:30:50');
      expect(_text(tester, 'review_range_average'), '37:42');
      await _tap(tester, find.byKey(const ValueKey('range_day_2026-10-01')));
      expect(find.text('这一天还没有学习时长记录。'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('review_close_day')));
      await tester.pumpAndSettle();
      await _top(tester);
      await _tap(tester, find.byKey(const ValueKey('review_range_last7')));
      expect(_text(tester, 'review_range_average'), '21:47');
      store.studySeconds('one', 30);
      await tester.pumpAndSettle();
      expect(_text(tester, 'review_range_total'), '02:33:00');
      store.clearLearningData();
      await tester.pumpAndSettle();
      expect(_text(tester, 'review_range_total'), '00:00');
      expect(_text(tester, 'review_range_best'), '—');
      expect(_text(tester, 'review_current_streak'), '0 天');
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'custom range cancellation and confirmation preserve read-only data',
    (tester) async {
      _phone(tester);
      final store = await _fixture();
      addTearDown(store.dispose);
      final storage = store.storage! as _Storage;
      try {
        await tester.pumpWidget(
          localizedApp(
            home: StudyReviewPage(store: store),
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();
        await _rangeView(tester, 'Date range');
        final beforeDates = _text(tester, 'review_range_dates');
        final beforeData = storage.value;
        final writes = storage.writes;
        await _tap(tester, find.byKey(const ValueKey('review_range_custom')));
        expect(find.byType(DateRangePickerDialog), findsOneWidget);
        final picker = tester.widget<DateRangePickerDialog>(
          find.byType(DateRangePickerDialog),
        );
        expect(picker.lastDate, DateTime(2026, 10, 4));
        expect(picker.firstDate, DateTime(2026, 9, 5));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_text(tester, 'review_range_dates'), beforeDates);
        await _tap(tester, find.byKey(const ValueKey('review_range_custom')));
        final pickerContext = tester.element(
          find.byType(DateRangePickerDialog),
        );
        final material = MaterialLocalizations.of(pickerContext);
        await tester.tap(find.byTooltip(material.inputDateModeButtonLabel));
        await tester.pumpAndSettle();
        final inputs = find.descendant(
          of: find.byType(DateRangePickerDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(inputs.at(0), '10/2/2026');
        await tester.enterText(inputs.at(1), '10/3/2026');
        await tester.tap(find.text(material.okButtonLabel));
        await tester.pumpAndSettle();
        expect(find.byType(DateRangePickerDialog), findsNothing);
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const ValueKey('review_range_custom')),
              )
              .selected,
          isTrue,
        );
        expect(_text(tester, 'review_range_total'), '01:13:20');
        expect(_text(tester, 'review_range_average'), '36:40');
        expect(_text(tester, 'review_range_dates'), contains('Oct 2, 2026'));
        expect(_text(tester, 'review_range_dates'), contains('Oct 3, 2026'));
        expect(storage.value, beforeData);
        expect(storage.writes, writes);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('calendar and range retain their own month, preset and scroll', (
    tester,
  ) async {
    _phone(tester);
    final store = await _fixture();
    addTearDown(store.dispose);
    try {
      await tester.pumpWidget(
        localizedApp(home: StudyReviewPage(store: store)),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('review_previous_month')));
      _position(tester).jumpTo(100);
      await tester.pumpAndSettle();
      final calendarOffset = _position(tester).pixels;
      await tester.tap(find.text('范围统计'));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('review_range_last7')));
      _position(tester).jumpTo(100);
      await tester.pumpAndSettle();
      final rangeOffset = _position(tester).pixels;
      await tester.tap(find.text('月历'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'review_month_title'), '2026年9月');
      expect(_position(tester).pixels, closeTo(calendarOffset, 1));
      await tester.tap(find.text('范围统计'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('review_range_last7')),
            )
            .selected,
        isTrue,
      );
      expect(_position(tester).pixels, closeTo(rangeOffset, 1));
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'study-date reset refreshes the open page without writing history',
    (tester) async {
      _phone(tester);
      var now = DateTime(2026, 10, 4, 3, 59, 59);
      final settings = SettingsStore();
      settings.update(settings.settings.copyWith(dailyResetHour: 4));
      final store = await _fixture(settings: settings, now: () => now);
      addTearDown(settings.dispose);
      addTearDown(store.dispose);
      try {
        await tester.pumpWidget(
          localizedApp(home: StudyReviewPage(store: store)),
        );
        await tester.pumpAndSettle();
        final storage = store.storage! as _Storage;
        final writes = storage.writes;
        expect(_text(tester, 'review_current_streak'), '2 天');
        now = DateTime(2026, 10, 4, 4);
        await tester.pump(const Duration(seconds: 2));
        expect(_text(tester, 'review_current_streak'), '3 天');
        expect(storage.writes, writes);
        settings.update(settings.settings.copyWith(dailyResetHour: 5));
        await tester.pumpAndSettle();
        expect(_text(tester, 'review_current_streak'), '2 天');
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('load failures stay errors and disable the statistics entry', (
    tester,
  ) async {
    final storage = _Storage()..value = '{"version":99,"plans":[]}';
    final store = await StudyPlanStore.load(storage: storage);
    addTearDown(store.dispose);
    try {
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(body: StudyStatisticsPage(store: store)),
        ),
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('open_study_review')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(
        localizedApp(home: StudyReviewPage(store: store)),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(StudyReviewPage)),
      )!;
      expect(find.text(l10n.planLoadFailed), findsOneWidget);
      expect(find.byKey(const ValueKey('review_current_streak')), findsNothing);
      expect(storage.writes, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}
