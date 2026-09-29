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
  final List<StudyPlan> _plans = [];
  final List<StudyRecord> _records = [];
  int _nextId = 1;
  String? _pendingSnapshot;
  Future<void>? _writeTask;
  Object? _lastWriteError;
  bool _hasLoadError = false;
  bool _disposed = false;

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
            (decoded['version'] != 1 &&
                decoded['version'] != 2 &&
                decoded['version'] != 3 &&
                decoded['version'] != 4 &&
                decoded['version'] != 5) ||
            decoded['plans'] is! List) {
          throw const FormatException('Invalid saved plans');
        }
        final loaded = (decoded['plans'] as List)
            .map(
              (item) =>
                  StudyPlan.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        final loadedRecords = decoded['version'] != 1
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
        needsWrite = decoded['version'] != 5;
        final nextId = decoded['nextId'];
        if (nextId is int && nextId > 0) store._nextId = nextId;
        while (store._plans.any(
          (plan) => plan.id == 'custom_${store._nextId}',
        )) {
          store._nextId++;
        }
      } on FormatException {
        store._hasLoadError = true;
      } on TypeError {
        store._hasLoadError = true;
      }
    }
    for (final plan in List<StudyPlan>.of(store._plans)) {
      if (plan.isRunning) store.reconcileRunning(plan.id);
      if (store._syncRecord(store.planById(plan.id) ?? plan)) needsWrite = true;
    }
    store.refreshForToday();
    if (needsWrite) store._scheduleWrite();
    return store;
  }

  List<StudyPlan> get plans => List.unmodifiable(_plans);
  DateTime get currentTime => _now();
  List<StudyRecord> get records => List.unmodifiable(_records);
  bool get hasLoadError => _hasLoadError;
  bool get isDisposed => _disposed;

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
          clearRunning: true,
        );
        changed = true;
      }
    }
    if (changed) _changed();
  }

  void addPlan({
    required String name,
    required String iconId,
    required int plannedSeconds,
    String? customIconPath,
  }) {
    refreshForToday();
    _plans.add(
      StudyPlan(
        id: 'custom_${_nextId++}',
        name: name,
        iconId: iconId,
        plannedSeconds: plannedSeconds,
        customIconPath: customIconPath,
      ),
    );
    _changed();
  }

  void updatePlan(StudyPlan updated) {
    refreshForToday();
    final index = _plans.indexWhere((plan) => plan.id == updated.id);
    if (index == -1) return;
    if (_plans[index].isRunning) reconcileRunning(updated.id);
    final previous = _plans[index];
    final calculatedRemaining =
        updated.plannedSeconds == previous.plannedSeconds
        ? previous.remainingSeconds
        : updated.plannedSeconds - previous.studiedSeconds;
    final remaining = previous.hasStartedToday && calculatedRemaining > 0
        ? calculatedRemaining
        : 0;
    _plans[index] = previous
        .copyWith(
          name: updated.name,
          iconId: updated.iconId,
          plannedSeconds: updated.plannedSeconds,
          pauseWhenBackgrounded: updated.pauseWhenBackgrounded,
          customIconPath: updated.customIconPath,
          clearCustomIcon: updated.customIconPath == null,
        )
        .withProgress(
          day: previous.progressDay,
          remainingSeconds: remaining,
          studiedSeconds: previous.studiedSeconds,
          hasStartedToday: previous.hasStartedToday,
          isCompletedToday: previous.hasStartedToday && remaining == 0,
          clearRunning: updated.plannedSeconds != previous.plannedSeconds,
        );
    if (previous.isRunning &&
        remaining > 0 &&
        updated.plannedSeconds != previous.plannedSeconds) {
      final now = _now();
      _plans[index] = _plans[index].withSession(
        startedAt: now,
        sessionId: '${updated.id}_${now.microsecondsSinceEpoch}',
      );
    }
    _syncRecord(_plans[index]);
    _changed();
  }

  int setBackgroundPauseForPlans(Set<String> ids, bool enabled) {
    if (ids.isEmpty) return 0;
    refreshForToday();
    var matched = 0;
    var changed = false;
    for (var index = 0; index < _plans.length; index++) {
      final plan = _plans[index];
      if (!ids.contains(plan.id)) continue;
      matched++;
      if (plan.pauseWhenBackgrounded == enabled) continue;
      _plans[index] = plan.copyWith(pauseWhenBackgrounded: enabled);
      changed = true;
    }
    if (changed) _changed();
    return matched;
  }

  void adjustRemainingSeconds(String id, int seconds) {
    if (seconds <= 0) {
      throw ArgumentError.value(seconds, 'seconds');
    }
    refreshForToday();
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index == -1) return;
    final plan = _plans[index];
    _plans[index] = plan.withProgress(
      day: _today,
      remainingSeconds: seconds,
      studiedSeconds: plan.studiedSeconds,
      hasStartedToday: true,
      isCompletedToday: false,
      clearRunning: true,
    );
    _syncRecord(_plans[index]);
    _changed();
  }

  void deletePlan(String id) {
    deletePlans({id});
  }

  void deletePlans(Set<String> ids) {
    final oldLength = _plans.length;
    _plans.removeWhere((plan) => ids.contains(plan.id));
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
        clearRunning: true,
      );
    }
    _records.clear();
    _changed();
  }

  void clearAllData() {
    _plans.clear();
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
      remainingSeconds: plan.plannedSeconds,
      studiedSeconds: 0,
      hasStartedToday: true,
      isCompletedToday: false,
    );
    _syncRecord(_plans[index]);
    _changed();
  }

  void beginRunning(String id, {DateTime? now}) {
    startOrResume(id);
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index == -1 ||
        _plans[index].isCompletedToday ||
        _plans[index].isRunning) {
      return;
    }
    now ??= _now();
    _plans[index] = _plans[index].withSession(
      startedAt: now,
      sessionId: '${id}_${now.microsecondsSinceEpoch}',
    );
    _changed();
  }

  void reconcileRunning(String id, {DateTime? now}) {
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index == -1) return;
    final plan = _plans[index];
    if (!plan.isRunning) return;
    final elapsed = (now ?? _now()).difference(plan.startedAt!).inSeconds;
    final consumed = elapsed.clamp(0, plan.sessionStartRemainingSeconds!);
    final remaining = plan.sessionStartRemainingSeconds! - consumed;
    final studied = plan.sessionStartStudiedSeconds! + consumed;
    if (remaining == plan.remainingSeconds && studied == plan.studiedSeconds) {
      return;
    }
    _plans[index] = plan.withProgress(
      day: plan.progressDay,
      remainingSeconds: remaining,
      studiedSeconds: studied,
      hasStartedToday: true,
      isCompletedToday: remaining == 0,
      clearRunning: remaining == 0,
    );
    _syncRecord(_plans[index]);
    _changed();
  }

  void pauseRunning(String id, {DateTime? now}) {
    reconcileRunning(id, now: now);
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index == -1 || !_plans[index].isRunning) return;
    final plan = _plans[index];
    _plans[index] = plan.withProgress(
      day: plan.progressDay,
      remainingSeconds: plan.remainingSeconds,
      studiedSeconds: plan.studiedSeconds,
      hasStartedToday: plan.hasStartedToday,
      isCompletedToday: plan.isCompletedToday,
      clearRunning: true,
    );
    _changed();
  }

  void studyOneSecond(String id) => studySeconds(id, 1);

  void studySeconds(String id, int seconds) {
    if (seconds <= 0) return;
    refreshForToday();
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index == -1) return;
    final plan = _plans[index];
    if (!plan.hasStartedToday || plan.remainingSeconds == 0) return;
    final consumed = seconds < plan.remainingSeconds
        ? seconds
        : plan.remainingSeconds;
    final remaining = plan.remainingSeconds - consumed;
    _plans[index] = plan.withProgress(
      day: _today,
      remainingSeconds: remaining,
      studiedSeconds: plan.studiedSeconds + consumed,
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
      plannedSeconds: plan.plannedSeconds,
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
    if (target == null || _hasLoadError) return;
    _pendingSnapshot = jsonEncode({
      'version': 5,
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
    _disposed = true;
    settings?.removeListener(refreshForToday);
    super.dispose();
  }
}
