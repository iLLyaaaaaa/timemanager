class StudyRecord {
  const StudyRecord({
    required this.id,
    required this.planId,
    required this.date,
    required this.plannedSeconds,
    required this.studiedSeconds,
    this.schemeId,
    this.schemeName,
    this.planName,
  });

  final String id;
  final String planId;
  final String date;
  final int plannedSeconds;
  final int studiedSeconds;
  final String? schemeId;
  final String? schemeName;
  final String? planName;

  Map<String, Object?> toJson() => {
    'id': id,
    'planId': planId,
    'date': date,
    'plannedSeconds': plannedSeconds,
    'studiedSeconds': studiedSeconds,
    'schemeId': schemeId,
    'schemeName': schemeName,
    'planName': planName,
  };

  factory StudyRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final planId = json['planId'];
    final date = json['date'];
    final plannedSeconds = json['plannedSeconds'];
    final studiedSeconds = json['studiedSeconds'];
    if (id is! String ||
        planId is! String ||
        date is! String ||
        plannedSeconds is! int ||
        plannedSeconds <= 0 ||
        studiedSeconds is! int ||
        studiedSeconds < 0) {
      throw const FormatException('Invalid study record');
    }
    return StudyRecord(
      id: id,
      planId: planId,
      date: date,
      plannedSeconds: plannedSeconds,
      studiedSeconds: studiedSeconds,
      schemeId: json['schemeId'] as String?,
      schemeName: json['schemeName'] as String?,
      planName: json['planName'] as String?,
    );
  }
}
