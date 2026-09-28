import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/study_plan.dart';
import '../models/study_record.dart';
import 'settings_store.dart';
import 'study_plan_storage.dart';

class StudyPlanStore extends ChangeNotifier {
  StudyPlanStore({this.storage, this.settings, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    settings?.addListener(refreshForToday);
  }

  final StudyPlanStorage? storage;
  final SettingsStore? settings;
  final DateTime Function() _now;
  static const List<StudyPlan> _examplePlans = [
    StudyPlan(
      id: 'default_japanese',
      name: '日语',
      iconId: 'translate',
      plannedMinutes: 60,
    ),
    StudyPlan(
      id: 'default_english',
      name: '英语',
      iconId: 'language',
      plannedMinutes: 60,
    ),
    StudyPlan(
      id: 'default_math',
      name: '数学',
      iconId: 'calculate',
      plannedMinutes: 120,
    ),
    StudyPlan(
      id: 'default_programming',
      name: '编程',
      iconId: 'code',
      plannedMinutes: 120,
    ),
  ];
  final List<StudyPlan> _plans = [..._examplePlans];
  final List<StudyRecord> _records = [];
  int _nextId = 1;
  String? _pendingSnapshot;
  Future<void>? _writeTask;
  Object? _lastWriteError;

  static Future<StudyPlanStore> load({
    required StudyPlanStorage storage,
    SettingsStore? settings,
    DateTime Function()? now,
  }) async {
    final store = StudyPlanStore(
      storage: storage,
      settings: settings,
      now: now,
    );
    final saved = await storage.read();
    var needsWrite = false;
    if (saved != null) {
      try {
        final decoded = jsonDecode(saved);
        if (decoded is! Map<String, dynamic> ||
            (decoded['version'] != 1 && decoded['version'] != 2) ||
            decoded['plans'] is! List) {
          throw const FormatException('Invalid saved plans');
        }
        final loaded = (decoded['plans'] as List)
            .map(
              (item) =>
                  StudyPlan.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        final loadedRecords = decoded['version'] == 2
            ? (decoded['records'] as List)
                  .map(
                    (item) => StudyRecord.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ),
                  )
                  .toList()
            : <StudyRecord>[];
        store._plans
          ..clear()
          ..addAll(loaded);
        store._records.addAll(loadedRecords);
        needsWrite = decoded['version'] == 1;
        final nextId = decoded['nextId'];
        if (nextId is int && nextId > 0) store._nextId = nextId;
        while (store._plans.any(
          (plan) => plan.id == 'custom_${store._nextId}',
        )) {
          store._nextId++;
        }
      } on FormatException {
        // Keep the example plans if saved data has an unsupported format.
      } on TypeError {
        // Keep the example plans if saved data has invalid field types.
      }
    }
    for (final plan in store._plans) {
      if (store._syncRecord(plan)) needsWrite = true;
    }
    store.refreshForToday();
    if (needsWrite) store._scheduleWrite();
    return store;
  }

  List<StudyPlan> get plans => List.unmodifiable(_plans);
  List<StudyRecord> get records => List.unmodifiable(_records);

  StudyPlan? planById(String id) {
    for (final plan in _plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  String get _today {
    final current = _now();
    final date = settings?.studyDate(current) ?? current;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void refreshForToday() {
    final today = _today;
    var changed = false;
    for (var index = 0; index < _plans.length; index++) {
      final plan = _plans[index];
      if (plan.hasStartedToday && plan.progressDay != today) {
        _syncRecord(plan);
        _plans[index] = plan.withProgress(
          day: null,
          remainingSeconds: 0,
          studiedSeconds: 0,
          hasStartedToday: false,
          isCompletedToday: false,
        );
        changed = true;
      }
    }
    if (changed) _changed();
  }

  void addPlan({
    required String name,
    required String iconId,
    required int plannedMinutes,
  }) {
    refreshForToday();
    _plans.add(
      StudyPlan(
        id: 'custom_${_nextId++}',
        name: name,
        iconId: iconId,
        plannedMinutes: plannedMinutes,
      ),
    );
    _changed();
  }

  void updatePlan(StudyPlan updated) {
    refreshForToday();
    final index = _plans.indexWhere((plan) => plan.id == updated.id);
    if (index == -1) return;
    final previous = _plans[index];
    final calculatedRemaining =
        updated.plannedMinutes == previous.plannedMinutes
        ? previous.remainingSeconds
        : updated.plannedMinutes * 60 - previous.studiedSeconds;
    final remaining = previous.hasStartedToday && calculatedRemaining > 0
        ? calculatedRemaining
        : 0;
    _plans[index] = updated.withProgress(
      day: previous.progressDay,
      remainingSeconds: remaining,
      studiedSeconds: previous.studiedSeconds,
      hasStartedToday: previous.hasStartedToday,
      isCompletedToday: previous.hasStartedToday && remaining == 0,
    );
    _syncRecord(_plans[index]);
    _changed();
  }

  void adjustRemainingMinutes(String id, int minutes) {
    if (minutes <= 0 || minutes > 0x7fffffffffffffff ~/ 60) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    refreshForToday();
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index == -1) return;
    final plan = _plans[index];
    _plans[index] = plan.withProgress(
      day: _today,
      remainingSeconds: minutes * 60,
      studiedSeconds: plan.studiedSeconds,
      hasStartedToday: true,
      isCompletedToday: false,
    );
    _syncRecord(_plans[index]);
    _changed();
  }

  void deletePlan(String id) {
    final oldLength = _plans.length;
    _plans.removeWhere((plan) => plan.id == id);
    if (_plans.length != oldLength) _changed();
  }

  void restorePlan(StudyPlan plan, {int? index}) {
    if (_plans.any((item) => item.id == plan.id)) return;
    final position = index == null
        ? _plans.length
        : index.clamp(0, _plans.length);
    _plans.insert(position, plan);
    _syncRecord(plan);
    _changed();
  }

  void clearLearningData() {
    for (var index = 0; index < _plans.length; index++) {
      _plans[index] = _plans[index].withProgress(
        day: null,
        remainingSeconds: 0,
        studiedSeconds: 0,
        hasStartedToday: false,
        isCompletedToday: false,
      );
    }
    _records.clear();
    _changed();
  }

  void clearAllData() {
    _plans
      ..clear()
      ..addAll(_examplePlans);
    _records.clear();
    _nextId = 1;
    _changed();
  }

  void startOrResume(String id) {
    refreshForToday();
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index == -1) return;
    final plan = _plans[index];
    if (plan.hasStartedToday) return;
    _plans[index] = plan.withProgress(
      day: _today,
      remainingSeconds: plan.plannedMinutes * 60,
      studiedSeconds: 0,
      hasStartedToday: true,
      isCompletedToday: false,
    );
    _syncRecord(_plans[index]);
    _changed();
  }

  void studyOneSecond(String id) {
    refreshForToday();
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index == -1) return;
    final plan = _plans[index];
    if (!plan.hasStartedToday || plan.remainingSeconds == 0) return;
    final remaining = plan.remainingSeconds - 1;
    _plans[index] = plan.withProgress(
      day: _today,
      remainingSeconds: remaining,
      studiedSeconds: plan.studiedSeconds + 1,
      hasStartedToday: true,
      isCompletedToday: remaining == 0,
    );
    _syncRecord(_plans[index]);
    _changed();
  }

  bool _syncRecord(StudyPlan plan) {
    if (!plan.hasStartedToday || plan.progressDay == null) return false;
    final record = StudyRecord(
      id: '${plan.progressDay}_${plan.id}',
      planId: plan.id,
      date: plan.progressDay!,
      plannedSeconds: plan.plannedMinutes * 60,
      studiedSeconds: plan.studiedSeconds,
    );
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index == -1) {
      _records.add(record);
      return true;
    }
    final previous = _records[index];
    if (previous.plannedSeconds == record.plannedSeconds &&
        previous.studiedSeconds == record.studiedSeconds) {
      return false;
    }
    _records[index] = record;
    return true;
  }

  void _changed() {
    notifyListeners();
    _scheduleWrite();
  }

  void _scheduleWrite() {
    final target = storage;
    if (target == null) return;
    _pendingSnapshot = jsonEncode({
      'version': 2,
      'nextId': _nextId,
      'plans': _plans.map((plan) => plan.toJson()).toList(),
      'records': _records.map((record) => record.toJson()).toList(),
    });
    _writeTask ??= _drainWrites(target);
  }

  Future<void> _drainWrites(StudyPlanStorage storage) async {
    while (_pendingSnapshot != null) {
      final snapshot = _pendingSnapshot!;
      _pendingSnapshot = null;
      try {
        await storage.write(snapshot);
        _lastWriteError = null;
      } catch (error) {
        _lastWriteError = error;
      }
    }
    _writeTask = null;
  }

  Future<bool> flush() async {
    while (_writeTask != null) {
      await _writeTask;
    }
    return _lastWriteError == null;
  }

  @override
  void dispose() {
    settings?.removeListener(refreshForToday);
    super.dispose();
  }
}
