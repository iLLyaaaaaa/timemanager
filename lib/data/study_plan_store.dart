import 'snapshot_writer.dart';
import 'study_snapshot.dart';

import 'package:flutter/foundation.dart';

import '../models/study_plan.dart';
import '../models/study_record.dart';
import '../models/study_scheme.dart';
import '../utils/study_history.dart';
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
  final List<StudyScheme> _schemes = [const StudyScheme.defaultScheme()];
  final Map<int, String?> _weeklyAssignments = {
    for (var day = 1; day <= 7; day++) day: defaultStudySchemeId,
  };
  final Map<String, String?> _dateOverrides = {};
  final Set<String> _invalidatedSessions = {};
  String? _knownDay;
  int _nextId = 1;
  late final _writer = SnapshotWriter(storage?.write)
    ..addListener(_notifyPersistence);
  bool _isReplacing = false;
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
    try {
      final snapshot = StudyPlanSnapshot.decode(await storage.read());
      store._install(snapshot);
      store._initialize(snapshot.sourceVersion != 6);
    } catch (_) {
      store._hasLoadError = true;
    }
    return store;
  }

  static StudyPlanStore fromSnapshot(
    StudyPlanSnapshot snapshot, {
    StudyPlanStorage? storage,
    SettingsStore? settings,
    DateTime Function()? now,
  }) {
    final store = StudyPlanStore(
      storage: storage,
      settings: settings,
      now: now,
    );
    store._install(snapshot);
    store._initialize(snapshot.sourceVersion != 6);
    return store;
  }

  void _install(StudyPlanSnapshot snapshot) {
    _plans
      ..clear()
      ..addAll(snapshot.plans);
    _records
      ..clear()
      ..addAll(snapshot.records);
    _nextId = snapshot.nextId;
    _schemes
      ..clear()
      ..addAll(snapshot.schemes);
    _weeklyAssignments
      ..clear()
      ..addAll(snapshot.weeklyAssignments);
    _dateOverrides
      ..clear()
      ..addAll(snapshot.dateOverrides);
    _knownDay = null;
  }

  void _initialize(bool needsWrite) {
    for (final plan in List<StudyPlan>.of(_plans)) {
      if (plan.isRunning) reconcileRunning(plan.id);
      if (_syncRecord(planById(plan.id) ?? plan)) needsWrite = true;
    }
    refreshForToday();
    if (needsWrite) _scheduleWrite();
  }

  StudyPlanSnapshot get snapshot => StudyPlanSnapshot(
    plans: _plans,
    records: _records,
    nextId: _nextId,
    schemes: _schemes,
    weeklyAssignments: _weeklyAssignments,
    dateOverrides: _dateOverrides,
  );
  bool get isSaving => _writer.isSaving;
  bool get hasSaveError => _writer.hasSaveError;
  bool get hasUnsavedChanges => _writer.hasUnsavedChanges;
  bool get isReplacing => _isReplacing;

  void _notifyPersistence() {
    if (!_disposed) notifyListeners();
  }

  void beginReplacement() {
    if (_isReplacing || isSaving) throw StateError('Store is busy');
    _isReplacing = true;
    _notifyPersistence();
  }

  void acceptRestoredSnapshot(StudyPlanSnapshot value) {
    if (!_isReplacing) throw StateError('Replacement is not active');
    _install(value);
    _hasLoadError = false;
    _writer.acceptPersisted();
  }

  void endReplacement() {
    _isReplacing = false;
    _notifyPersistence();
  }

  void _checkReplacement() {
    if (_isReplacing) throw StateError('Data replacement is active');
  }

  List<StudyPlan> get plans => List.unmodifiable(_plans);
  List<StudyScheme> get schemes => List.unmodifiable(_schemes);
  Map<int, String?> get weeklyAssignments =>
      Map.unmodifiable(_weeklyAssignments);
  Map<String, String?> get dateOverrides => Map.unmodifiable(_dateOverrides);
  DateTime get studyDate =>
      studyCalendarDate(settings?.studyDate(_now()) ?? _now());
  String get todayKey => studyDayKey(studyDate);
  String? get todaySchemeId => schemeIdOn(studyDate);
  StudyScheme? get todayScheme => schemeById(todaySchemeId);
  List<StudyPlan> get todayPlans => plansForScheme(todaySchemeId);
  int get todayStudiedSeconds =>
      recordsOn(studyDate)
          .fold(0, (sum, record) => sum + record.studiedSeconds);

  StudyScheme? schemeById(String? id) =>
      _schemes.where((scheme) => scheme.id == id).firstOrNull;
  List<StudyPlan> plansForScheme(String? id) =>
      List.unmodifiable(_plans.where((plan) => plan.schemeId == id));
  String? schemeIdOn(DateTime date) {
    final key = studyDayKey(date);
    return _dateOverrides.containsKey(key)
        ? _dateOverrides[key]
        : _weeklyAssignments[date.weekday];
  }

  List<StudyRecord> recordsOn(DateTime date) => List.unmodifiable(
    _records.where((record) => record.date == studyDayKey(date)),
  );
  bool isPlanActive(String id) {
    final plan = planById(id);
    return plan != null && plan.schemeId == todaySchemeId;
  }

  Set<String> takeInvalidatedSessions() {
    final result = Set<String>.of(_invalidatedSessions);
    _invalidatedSessions.clear();
    return result;
  }

  void _validateTarget(String? id) {
    if (id != null && schemeById(id) == null) {
      throw ArgumentError.value(id, 'schemeId');
    }
  }

  StudyScheme addScheme(String name, {String? copyFrom}) {
    _checkReplacement();
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    if (copyFrom != null) _validateTarget(copyFrom);
    final originals = plansForScheme(copyFrom);
    final scheme = StudyScheme(id: 'scheme_${_nextId++}', name: name.trim());
    _schemes.add(scheme);
    for (final plan in originals) {
      _plans.add(
        StudyPlan(
          id: 'custom_${_nextId++}',
          schemeId: scheme.id,
          name: plan.name,
          iconId: plan.iconId,
          plannedSeconds: plan.plannedSeconds,
          customIconPath: plan.customIconPath,
          pauseWhenBackgrounded: plan.pauseWhenBackgrounded,
        ),
      );
    }
    _changed();
    return scheme;
  }

  void renameScheme(String id, String name) {
    _checkReplacement();
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    final index = _schemes.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _schemes[index] = StudyScheme(id: id, name: name.trim());
    _changed();
  }

  void setWeeklyAssignments(Map<int, String?> assignments) {
    _checkReplacement();
    for (final entry in assignments.entries) {
      if (entry.key < 1 || entry.key > 7) {
        throw ArgumentError('Invalid weekday');
      }
      _validateTarget(entry.value);
    }
    _weeklyAssignments.addAll(assignments);
    refreshForToday();
    _changed();
  }

  List<String> _editableDates(Iterable<DateTime> dates) {
    final keys = dates.map(studyDayKey).toSet().toList();
    if (keys.any((key) => key.compareTo(todayKey) < 0)) {
      throw ArgumentError('Past dates are read-only');
    }
    return keys;
  }

  void assignDates(Iterable<DateTime> dates, String? schemeId) {
    _checkReplacement();
    _validateTarget(schemeId);
    final keys = _editableDates(dates);
    for (final key in keys) {
      _dateOverrides[key] = schemeId;
    }
    refreshForToday();
    _changed();
  }

  void restoreWeeklyDates(Iterable<DateTime> dates) {
    _checkReplacement();
    for (final key in _editableDates(dates)) {
      _dateOverrides.remove(key);
    }
    refreshForToday();
    _changed();
  }

  void deleteScheme(String id, {required String? replacementId}) {
    _checkReplacement();
    if (schemeById(id) == null) return;
    if (_schemes.length <= 1 || id == replacementId) {
      throw StateError('Keep at least one scheme');
    }
    _validateTarget(replacementId);
    deletePlans(plansForScheme(id).map((p) => p.id).toSet());
    _schemes.removeWhere((s) => s.id == id);
    for (final day in _weeklyAssignments.keys.toList()) {
      if (_weeklyAssignments[day] == id) {
        _weeklyAssignments[day] = replacementId;
      }
    }
    for (final day in _dateOverrides.keys.toList()) {
      if (_dateOverrides[day] == id) _dateOverrides[day] = replacementId;
    }
    refreshForToday();
    _changed();
  }

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
    if (_isReplacing) return;
    final today = _today;
    var changed = _knownDay != null && _knownDay != today;
    _knownDay = today;
    for (var index = 0; index < _plans.length; index++) {
      var plan = _plans[index];
      if (plan.isRunning &&
          (plan.progressDay != today || plan.schemeId != todaySchemeId)) {
        _invalidatedSessions.add(plan.sessionId!);
        pauseRunning(plan.id);
        plan = _plans[index];
        changed = true;
      }
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

  StudyPlan addPlan({
    required String name,
    required String iconId,
    required int plannedSeconds,
    String? customIconPath,
    String? schemeId,
  }) {
    _checkReplacement();
    refreshForToday();
    final target = schemeId ?? todaySchemeId ?? _schemes.first.id;
    _validateTarget(target);
    final plan = StudyPlan(
      id: 'custom_${_nextId++}',
      schemeId: target,
      name: name,
      iconId: iconId,
      plannedSeconds: plannedSeconds,
      customIconPath: customIconPath,
    );
    _plans.add(plan);
    _changed();
    return plan;
  }

  void updatePlan(StudyPlan updated) {
    _checkReplacement();
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

  void adjustRemainingSeconds(String id, int seconds) {
    _checkReplacement();
    if (seconds <= 0) {
      throw ArgumentError.value(seconds, 'seconds');
    }
    refreshForToday();
    if (!isPlanActive(id)) return;
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
    _checkReplacement();
    for (final plan in List<StudyPlan>.of(
      _plans.where((p) => ids.contains(p.id)),
    )) {
      if (plan.isRunning) {
        _invalidatedSessions.add(plan.sessionId!);
        pauseRunning(plan.id);
      }
      _syncRecord(planById(plan.id)!);
    }
    final oldLength = _plans.length;
    _plans.removeWhere((plan) => ids.contains(plan.id));
    if (_plans.length != oldLength) _changed();
  }

  void restorePlan(StudyPlan plan, {int? index}) {
    _checkReplacement();
    if (schemeById(plan.schemeId) == null) return;
    if (_plans.any((item) => item.id == plan.id)) return;
    final position = index == null
        ? _plans.length
        : index.clamp(0, _plans.length);
    _plans.insert(position, plan);
    _syncRecord(plan);
    refreshForToday();
    _changed();
  }

  void clearLearningData() {
    _checkReplacement();
    for (var index = 0; index < _plans.length; index++) {
      if (_plans[index].sessionId != null) {
        _invalidatedSessions.add(_plans[index].sessionId!);
      }
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
    _checkReplacement();
    for (final plan in _plans) {
      if (plan.sessionId != null) _invalidatedSessions.add(plan.sessionId!);
    }
    _plans.clear();
    _records.clear();
    _nextId = 1;
    _schemes
      ..clear()
      ..add(const StudyScheme.defaultScheme());
    _weeklyAssignments
      ..clear()
      ..addAll({for (var day = 1; day <= 7; day++) day: defaultStudySchemeId});
    _dateOverrides.clear();
    _changed();
  }

  void startOrResume(String id) {
    _checkReplacement();
    refreshForToday();
    if (!isPlanActive(id)) return;
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
    _checkReplacement();
    startOrResume(id);
    if (!isPlanActive(id)) return;
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
    if (_isReplacing) return;
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
    _checkReplacement();
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
    _checkReplacement();
    if (seconds <= 0) return;
    refreshForToday();
    if (!isPlanActive(id)) return;
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
    final key = '${plan.progressDay}_${plan.id}';
    final previousRecord = _records.where((r) => r.id == key).firstOrNull;
    final record = StudyRecord(
      id: '${plan.progressDay}_${plan.id}',
      planId: plan.id,
      date: plan.progressDay!,
      plannedSeconds: plan.plannedSeconds,
      studiedSeconds: plan.studiedSeconds,
      schemeId: plan.schemeId,
      schemeName: previousRecord?.schemeName ?? schemeById(plan.schemeId)?.name,
      planName: previousRecord?.planName ?? plan.name,
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
    if (_hasLoadError || _isReplacing) return;
    _writer.enqueue(snapshot.encode());
  }

  Future<bool> flush() async => !_hasLoadError && await _writer.flush();
  Future<bool> retrySave() async => !_hasLoadError && await _writer.retry();
  @override
  void dispose() {
    _disposed = true;
    _writer.dispose();
    settings?.removeListener(refreshForToday);
    super.dispose();
  }
}
