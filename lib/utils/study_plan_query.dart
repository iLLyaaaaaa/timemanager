import '../models/study_plan.dart';

enum StudyPlanFilter { all, notStarted, inProgress, completed }

List<StudyPlan> filterStudyPlans(
  List<StudyPlan> plans, {
  String query = '',
  StudyPlanFilter filter = StudyPlanFilter.all,
}) {
  final nameQuery = query.trim().toLowerCase();
  return plans.where((plan) {
    if (!plan.name.toLowerCase().contains(nameQuery)) return false;
    return switch (filter) {
      StudyPlanFilter.all => true,
      StudyPlanFilter.notStarted =>
        !plan.hasStartedToday && !plan.isCompletedToday,
      StudyPlanFilter.inProgress =>
        plan.hasStartedToday && !plan.isCompletedToday,
      StudyPlanFilter.completed => plan.isCompletedToday,
    };
  }).toList();
}

StudyPlan? planToContinue(List<StudyPlan> plans) {
  for (final plan in plans) {
    if (plan.isRunning && !plan.isCompletedToday) return plan;
  }
  for (final plan in plans) {
    if (plan.hasStartedToday && !plan.isCompletedToday) return plan;
  }
  return null;
}
