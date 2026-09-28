class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.name,
    required this.iconId,
    required this.plannedMinutes,
    this.progressDay,
    this.remainingSeconds = 0,
    this.studiedSeconds = 0,
    this.hasStartedToday = false,
    this.isCompletedToday = false,
  });

  final String id;
  final String name;
  final String iconId;
  final int plannedMinutes;
  final String? progressDay;
  final int remainingSeconds;
  final int studiedSeconds;
  final bool hasStartedToday;
  final bool isCompletedToday;

  StudyPlan copyWith({String? name, String? iconId, int? plannedMinutes}) {
    return StudyPlan(
      id: id,
      name: name ?? this.name,
      iconId: iconId ?? this.iconId,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      progressDay: progressDay,
      remainingSeconds: remainingSeconds,
      studiedSeconds: studiedSeconds,
      hasStartedToday: hasStartedToday,
      isCompletedToday: isCompletedToday,
    );
  }

  StudyPlan withProgress({
    required String? day,
    required int remainingSeconds,
    required int studiedSeconds,
    required bool hasStartedToday,
    required bool isCompletedToday,
  }) {
    return StudyPlan(
      id: id,
      name: name,
      iconId: iconId,
      plannedMinutes: plannedMinutes,
      progressDay: day,
      remainingSeconds: remainingSeconds,
      studiedSeconds: studiedSeconds,
      hasStartedToday: hasStartedToday,
      isCompletedToday: isCompletedToday,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'iconId': iconId,
    'plannedMinutes': plannedMinutes,
    'progressDay': progressDay,
    'remainingSeconds': remainingSeconds,
    'studiedSeconds': studiedSeconds,
    'hasStartedToday': hasStartedToday,
    'isCompletedToday': isCompletedToday,
  };

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final iconId = json['iconId'];
    final minutes = json['plannedMinutes'];
    final storedRemainingSeconds = json['remainingSeconds'];
    final storedStudiedSeconds = json['studiedSeconds'];
    if (id is! String ||
        name is! String ||
        iconId is! String ||
        minutes is! int ||
        minutes <= 0) {
      throw const FormatException('Invalid study plan');
    }
    return StudyPlan(
      id: id,
      name: name,
      iconId: iconId,
      plannedMinutes: minutes,
      progressDay: json['progressDay'] is String
          ? json['progressDay'] as String
          : null,
      remainingSeconds:
          storedRemainingSeconds is int && storedRemainingSeconds >= 0
          ? storedRemainingSeconds
          : 0,
      studiedSeconds: storedStudiedSeconds is int && storedStudiedSeconds >= 0
          ? storedStudiedSeconds
          : 0,
      hasStartedToday: json['hasStartedToday'] == true,
      isCompletedToday: json['isCompletedToday'] == true,
    );
  }
}
