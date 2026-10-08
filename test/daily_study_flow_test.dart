import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';
import 'package:hello_app/widgets/study_duration_input.dart';
import 'package:hello_app/widgets/study_plan_card.dart';
import 'package:hello_app/widgets/study_time_adjustment_dialog.dart';

import 'support/daily_study_fixtures.dart';
import 'support/localized_app.dart';

DailyHarness _h({int seconds = 600}) {
  final h = DailyHarness(seconds: seconds);
  addTearDown(h.dispose);
  return h;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(mockDailyAudio);

  testWidgets('automatic entry starts once and preserves an active session', (
    tester,
  ) async {
    final h = _h();
    await openDailyTimer(tester, h);
    final session = h.plan.sessionId;
    expect(h.plan.isRunning, isTrue);
    h.advance(3);
    await tester.pump(const Duration(seconds: 3));
    expect(h.plan.studiedSeconds, 3);
    h.settings.update(h.settings.settings.copyWith(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();
    expect(h.plan.sessionId, session);
    expect(h.alerts.scheduled, [session]);
    await tester.pumpWidget(const SizedBox());
    await openDailyTimer(tester, h);
    expect(h.plan.sessionId, session);
    expect(h.plan.remainingSeconds, 597);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'paused entry resumes while completed and expired entry only display',
    (tester) async {
      final h = _h(seconds: 20);
      h.store.startOrResume(h.id);
      h.store.studySeconds(h.id, 5);
      await openDailyTimer(tester, h);
      expect(h.plan.isRunning, isTrue);
      expect(h.plan.studiedSeconds, 5);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(h.plan.isRunning, isFalse);
      h.store.beginRunning(h.id);
      h.advance(15);
      await openDailyTimer(tester, h);
      expect(h.plan.isCompletedToday, isTrue);
      expect(h.plan.isRunning, isFalse);
      expect(h.alerts.completions, 0);
      expect(find.text('返回首页'), findsOneWidget);
      await tapDaily(tester, 'timer_main_action');
      expect(find.byType(StudyTimerPage), findsNothing);
      await openDailyTimer(tester, h);
      expect(h.plan.isRunning, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'automatic entry reports an unrepresentable duration without starting',
    (tester) async {
      final h = _h(seconds: 0x7fffffffffffffff);
      await openDailyTimer(tester, h);
      expect(h.plan.isRunning, isFalse);
      expect(h.plan.hasStartedToday, isFalse);
      expect(find.textContaining('无法开始计时'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('home card starts immediately and rapid entry opens one page', (
    tester,
  ) async {
    final h = _h();
    await tester.pumpWidget(
      localizedApp(
        home: StudyHomePage(store: h.store, settings: h.settings),
      ),
    );
    final button = find.byKey(ValueKey('start_plan_${h.id}'));
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final open = tester.widget<FilledButton>(button).onPressed!;
    await tester.tap(button);
    open();
    await tester.pumpAndSettle();
    expect(find.byType(StudyTimerPage), findsOneWidget);
    expect(h.plan.isRunning, isTrue);
    h.advance(2);
    await tester.pump(const Duration(seconds: 2));
    expect(h.plan.studiedSeconds, 2);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(StudyTimerPage), findsNothing);
    expect(h.plan.isRunning, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  for (final confirm in [false, true]) {
    testWidgets(
      'adjustment ${confirm ? 'confirmation' : 'cancellation'} excludes editing time and resumes',
      (tester) async {
        final h = _h();
        await openDailyTimer(tester, h);
        h.advance(10);
        await tester.pump(const Duration(seconds: 10));
        final oldSession = h.plan.sessionId;
        await tapDaily(tester, 'timer_adjust_time');
        expect(h.plan.isRunning, isFalse);
        expect(h.alerts.cancelled, contains(oldSession));
        await tapDaily(tester, 'add_time_5');
        expect(h.plan.remainingSeconds, 590);
        h.advance(300);
        await tester.pump(const Duration(seconds: 300));
        expect(h.plan.studiedSeconds, 10);
        await tapDaily(
          tester,
          confirm ? 'confirm_adjust_time' : 'cancel_adjust_time',
        );
        expect(h.plan.isRunning, isTrue);
        expect(h.plan.remainingSeconds, confirm ? 890 : 590);
        expect(h.plan.studiedSeconds, 10);
        expect(h.plan.sessionId, isNot(oldSession));
        h.advance(1);
        await tester.pump(const Duration(seconds: 1));
        expect(h.plan.studiedSeconds, 11);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('adjustment of a paused plan stays paused', (tester) async {
    final h = _h();
    h.store.startOrResume(h.id);
    h.store.studySeconds(h.id, 7);
    await openDailyTimer(tester, h, autoStart: false);
    await tapDaily(tester, 'timer_adjust_time');
    await tapDaily(tester, 'add_time_15');
    await tapDaily(tester, 'confirm_adjust_time');
    expect(h.plan.isRunning, isFalse);
    expect(h.plan.remainingSeconds, 1493);
    expect(h.plan.studiedSeconds, 7);
    expect(h.alerts.scheduled, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  for (final systemBack in [true, false]) {
    testWidgets(
      'dialog ${systemBack ? 'system back' : 'outside tap'} cancels changes and resumes',
      (tester) async {
        final h = _h();
        await openDailyTimer(tester, h);
        await tapDaily(tester, 'timer_adjust_time');
        await tapDaily(tester, 'add_time_1');
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(const Offset(2, 2));
        }
        await tester.pumpAndSettle();
        expect(find.byType(StudyTimeAdjustmentDialog), findsNothing);
        expect(h.plan.remainingSeconds, 600);
        expect(h.plan.isRunning, isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('closed adjustment resumes only after returning to foreground', (
    tester,
  ) async {
    final h = _h();
    await openDailyTimer(tester, h);
    await tapDaily(tester, 'timer_adjust_time');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tapDaily(tester, 'cancel_adjust_time');
    expect(h.plan.isRunning, isFalse);
    h.advance(30);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.plan.isRunning, isTrue);
    expect(h.plan.studiedSeconds, 0);
    expect(h.plan.remainingSeconds, 600);
    await tester.pumpWidget(const SizedBox());
  });

  for (final change in ['day', 'delete', 'close', 'complete']) {
    testWidgets('adjustment never restores an obsolete session after $change', (
      tester,
    ) async {
      final h = _h();
      await openDailyTimer(tester, h);
      await tapDaily(tester, 'timer_adjust_time');
      switch (change) {
        case 'day':
          h.advance(86400);
          h.store.refreshForToday();
        case 'delete':
          h.store.deletePlan(h.id);
        case 'close':
          await tester.pumpWidget(const SizedBox());
        case 'complete':
          h.store.studySeconds(h.id, 600);
      }
      if (change != 'close') {
        await tapDaily(tester, 'cancel_adjust_time');
      }
      expect(h.store.planById(h.id)?.isRunning ?? false, isFalse);
      if (change == 'day') expect(h.plan.hasStartedToday, isFalse);
      expect(h.alerts.scheduled.length, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'cross-day confirmation keeps form open and does not alter new progress',
    (tester) async {
      final h = _h();
      await openDailyTimer(tester, h);
      await tapDaily(tester, 'timer_adjust_time');
      await tapDaily(tester, 'add_time_5');
      h.advance(86400);
      await tapDaily(tester, 'confirm_adjust_time');
      expect(find.byType(StudyTimeAdjustmentDialog), findsOneWidget);
      expect(h.plan.hasStartedToday, isFalse);
      expect(h.plan.isRunning, isFalse);
      expect(find.textContaining('学习日期'), findsOneWidget);
      await tapDaily(tester, 'cancel_adjust_time');
      expect(h.plan.isRunning, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'configured daily reset during adjustment leaves the new day ready',
    (tester) async {
      final h = _h();
      h.settings.update(
        h.settings.settings.copyWith(dailyResetHour: 4, dailyResetMinute: 30),
      );
      h.now = DateTime(2026, 10, 8, 4, 29);
      await openDailyTimer(tester, h);
      expect(h.plan.progressDay, '2026-10-07');
      h.advance(10);
      await tester.pump(const Duration(seconds: 10));
      await tapDaily(tester, 'timer_adjust_time');
      h.advance(50);
      await tapDaily(tester, 'cancel_adjust_time');
      expect(h.plan.isRunning, isFalse);
      expect(h.plan.hasStartedToday, isFalse);
      expect(h.store.records.single.date, '2026-10-07');
      expect(h.store.records.single.studiedSeconds, 10);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pending exit disables controls and repeated top and system back',
    (tester) async {
      final h = _h();
      await openDailyTimer(tester, h);
      final gate = Completer<void>();
      h.planStorage.gate = gate;
      await tester.tap(find.byKey(const ValueKey('timer_back')));
      await tester.pump();
      expect(h.plan.isRunning, isFalse);
      final writes = h.planStorage.writes;
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('timer_back')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('timer_main_action')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('timer_adjust_time')),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(h.planStorage.writes, writes);
      expect(find.byType(StudyTimerPage), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(StudyTimerPage), findsNothing);
      h.planStorage.gate = null;
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'submission blocks repeated edits, clicks and dismissals until saved',
    (tester) async {
      final h = _h();
      await openDailyTimer(tester, h);
      await tapDaily(tester, 'timer_adjust_time');
      final gate = Completer<void>();
      h.planStorage.gate = gate;
      await tester.tap(find.byKey(const ValueKey('confirm_adjust_time')));
      await tester.pump();
      final writes = h.planStorage.writes;
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('confirm_adjust_time')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('cancel_adjust_time')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('duration_minutes')))
            .enabled,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('confirm_adjust_time')));
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(StudyTimeAdjustmentDialog), findsOneWidget);
      expect(h.planStorage.writes, writes);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(StudyTimeAdjustmentDialog), findsNothing);
      expect(h.plan.isRunning, isTrue);
      h.planStorage.gate = null;
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed adjustment retains new duration and resumes with retry banner',
    (tester) async {
      final h = _h();
      await openDailyTimer(tester, h);
      await tapDaily(tester, 'timer_adjust_time');
      h.planStorage.failWrites = true;
      await tapDaily(tester, 'add_time_5');
      await tapDaily(tester, 'confirm_adjust_time');
      expect(h.plan.remainingSeconds, 900);
      expect(h.plan.isRunning, isTrue);
      expect(h.store.hasSaveError, isTrue);
      expect(find.byKey(const ValueKey('retry_save')), findsOneWidget);
      await tapDaily(tester, 'timer_main_action');
      h.planStorage.failWrites = false;
      await tapDaily(tester, 'retry_save');
      expect(h.store.hasUnsavedChanges, isFalse);
      expect(find.byKey(const ValueKey('retry_save')), findsNothing);
      expect(h.plan.remainingSeconds, 900);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed exit can stay paused or return home retaining data and retry',
    (tester) async {
      final h = _h();
      h.store.startOrResume(h.id);
      await tester.pumpWidget(
        localizedApp(
          home: StudyHomePage(store: h.store, settings: h.settings),
        ),
      );
      await tapDaily(tester, 'home_resume_plan');
      h.advance(8);
      await tester.pump(const Duration(seconds: 8));
      h.planStorage.failWrites = true;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timer_unsaved_exit')), findsOneWidget);
      await tapDaily(tester, 'stay_on_timer');
      expect(find.byType(StudyTimerPage), findsOneWidget);
      expect(h.plan.isRunning, isFalse);
      expect(h.plan.studiedSeconds, 8);
      h.advance(20);
      await tester.pump(const Duration(seconds: 20));
      expect(h.plan.studiedSeconds, 8);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapDaily(tester, 'leave_unsaved_timer');
      expect(find.byType(StudyTimerPage), findsNothing);
      expect(h.plan.remainingSeconds, 592);
      expect(h.store.hasSaveError, isTrue);
      final retry = find.byKey(const ValueKey('retry_save'));
      await tester.ensureVisible(retry);
      h.planStorage.failWrites = false;
      await tapDaily(tester, 'retry_save');
      expect(h.store.hasUnsavedChanges, isFalse);
      expect(h.plan.studiedSeconds, 8);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'programmatic duration uses the same validation and reports changes',
    (tester) async {
      final key = GlobalKey<StudyDurationInputState>();
      final changes = <int?>[];
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: Form(
              child: StudyDurationInput(
                key: key,
                initialSeconds: 90,
                label: 'Duration',
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('duration_minutes')),
        '60',
      );
      await tester.pump();
      expect(key.currentState!.totalSeconds, isNull);
      expect(changes.last, isNull);
      key.currentState!.setTotalSeconds(3661);
      await tester.pump();
      expect(key.currentState!.totalSeconds, 3661);
      expect(changes.last, 3661);
      expect(find.text('分钟和秒须在 0 到 59 之间'), findsNothing);
      for (final part in ['hours', 'minutes', 'seconds']) {
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey('duration_$part')))
              .controller!
              .text,
          '1',
        );
      }
      expect(() => key.currentState!.setTotalSeconds(0), throwsArgumentError);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('quick increments disable on invalid or overflowing values', (
    tester,
  ) async {
    final h = _h();
    await openDailyTimer(tester, h, autoStart: false);
    await tapDaily(tester, 'timer_adjust_time');
    await tester.enterText(
      find.byKey(const ValueKey('duration_minutes')),
      '60',
    );
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('add_time_1')))
          .onPressed,
      isNull,
    );
    final input = tester.state<StudyDurationInputState>(
      find.byType(StudyDurationInput),
    );
    input.setTotalSeconds(0x7fffffffffffffff - 90);
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('add_time_1')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('add_time_5')))
          .onPressed,
      isNull,
    );
    await tapDaily(tester, 'cancel_adjust_time');
    expect(h.plan.plannedSeconds, 600);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'home builds cards lazily and returns to the selected scroll position',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = _h();
      for (var index = 1; index < 150; index++) {
        h.store.addPlan(
          name: 'Plan $index',
          iconId: 'book',
          plannedSeconds: 60,
        );
      }
      await tester.pumpWidget(
        localizedApp(
          home: StudyHomePage(store: h.store, settings: h.settings),
        ),
      );
      expect(find.byType(StudyPlanCard).evaluate().length, lessThan(10));
      final last = h.store.plans.last;
      final button = find.byKey(ValueKey('start_plan_${last.id}'));
      expect(button, findsNothing);
      await tester.scrollUntilVisible(
        button,
        600,
        maxScrolls: 100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = position.pixels;
      expect(find.byType(StudyPlanCard).evaluate().length, lessThan(10));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        last.id,
        tester.widget<StudyTimerPage>(find.byType(StudyTimerPage)).planId,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(offset, 1));
      await tester.tap(find.text('统计'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(offset, 1),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
