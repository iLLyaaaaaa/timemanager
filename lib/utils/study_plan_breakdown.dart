import '../models/study_plan.dart';

class StudyPlanTime {
  const StudyPlanTime({
    required this.id,
    required this.name,
    required this.seconds,
  });

  final String id;
  final String name;
  final int seconds;
}

// Resolve names at display time, preserving time from removed plans as one row.
List<StudyPlanTime> studyPlanTimes({
  required Map<String, int> secondsByPlan,
  required Iterable<StudyPlan> plans,
  required String Function(int) deletedPlansLabel,
}) {
  final names = {for (final plan in plans) plan.id: plan.name};
  final entries = <StudyPlanTime>[];
  var deletedSeconds = 0;
  var deletedCount = 0;
  for (final entry in secondsByPlan.entries) {
    if (entry.value <= 0) continue;
    final name = names[entry.key];
    if (name == null) {
      deletedSeconds += entry.value;
      deletedCount++;
    } else {
      entries.add(
        StudyPlanTime(id: entry.key, name: name, seconds: entry.value),
      );
    }
  }
  if (deletedCount > 0) {
    entries.add(
      StudyPlanTime(
        id: '',
        name: deletedPlansLabel(deletedCount),
        seconds: deletedSeconds,
      ),
    );
  }
  entries.sort((a, b) {
    final time = b.seconds.compareTo(a.seconds);
    return time == 0 ? a.id.compareTo(b.id) : time;
  });
  return List.unmodifiable(entries);
}
