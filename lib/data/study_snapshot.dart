import 'dart:convert';

import '../models/app_settings.dart';
import '../models/study_plan.dart';
import '../models/study_record.dart';
import '../models/study_scheme.dart';
import '../utils/study_history.dart';

class SnapshotVersionException extends FormatException {
  const SnapshotVersionException() : super('Unsupported snapshot version');
}

class StudyPlanSnapshot {
  StudyPlanSnapshot({
    required Iterable<StudyPlan> plans,
    required Iterable<StudyRecord> records,
    required this.nextId,
    this.sourceVersion = 6,
    Iterable<StudyScheme> schemes = const [StudyScheme.defaultScheme()],
    Map<int, String?>? weeklyAssignments,
    Map<String, String?> dateOverrides = const {},
  }) : plans = List.unmodifiable(plans),
       records = List.unmodifiable(records),
       schemes = List.unmodifiable(schemes),
       weeklyAssignments = Map.unmodifiable(
         weeklyAssignments ??
             {for (var day = 1; day <= 7; day++) day: defaultStudySchemeId},
       ),
       dateOverrides = Map.unmodifiable(dateOverrides);

  final List<StudyPlan> plans;
  final List<StudyRecord> records;
  final int nextId;
  final int sourceVersion;
  final List<StudyScheme> schemes;
  // A null target is an explicit rest day. An absent override uses the week.
  final Map<int, String?> weeklyAssignments;
  final Map<String, String?> dateOverrides;

