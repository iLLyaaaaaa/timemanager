const defaultStudySchemeId = 'scheme_default';

class StudyScheme {
  const StudyScheme({required this.id, required this.name});

  const StudyScheme.defaultScheme() : id = defaultStudySchemeId, name = '';

  final String id;
  // An empty name is reserved for the localized built-in default scheme.
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory StudyScheme.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        (name.trim().isEmpty && id != defaultStudySchemeId)) {
      throw const FormatException('Invalid study scheme');
    }
    return StudyScheme(id: id, name: name);
  }
}
