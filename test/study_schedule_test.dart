import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_app/data/settings_store.dart';
import 'package:hello_app/data/study_plan_store.dart';
import 'package:hello_app/data/study_snapshot.dart';
import 'package:hello_app/models/study_backup.dart';
import 'package:hello_app/models/study_plan.dart';
import 'package:hello_app/models/study_record.dart';
import 'package:hello_app/models/study_scheme.dart';

import 'support/backup_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final monday = DateTime(2026, 10, 12, 12);

  for (var version = 1; version <= 5; version++) {
    test(
      'version $version migrates identities, configuration and progress',
      () {
        final plan = StudyPlan(
          id: 'custom_7',
          name: '阅读',
          iconId: 'book',
          plannedSeconds: 120,
          progressDay: '2026-10-12',
          remainingSeconds: 90,
          studiedSeconds: 30,
          hasStartedToday: true,
          customIconPath: '/managed/image.png',
        );
        final json = plan.toJson()..remove('schemeId');
        final snapshot = StudyPlanSnapshot.decode(
          jsonEncode({
            'version': version,
            'nextId': 2,
            'plans': [json],
            if (version != 1)
              'records': [
                const StudyRecord(
                  id: 'old',
                  planId: 'custom_7',
                  date: '2026-10-11',
                  plannedSeconds: 120,
                  studiedSeconds: 80,
                ).toJson(),
              ],
          }),
        );
        final store = StudyPlanStore.fromSnapshot(snapshot, now: () => monday);
        addTearDown(store.dispose);
        expect(store.todaySchemeId, defaultStudySchemeId);
        expect(store.weeklyAssignments.values.toSet(), {defaultStudySchemeId});
        expect(store.todayPlans.single.id, 'custom_7');
        expect(store.todayPlans.single.remainingSeconds, 90);
        expect(store.todayPlans.single.customIconPath, '/managed/image.png');
        expect(store.todayStudiedSeconds, 30);
        expect(
          store.addPlan(name: '数学', iconId: 'book', plannedSeconds: 60).id,
          'custom_8',
        );
        expect(
          StudyPlanSnapshot.decode(store.snapshot.encode()).schemes.length,
          1,
        );
      },
    );
  }

  test('week rules, cross-month overrides, rest and clearing overrides', () {
    final store = StudyPlanStore(now: () => monday);
    addTearDown(store.dispose);
    final weekend = store.addScheme('周末');
    final holiday = store.addScheme('假期');
    store.setWeeklyAssignments({6: weekend.id, 7: weekend.id});
    expect(store.schemeIdOn(DateTime(2026, 10, 16)), defaultStudySchemeId);
    expect(store.schemeIdOn(DateTime(2026, 10, 17)), weekend.id);
    final dates = [
      DateTime(2026, 10, 30),
      DateTime(2026, 10, 31),
      DateTime(2026, 11, 1),
    ];
    store.assignDates(dates, holiday.id);
    store.setWeeklyAssignments({5: weekend.id});
    expect(dates.map(store.schemeIdOn).toSet(), {holiday.id});
    store.assignDates([dates[1]], null);
    expect(store.schemeIdOn(dates[1]), isNull);
    expect(store.dateOverrides.containsKey('2026-10-31'), isTrue);
    store.restoreWeeklyDates(dates);
    expect(dates.map(store.schemeIdOn).toSet(), {weekend.id});
    expect(store.dateOverrides, isEmpty);
    expect(
      () => store.assignDates([DateTime(2026, 10, 11), dates[0]], holiday.id),
      throwsArgumentError,
    );
    expect(store.dateOverrides, isEmpty);
  });

  test(
    'switch A to B to A retains progress and blocks inactive sessions',
    () async {
      var now = monday;
      final disk = BackupPlanStorage();
      final store = StudyPlanStore(storage: disk, now: () => now);
      addTearDown(store.dispose);
      final a = store.addPlan(name: 'A', iconId: 'book', plannedSeconds: 90);
      final bScheme = store.addScheme('方案 B');
      final b = store.addPlan(
        name: 'B',
        iconId: 'book',
        plannedSeconds: 60,
        schemeId: bScheme.id,
      );
      store.beginRunning(a.id);
      final session = store.planById(a.id)!.sessionId;
      now = now.add(const Duration(seconds: 20));
      store.assignDates([now], bScheme.id);
      expect(store.planById(a.id)!.isRunning, isFalse);
      expect(store.planById(a.id)!.remainingSeconds, 70);
      expect(store.takeInvalidatedSessions(), {session});
      store.beginRunning(a.id);
      store.studySeconds(a.id, 30);
      expect(store.planById(a.id)!.studiedSeconds, 20);
      store.startOrResume(b.id);
      store.studySeconds(b.id, 15);
      store.assignDates([now], defaultStudySchemeId);
      expect(store.todayPlans.single.id, a.id);
      expect(store.todayPlans.single.remainingSeconds, 70);
      expect(store.todayStudiedSeconds, 35);
      expect(store.records, hasLength(2));
      store.assignDates([now], bScheme.id);
      expect(store.todayPlans.single.remainingSeconds, 45);
      expect(await store.flush(), isTrue);
      final reopened = await StudyPlanStore.load(storage: disk, now: () => now);
      addTearDown(reopened.dispose);
      expect(reopened.todaySchemeId, bScheme.id);
      expect(reopened.todayStudiedSeconds, 35);
      expect(
        reopened.plansForScheme(defaultStudySchemeId).single.studiedSeconds,
        20,
      );
    },
  );

  test('copied schemes have independent configuration and no progress', () {
    final store = StudyPlanStore(now: () => monday);
    addTearDown(store.dispose);
    final source = store.addPlan(
      name: '阅读',
      iconId: 'book',
      plannedSeconds: 120,
      customIconPath: '/managed/image.png',
    );
    store.updatePlan(source.copyWith(pauseWhenBackgrounded: false));
    store.startOrResume(source.id);
    store.studySeconds(source.id, 30);
    final copied = store.addScheme('周末', copyFrom: defaultStudySchemeId);
    final task = store.plansForScheme(copied.id).single;
    expect(task.id, isNot(source.id));
    expect(task.pauseWhenBackgrounded, isFalse);
    expect(task.customIconPath, source.customIconPath);
    expect(task.hasStartedToday, isFalse);
    expect(task.studiedSeconds, 0);
    store.updatePlan(store.planById(source.id)!.copyWith(plannedSeconds: 180));
    expect(store.planById(source.id)!.remainingSeconds, 150);
    expect(store.plansForScheme(copied.id).single.plannedSeconds, 120);
    store.updatePlan(store.planById(source.id)!.copyWith(plannedSeconds: 20));
    expect(store.planById(source.id)!.isCompletedToday, isTrue);
    expect(store.todayStudiedSeconds, 30);
  });

  test(
    'rest, deletion replacement and clearing data preserve the right data',
    () {
      final store = StudyPlanStore(now: () => monday);
      addTearDown(store.dispose);
      store.renameScheme(defaultStudySchemeId, '旧方案');
      final task = store.addPlan(
        name: '阅读',
        iconId: 'book',
        plannedSeconds: 90,
      );
      store.startOrResume(task.id);
      store.studySeconds(task.id, 20);
      store.assignDates([monday], null);
      expect(store.todayPlans, isEmpty);
      expect(store.todayStudiedSeconds, 20);
      final replacement = store.addScheme('替代方案');
      store.assignDates([DateTime(2026, 10, 20)], defaultStudySchemeId);
      store.deleteScheme(defaultStudySchemeId, replacementId: replacement.id);
      expect(store.weeklyAssignments.values.toSet(), {replacement.id});
      expect(store.schemeIdOn(DateTime(2026, 10, 20)), replacement.id);
      expect(store.records.single.schemeName, '旧方案');
      expect(store.records.single.planName, '阅读');
      expect(store.todayStudiedSeconds, 20);
      expect(
        () => store.deleteScheme(replacement.id, replacementId: null),
        throwsStateError,
      );
      store.clearLearningData();
      expect(store.records, isEmpty);
      expect(store.schemeIdOn(monday), isNull);
      store.clearAllData();
      expect(store.todaySchemeId, defaultStudySchemeId);
      expect(store.schemes, hasLength(1));
      expect(store.dateOverrides, isEmpty);
    },
  );

  test('edits update the current target and future previews without rewriting history', () {
    var now = monday;
    final store = StudyPlanStore(now: () => now);
    addTearDown(store.dispose);
    final task = store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    store.startOrResume(task.id);
    store.studySeconds(task.id, 30);
    store.updatePlan(store.planById(task.id)!.copyWith(plannedSeconds: 120));
    expect(store.todayPlans.single.remainingSeconds, 90);
    expect(store.records.single.plannedSeconds, 120);
    now = DateTime(2026, 10, 13, 12);
    store.refreshForToday();
    store.renameScheme(defaultStudySchemeId, '新名称');
    store.updatePlan(
      store.planById(task.id)!.copyWith(plannedSeconds: 60, name: '新任务名称'),
    );
    expect(store.records.single.plannedSeconds, 120);
    expect(store.records.single.planName, '阅读');
    expect(store.records.single.schemeName, '');
    expect(store.todayPlans.single.plannedSeconds, 60);
    expect(store.todayStudiedSeconds, 0);
  });

  test('custom day boundary resolves the new scheme and invalidates old running state', () {
    var now = DateTime(2026, 10, 13, 3, 50);
    final settings = SettingsStore();
    settings.update(settings.settings.copyWith(dailyResetHour: 4));
    final store = StudyPlanStore(settings: settings, now: () => now);
    addTearDown(() {
      store.dispose();
      settings.dispose();
    });
    final tuesday = store.addScheme('周二');
    store.setWeeklyAssignments({2: tuesday.id});
    final task = store.addPlan(
      name: '旧日任务',
      iconId: 'book',
      plannedSeconds: 3600,
    );
    store.beginRunning(task.id);
    final session = store.planById(task.id)!.sessionId;
    expect(store.todayKey, '2026-10-12');
    now = DateTime(2026, 10, 13, 4);
    store.refreshForToday();
    expect(store.todayKey, '2026-10-13');
    expect(store.todaySchemeId, tuesday.id);
    expect(store.takeInvalidatedSessions(), {session});
    expect(store.planById(task.id)!.hasStartedToday, isFalse);
    expect(store.records.single.date, '2026-10-12');
    expect(store.records.single.studiedSeconds, 600);
    store.beginRunning(task.id);
    expect(store.planById(task.id)!.isRunning, isFalse);
  });

  test('invalid schedules reject foreign references and recover allocation counters', () {
    final store = StudyPlanStore(now: () => monday);
    addTearDown(store.dispose);
    final scheme = store.addScheme('周末');
    store.addPlan(
      name: '阅读',
      iconId: 'book',
      plannedSeconds: 90,
      schemeId: scheme.id,
    );
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (v) => v['schemes'] = [],
      (v) => v['schemes'].add(v['schemes'][0]),
      (v) => v['weeklyAssignments']['1'] = 'foreign',
      (v) => v['weeklyAssignments'].remove('1'),
      (v) => v['dateOverrides']['2026-02-30'] = null,
      (v) => v['dateOverrides']['2026-10-12'] = 'foreign',
      (v) => v['plans'][0].remove('schemeId'),
    ]) {
      final value = jsonDecode(store.snapshot.encode()) as Map<String, dynamic>;
      mutate(value);
      expect(
        () => StudyPlanSnapshot.decode(jsonEncode(value)),
        throwsFormatException,
      );
    }
    final value = jsonDecode(store.snapshot.encode()) as Map<String, dynamic>;
    value['nextId'] = 1;
    value['records'].add(
      const StudyRecord(
        id: 'old',
        planId: 'custom_99',
        date: '2026-10-11',
        plannedSeconds: 60,
        studiedSeconds: 30,
        schemeId: 'scheme_110',
        schemeName: '已删除方案',
      ).toJson(),
    );
    final loaded = StudyPlanStore.fromSnapshot(
      StudyPlanSnapshot.decode(jsonEncode(value)),
      now: () => monday,
    );
    addTearDown(loaded.dispose);
    expect(loaded.addScheme('新方案').id, 'scheme_111');
  });

  test('failed schedule save retains progress and retry writes the latest selection', () async {
    final disk = BackupPlanStorage()..failWrites = true;
    final store = StudyPlanStore(storage: disk, now: () => monday);
    addTearDown(store.dispose);
    final task = store.addPlan(name: '阅读', iconId: 'book', plannedSeconds: 90);
    store.startOrResume(task.id);
    store.studySeconds(task.id, 20);
    final scheme = store.addScheme('周末');
    store.assignDates([monday], scheme.id);
    expect(await store.flush(), isFalse);
    store.assignDates([monday], null);
    expect(store.todayStudiedSeconds, 20);
    disk.failWrites = false;
    expect(await store.retrySave(), isTrue);
    final loaded = StudyPlanStore.fromSnapshot(
      StudyPlanSnapshot.decode(disk.value),
      now: () => monday,
    );
    addTearDown(loaded.dispose);
    expect(loaded.todaySchemeId, isNull);
    expect(loaded.todayStudiedSeconds, 20);
  });

  test(
    'version 2 backup restores all schemes, schedules and shared media',
    () async {
      final h = await BackupHarness.create();
      addTearDown(h.close);
      final icon = await h.icon();
      h.store.addPlan(
        name: '阅读',
        iconId: 'book',
        plannedSeconds: 90,
        customIconPath: icon,
      );
      final copy = h.store.addScheme('周末', copyFrom: defaultStudySchemeId);
      h.store.setWeeklyAssignments({6: copy.id, 7: copy.id});
      h.store.assignDates([h.now], copy.id);
      h.store.assignDates([DateTime(2026, 10, 9)], null);
      final task = h.store.todayPlans.single;
      h.store.startOrResume(task.id);
      h.store.studySeconds(task.id, 20);
      final service = h.service();
      final backup = StudyBackup.decode((await service.capture()).encode());
      expect(backup.toJson()['version'], 2);
      expect(backup.media, hasLength(1));
      expect(backup.plans.schemes, hasLength(2));
      h.store.clearAllData();
      await service.restore(backup);
      expect(h.store.todaySchemeId, copy.id);
      expect(h.store.todayStudiedSeconds, 20);
      expect(h.store.weeklyAssignments[6], copy.id);
      expect(h.store.schemeIdOn(DateTime(2026, 10, 9)), isNull);
      expect(h.store.plans.map((p) => p.customIconPath).toSet(), hasLength(1));
      expect(h.store.plans.first.customIconPath, isNot(icon));
    },
  );

  test('legacy version 1 backup imports into one default scheme', () async {
    final h = await BackupHarness.create();
    addTearDown(h.close);
    final task = h.store.addPlan(
      name: '旧任务',
      iconId: 'book',
      plannedSeconds: 90,
    );
    h.store.startOrResume(task.id);
    h.store.studySeconds(task.id, 20);
    final service = h.service();
    final value = (await service.capture()).toJson();
    value['version'] = 1;
    final plans = value['plans'] as Map<String, Object?>;
    plans['version'] = 5;
    plans.remove('schemes');
    plans.remove('weeklyAssignments');
    plans.remove('dateOverrides');
    for (final plan in plans['plans'] as List) {
      (plan as Map).remove('schemeId');
    }
    for (final record in plans['records'] as List) {
      (record as Map).remove('schemeId');
      record.remove('schemeName');
      record.remove('planName');
    }
    final legacy = StudyBackup.decode(
      Uint8List.fromList(utf8.encode(jsonEncode(value))),
    );
    h.store.addScheme('待覆盖');
    await service.restore(legacy);
    expect(h.store.schemes, hasLength(1));
    expect(h.store.todaySchemeId, defaultStudySchemeId);
    expect(h.store.todayPlans.single.id, task.id);
    expect(h.store.todayStudiedSeconds, 20);
  });
}