  factory StudyPlanSnapshot.decode(String? raw) {
    if (raw == null) {
      return StudyPlanSnapshot(plans: [], records: [], nextId: 1);
    }
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic> &&
          value['version'] is int &&
          !const [1, 2, 3, 4, 5, 6].contains(value['version'])) {
        throw const SnapshotVersionException();
      }
      if (value is! Map<String, dynamic> ||
          !const [1, 2, 3, 4, 5, 6].contains(value['version']) ||
          value['plans'] is! List ||
          (value['version'] != 1 && value['records'] is! List)) {
        throw const FormatException('Invalid saved plans');
      }
      final plans = (value['plans'] as List)
          .map(
            (item) =>
                StudyPlan.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      var records = value['version'] == 1
          ? <StudyRecord>[]
          : (value['records'] as List)
                .map(
                  (item) => StudyRecord.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();
      if (value['version'] != 6) {
        final names = {for (final p in plans) p.id: p.name};
        records = records
            .map(
              (r) => StudyRecord(
                id: r.id,
                planId: r.planId,
                date: r.date,
                plannedSeconds: r.plannedSeconds,
                studiedSeconds: r.studiedSeconds,
                schemeId: defaultStudySchemeId,
                schemeName: '',
                planName: names[r.planId],
              ),
            )
            .toList();
      }
      final schemes = value['version'] == 6
          ? (value['schemes'] as List)
                .map(
                  (item) => StudyScheme.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList()
          : const [StudyScheme.defaultScheme()];
      final weekly = value['version'] == 6
          ? Map<String, dynamic>.from(value['weeklyAssignments'] as Map)
          : {for (var day = 1; day <= 7; day++) '$day': defaultStudySchemeId};
      final overrides = value['version'] == 6
          ? Map<String, dynamic>.from(value['dateOverrides'] as Map)
          : <String, dynamic>{};
      final schemeIds = schemes.map((s) => s.id).toSet();
      bool validTarget(Object? target) =>
          target == null || (target is String && schemeIds.contains(target));
      bool validDay(String key) {
        final date = DateTime.tryParse(key);
        return date != null && studyDayKey(date) == key;
      }

      if (schemes.isEmpty ||
          schemeIds.length != schemes.length ||
          plans.any((p) => !schemeIds.contains(p.schemeId)) ||
          (value['version'] == 6 &&
              (value['plans'] as List).any(
                (p) => (p as Map)['schemeId'] is! String,
              )) ||
          weekly.length != 7 ||
          List.generate(
            7,
            (i) => '${i + 1}',
          ).any((key) => !weekly.containsKey(key)) ||
          weekly.values.any((target) => !validTarget(target)) ||
          overrides.entries.any(
            (e) => !validDay(e.key) || !validTarget(e.value),
          )) {
        throw const FormatException('Invalid study schedule');
      }
      if (plans.any((p) => p.id.isEmpty || p.name.trim().isEmpty) ||
          plans.map((p) => p.id).toSet().length != plans.length ||
          records.any((r) => r.id.isEmpty || r.planId.isEmpty) ||
          records.map((r) => r.id).toSet().length != records.length) {
        throw const FormatException('Invalid or duplicate IDs');
      }
      var nextId = value['nextId'] is int && (value['nextId'] as int) > 0
          ? value['nextId'] as int
          : 1;
      // Deleted plans still own their history; never reuse their IDs.
      final ids = {
        ...plans.map((p) => p.id),
        ...records.map((r) => r.planId),
        ...schemeIds,
        ...records.map((r) => r.schemeId).whereType<String>(),
      };
      for (final id in ids) {
        final match = RegExp(r'^(?:custom|scheme)_([0-9]+)$').firstMatch(id);
        final number = match == null ? null : int.tryParse(match.group(1)!);
        if (number != null && number >= nextId) nextId = number + 1;
      }
      return StudyPlanSnapshot(
        plans: plans,
        records: records,
        nextId: nextId,
        sourceVersion: value['version'] as int,
        schemes: schemes,
        weeklyAssignments: {
          for (final e in weekly.entries) int.parse(e.key): e.value as String?,
        },
        dateOverrides: {
          for (final e in overrides.entries) e.key: e.value as String?,
        },
      );
    } on TypeError {
      throw const FormatException('Invalid saved plans');
    } on ArgumentError {
      throw const FormatException('Invalid saved plans');
    }
  }

  Map<String, Object?> toJson() => {
    'version': 6,
    'nextId': nextId,
    'plans': plans.map((p) => p.toJson()).toList(),
    'records': records.map((r) => r.toJson()).toList(),
    'schemes': schemes.map((s) => s.toJson()).toList(),
    'weeklyAssignments': {
      for (final e in weeklyAssignments.entries) '${e.key}': e.value,
    },
    'dateOverrides': dateOverrides,
  };
  String encode() => jsonEncode(toJson());

  /// Copy at one instant; the live store and running sessions are untouched.
  StudyPlanSnapshot pausedAt(
    DateTime now, {
    AppSettings? settings,
    bool resetDay = false,
  }) {
    final history = {for (final record in records) record.id: record};
    final reset = settings ?? const AppSettings();
    final beforeReset =
        now.hour * 60 + now.minute <
        reset.dailyResetHour * 60 + reset.dailyResetMinute;
    final today = studyDayKey(
      DateTime(now.year, now.month, now.day - (beforeReset ? 1 : 0)),
    );
    final copied = plans.map((plan) {
      var remaining = plan.remainingSeconds;
      var studied = plan.studiedSeconds;
      if (plan.isRunning) {
        final consumed = now
            .difference(plan.startedAt!)
            .inSeconds
            .clamp(0, plan.sessionStartRemainingSeconds!);
        remaining = plan.sessionStartRemainingSeconds! - consumed;
        studied = plan.sessionStartStudiedSeconds! + consumed;
      }
      var copy = plan.withProgress(
        day: plan.progressDay,
        remainingSeconds: remaining,
        studiedSeconds: studied,
        hasStartedToday: plan.hasStartedToday,
        isCompletedToday: plan.hasStartedToday && remaining == 0,
        clearRunning: true,
      );
      if (copy.hasStartedToday && copy.progressDay != null) {
        final record = StudyRecord(
          id: '${copy.progressDay}_${copy.id}',
          planId: copy.id,
          date: copy.progressDay!,
          plannedSeconds: copy.plannedSeconds,
          studiedSeconds: copy.studiedSeconds,
          schemeId: copy.schemeId,
          schemeName:
              history['${copy.progressDay}_${copy.id}']?.schemeName ??
              schemes.where((s) => s.id == copy.schemeId).firstOrNull?.name,
          planName:
              history['${copy.progressDay}_${copy.id}']?.planName ?? copy.name,
        );
        history[record.id] = record;
      }
      if (resetDay && copy.hasStartedToday && copy.progressDay != today) {
        copy = copy.withProgress(
          day: null,
          remainingSeconds: 0,
          studiedSeconds: 0,
          hasStartedToday: false,
          isCompletedToday: false,
          clearRunning: true,
        );
      }
      return copy;
    }).toList();
    return StudyPlanSnapshot(
      plans: copied,
      records: history.values,
      nextId: nextId,
      schemes: schemes,
      weeklyAssignments: weeklyAssignments,
      dateOverrides: dateOverrides,
    );
  }
}

AppSettings decodeSettingsSnapshot(String? raw) {
  if (raw == null) return const AppSettings();
  try {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid settings');
    }
    if (value['version'] is int &&
        !const [2, 3, 4].contains(value['version'])) {
      throw const SnapshotVersionException();
    }
    return AppSettings.fromJson(value);
  } on TypeError {
    throw const FormatException('Invalid settings');
  }
}
