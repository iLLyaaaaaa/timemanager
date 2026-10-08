import 'support/localized_app.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hello_app/data/study_plan_storage.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/pages/study_home_page.dart';
import 'package:hello_app/pages/plan_management_page.dart';
import 'package:hello_app/pages/study_statistics_page.dart';
import 'package:hello_app/pages/study_timer_page.dart';
import 'package:hello_app/utils/study_duration.dart';
import 'package:hello_app/services/screen_state_service.dart';
import 'package:hello_app/widgets/study_plan_icon.dart';

class _UnlockedScreen extends ScreenStateService {
  @override
  Future<bool> isScreenLocked() async => false;
}

class _MemoryStorage implements StudyPlanStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String snapshot) async {
    value = snapshot;
  }
}

class _FakePreferences implements SharedPreferencesAsync {
  _FakePreferences(this.values);

  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final today = DateTime(2026, 9, 28);

  test(
    'running session survives process reload and uses target end time',
    () async {
      final storage = _MemoryStorage();
      var now = DateTime(2026, 9, 28, 12);
      final store = await StudyPlanStore.load(storage: storage, now: () => now);
      addTearDown(store.dispose);
      store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 120);
      final id = store.plans.single.id;
      store.beginRunning(id);
      final end = store.plans.single.targetEndTime;
      expect(end, now.add(const Duration(seconds: 120)));
      expect(await store.flush(), isTrue);
      now = now.add(const Duration(seconds: 67));
      final reopened = await StudyPlanStore.load(
        storage: storage,
        now: () => now,
      );
      addTearDown(reopened.dispose);
      expect(reopened.planById(id)!.remainingSeconds, 53);
      expect(reopened.planById(id)!.studiedSeconds, 67);
      expect(reopened.planById(id)!.isRunning, isTrue);
      reopened.pauseRunning(id);
      now = now.add(const Duration(minutes: 2));
      reopened.reconcileRunning(id);
      expect(reopened.planById(id)!.remainingSeconds, 53);
      expect(reopened.planById(id)!.studiedSeconds, 67);
    },
  );

  test(
    'custom icon path survives reload while legacy icons remain built in',
    () async {
      final storage = _MemoryStorage();
      final store = await StudyPlanStore.load(
        storage: storage,
        now: () => today,
      );
      addTearDown(store.dispose);
      store.addPlan(
        name: '自定义',
        iconId: 'category',
        plannedSeconds: 90,
        customIconPath: '/app/custom_icons/icon.png',
      );
      expect(await store.flush(), isTrue);
      final reopened = await StudyPlanStore.load(
        storage: storage,
        now: () => today,
      );
      addTearDown(reopened.dispose);
      expect(
        reopened.plans.single.customIconPath,
        '/app/custom_icons/icon.png',
      );
      expect(reopened.plans.single.iconId, 'category');
    },
  );

  test('duration formatter uses seconds everywhere', () {
    expect(formatStudyDuration(0), '00:00');
    expect(formatStudyDuration(90), '01:30');
    expect(formatStudyDuration(3599), '59:59');
    expect(formatStudyDuration(3600), '01:00:00');
  });

  test('fresh data stays empty through reload and clear all', () async {
    final storage = _MemoryStorage();
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    expect(store.plans, isEmpty);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    store.clearAllData();
    expect(await store.flush(), isTrue);
    store.dispose();
    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => today,
    );
    addTearDown(reopened.dispose);
    expect(reopened.plans, isEmpty);
  });

  test(
    'SharedPreferences keeps the version 3 snapshot as a migration backup',
    () async {
      final previous = jsonEncode({
        'version': 3,
        'nextId': 2,
        'plans': [
          {
            'id': 'custom_1',
            'name': '阅读',
            'iconId': 'book',
            'plannedSeconds': 90,
            'remainingSeconds': 0,
            'studiedSeconds': 0,
            'hasStartedToday': false,
            'isCompletedToday': false,
          },
        ],
        'records': <Object>[],
      });
      final preferences = _FakePreferences({'study_plans_v3': previous});
      final storage = SharedPreferencesPlanStorage(preferences: preferences);
      final store = await StudyPlanStore.load(
        storage: storage,
        now: () => today,
      );
      addTearDown(store.dispose);
      expect(store.plans.single.name, '阅读');
      expect(await store.flush(), isTrue);
      expect(await preferences.getString('study_plans_v3'), previous);
      final migrated = await preferences.getString('study_plans_v5');
      expect(jsonDecode(migrated!)['version'], 5);
      expect(jsonDecode(migrated)['plans'][0]['pauseWhenBackgrounded'], isTrue);
    },
  );

  test(
    'legacy plans migrate without losing second precision or history',
    () async {
      final storage = _MemoryStorage();
      storage.value = jsonEncode({
        'version': 2,
        'nextId': 2,
        'plans': [
          {
            'id': 'custom_1',
            'name': '阅读',
            'iconId': 'book',
            'plannedMinutes': 60,
            'progressDay': '2026-09-28',
            'remainingSeconds': 2537,
            'studiedSeconds': 1063,
            'hasStartedToday': true,
            'isCompletedToday': false,
          },
        ],
        'records': [
          {
            'id': '2026-09-27_custom_1',
            'planId': 'custom_1',
            'date': '2026-09-27',
            'plannedSeconds': 3600,
            'studiedSeconds': 1500,
          },
        ],
      });
      final legacy = storage.value;
      final store = await StudyPlanStore.load(
        storage: storage,
        now: () => today,
      );
      addTearDown(store.dispose);
      expect(store.plans.single.plannedSeconds, 3600);
      expect(store.plans.single.remainingSeconds, 2537);
      expect(store.plans.single.studiedSeconds, 1063);
      expect(store.records.length, 2);
      expect(store.records.first.date, '2026-09-27');
      expect(await store.flush(), isTrue);
      expect(jsonDecode(storage.value!)['version'], 5);
      expect(legacy, contains('plannedMinutes'));
      store.deletePlan('custom_1');
      expect(store.records.length, 2);
      expect(await store.flush(), isTrue);
      final reopened = await StudyPlanStore.load(
        storage: storage,
        now: () => today,
      );
      addTearDown(reopened.dispose);
      expect(reopened.plans, isEmpty);
      expect(reopened.records.length, 2);
    },
  );

  test('unknown snapshot is never overwritten with empty data', () async {
    final storage = _MemoryStorage()..value = '{"version":99,"plans":[]}';
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    expect(store.hasLoadError, isTrue);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    await store.flush();
    expect(storage.value, '{"version":99,"plans":[]}');
  });

  test(
    'version 3 plans gain a default background pause without losing data',
    () async {
      final storage = _MemoryStorage()
        ..value = jsonEncode({
          'version': 3,
          'nextId': 2,
          'plans': [
            {
              'id': 'custom_1',
              'name': '阅读',
              'iconId': 'book',
              'plannedSeconds': 90,
              'progressDay': '2026-09-28',
              'remainingSeconds': 37,
              'studiedSeconds': 53,
              'hasStartedToday': true,
              'isCompletedToday': false,
            },
          ],
          'records': [
            {
              'id': '2026-09-28_custom_1',
              'planId': 'custom_1',
              'date': '2026-09-28',
              'plannedSeconds': 90,
              'studiedSeconds': 53,
            },
          ],
        });
      final store = await StudyPlanStore.load(
        storage: storage,
        now: () => today,
      );
      addTearDown(store.dispose);
      expect(store.plans.single.pauseWhenBackgrounded, isTrue);
      expect(store.plans.single.remainingSeconds, 37);
      expect(store.plans.single.studiedSeconds, 53);
      expect(store.records.single.studiedSeconds, 53);
      expect(await store.flush(), isTrue);
      expect(jsonDecode(storage.value!)['version'], 5);
      expect(
        jsonDecode(storage.value!)['plans'][0]['pauseWhenBackgrounded'],
        isTrue,
      );
    },
  );

  testWidgets('a plan with background pause disabled continues on resume', (
    tester,
  ) async {
    final store = StudyPlanStore(now: () => today);
    addTearDown(store.dispose);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    final id = store.plans.single.id;
    store.updatePlan(store.plans.single.copyWith(pauseWhenBackgrounded: false));
    var clock = DateTime(2026, 9, 28, 12);
    await tester.pumpWidget(
      localizedApp(
        home: StudyTimerPage(store: store, planId: id, now: () => clock),
      ),
    );
    await tester.tap(find.text('开始'));
    await tester.pump();
    clock = clock.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(store.plans.single.studiedSeconds, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    clock = clock.add(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 30));
    expect(store.plans.single.studiedSeconds, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(store.plans.single.studiedSeconds, 22);
    expect(store.plans.single.remainingSeconds, 68);
    expect(find.text('暂停'), findsOneWidget);
    clock = clock.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(store.plans.single.studiedSeconds, 23);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);
  });

  testWidgets('each plan keeps its own background setting after reload', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final store = await StudyPlanStore.load(storage: storage, now: () => today);
    addTearDown(store.dispose);
    store.addPlan(name: '日语', iconId: 'language', plannedSeconds: 90);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 120);
    final firstId = store.plans.first.id;
    final secondId = store.plans.last.id;
    store.startOrResume(firstId);
    store.studyOneSecond(firstId);
    await tester.pumpWidget(
      localizedApp(home: PlanManagementPage(store: store)),
    );
    final secondSwitch = find.byKey(ValueKey('background_pause_$secondId'));
    await tester.ensureVisible(secondSwitch);
    await tester.pumpAndSettle();
    await tester.tap(secondSwitch);
    await tester.pump();
    expect(find.byKey(ValueKey('background_pause_$firstId')), findsOneWidget);
    expect(tester.widget<SwitchListTile>(secondSwitch).value, isFalse);
    expect(store.planById(firstId)!.pauseWhenBackgrounded, isTrue);
    expect(store.planById(secondId)!.pauseWhenBackgrounded, isFalse);
    await tester.pumpAndSettle();
    expect(
      jsonDecode(storage.value!)['plans'][1]['pauseWhenBackgrounded'],
      isFalse,
    );
    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => today,
    );
    addTearDown(reopened.dispose);
    expect(reopened.planById(firstId)!.pauseWhenBackgrounded, isTrue);
    expect(reopened.planById(secondId)!.pauseWhenBackgrounded, isFalse);
    expect(reopened.planById(firstId)!.studiedSeconds, 1);
    expect(reopened.records.single.planId, firstId);
  });

  testWidgets('large plan icons fit a narrow management page', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = StudyPlanStore(now: () => today);
    addTearDown(store.dispose);
    store.addPlan(
      name: '一个比较长的自定义学习计划名称',
      iconId: 'book',
      plannedSeconds: 3600,
    );
    await tester.pumpWidget(
      localizedApp(home: PlanManagementPage(store: store)),
    );
    await tester.pumpAndSettle();
    final icon = tester.widget<StudyPlanIcon>(find.byType(StudyPlanIcon));
    expect(icon.tileSize, 112);
    final iconRect = tester.getRect(find.byType(StudyPlanIcon));
    expect(iconRect.width, 112);
    expect(iconRect.height, 112);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      localizedApp(
        home: PlanManagementPage(store: store),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      localizedApp(home: PlanManagementPage(store: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle_bulk_mode')));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('开启后台自动暂停'), findsNothing);
    expect(find.text('关闭后台自动暂停'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'daily target edits retain studied time and crossing day keeps history',
    () {
      var now = today;
      final store = StudyPlanStore(now: () => now);
      addTearDown(store.dispose);
      store.addPlan(name: '数学', iconId: 'calculate', plannedSeconds: 90);
      final id = store.plans.single.id;
      store.startOrResume(id);
      for (var i = 0; i < 70; i++) {
        store.studyOneSecond(id);
      }
      store.updatePlan(store.plans.single.copyWith(plannedSeconds: 120));
      expect(store.plans.single.remainingSeconds, 50);
      store.updatePlan(store.plans.single.copyWith(plannedSeconds: 60));
      expect(store.plans.single.remainingSeconds, 0);
      expect(store.plans.single.studiedSeconds, 70);
      expect(store.plans.single.isCompletedToday, isTrue);
      now = DateTime(2026, 9, 29);
      store.refreshForToday();
      expect(store.plans.single.hasStartedToday, isFalse);
      expect(store.plans.single.studiedSeconds, 0);
      expect(store.records.single.studiedSeconds, 70);
      expect(store.records.single.planId, id);
    },
  );

  testWidgets('pause, return, reload and background exclude idle time', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final store = await StudyPlanStore.load(
      storage: storage,
      now: () => tester.binding.clock.now(),
    );
    addTearDown(store.dispose);
    store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    final id = store.plans.single.id;
    await tester.pumpWidget(
      localizedApp(
        home: StudyHomePage(store: store, screenState: _UnlockedScreen()),
      ),
    );
    final startButton = find.byKey(ValueKey('start_plan_$id'));
    await tester.scrollUntilVisible(
      startButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(find.text('01:30'), findsOneWidget);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(store.plans.single.studiedSeconds, 0);
    expect(store.plans.single.isRunning, isFalse);
    await tester.tap(find.text('继续'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(store.plans.single.remainingSeconds, 88);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(store.plans.single.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 30));
    expect(store.plans.single.remainingSeconds, 88);
    expect(store.plans.single.studiedSeconds, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('今日剩余 01:28'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('今日剩余 01:28'), findsOneWidget);
    expect(await store.flush(), isTrue);
    final reopened = await StudyPlanStore.load(
      storage: storage,
      now: () => tester.binding.clock.now(),
    );
    addTearDown(reopened.dispose);
    expect(reopened.planById(id)!.remainingSeconds, 88);
    expect(reopened.planById(id)!.studiedSeconds, 2);
  });

  testWidgets(
    'adjusted remaining time does not change target or studied time',
    (tester) async {
      final store = StudyPlanStore(now: () => tester.binding.clock.now());
      addTearDown(store.dispose);
      store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 60);
      final id = store.plans.single.id;
      await tester.pumpWidget(
        localizedApp(
          home: StudyTimerPage(store: store, planId: id),
        ),
      );
      await tester.tap(find.text('开始'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.ensureVisible(find.text('调整时间'));
      await tester.pump();
      await tester.tap(find.text('调整时间'));
      await tester.pumpAndSettle();
      expect(store.plans.single.isRunning, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(store.plans.single.studiedSeconds, 3);
      await tester.enterText(
        find.byKey(const ValueKey('duration_minutes')),
        '2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('duration_seconds')),
        '0',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(store.plans.single.plannedSeconds, 60);
      expect(store.plans.single.remainingSeconds, 120);
      expect(store.plans.single.studiedSeconds, 3);
      expect(store.plans.single.isRunning, isTrue);
      await tester.pump(const Duration(seconds: 5));
      expect(store.plans.single.studiedSeconds, 8);
      expect(find.text('01:55'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('statistics cards use square icons on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = StudyPlanStore(now: () => today);
    addTearDown(store.dispose);
    store.addPlan(name: '啊啊啊啊我要草坨', iconId: 'book', plannedSeconds: 3600);
    final id = store.plans.single.id;
    for (final locale in [const Locale('zh'), const Locale('en')]) {
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(body: StudyStatisticsPage(store: store)),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      final icon = find.byKey(ValueKey('statistics_icon_$id'));
      final rect = tester.getRect(icon);
      expect(rect.width, StudyPlanIcon.cardTileSize);
      expect(rect.height, StudyPlanIcon.cardTileSize);
      final title = tester.widget<Text>(find.text('啊啊啊啊我要草坨'));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('completion percentage exceeds 100 while bar is capped', (
    tester,
  ) async {
    final store = StudyPlanStore(now: () => today);
    addTearDown(store.dispose);
    store.addPlan(name: '数学', iconId: 'calculate', plannedSeconds: 60);
    final id = store.plans.single.id;
    store.adjustRemainingSeconds(id, 120);
    for (var i = 0; i < 120; i++) {
      store.studyOneSecond(id);
    }
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(body: StudyStatisticsPage(store: store)),
      ),
    );
    expect(find.text('今日完成率：200%'), findsOneWidget);
    expect(find.text('超出计划：01:00'), findsOneWidget);
    for (final bar in tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    )) {
      expect(bar.value, 1.0);
    }
    store.deletePlan(id);
    await tester.pump();
    expect(store.records.single.studiedSeconds, 120);
  });
}
