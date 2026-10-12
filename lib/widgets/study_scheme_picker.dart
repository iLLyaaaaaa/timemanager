import 'package:flutter/material.dart';

import '../data/study_plan_store.dart';
import '../l10n/app_localizations.dart';
import '../models/study_scheme.dart';
import '../models/study_record.dart';

String studySchemeName(BuildContext context, StudyScheme? scheme) {
  final l10n = AppLocalizations.of(context)!;
  if (scheme == null) return l10n.restDay;
  return scheme.name.isEmpty ? l10n.defaultScheme : scheme.name;
}

Color studySchemeColor(BuildContext context, String? id) {
  if (id == null) return Theme.of(context).colorScheme.outline;
  const colors = [
    Colors.teal,
    Colors.indigo,
    Colors.deepOrange,
    Colors.purple,
    Colors.blue,
    Colors.green,
  ];
  final hash = id.codeUnits.fold(0, (value, unit) => value * 31 + unit);
  return colors[hash.abs() % colors.length];
}

String studyRecordSchemeName(
  BuildContext context,
  StudyPlanStore store,
  StudyRecord record,
) {
  if (record.schemeName?.isNotEmpty == true) return record.schemeName!;
  if (record.schemeName == '' && record.schemeId == defaultStudySchemeId) {
    return AppLocalizations.of(context)!.defaultScheme;
  }
  final id =
      record.schemeId ??
      store.planById(record.planId)?.schemeId ??
      defaultStudySchemeId;
  final scheme = store.schemeById(id);
  if (scheme != null) return studySchemeName(context, scheme);
  return AppLocalizations.of(context)!.defaultScheme;
}

class SchemeSelection {
  const SchemeSelection(this.schemeId);
  final String? schemeId;
}

Future<SchemeSelection?> showStudySchemePicker(
  BuildContext context,
  StudyPlanStore store, {
  required String title,
  String? currentId,
  String? excludeId,
}) => showModalBottomSheet<SchemeSelection>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .75,
    ),
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        for (final scheme in <StudyScheme?>[
          null,
          ...store.schemes.where((s) => s.id != excludeId),
        ])
          ListTile(
            key: ValueKey('pick_scheme_${scheme?.id ?? 'rest'}'),
            selected: scheme?.id == currentId,
            leading: Icon(
              scheme == null
                  ? Icons.free_breakfast_outlined
                  : Icons.layers_outlined,
              color: studySchemeColor(context, scheme?.id),
            ),
            title: Text(studySchemeName(context, scheme)),
            trailing: scheme?.id == currentId ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, SchemeSelection(scheme?.id)),
          ),
      ],
    ),
  ),
);
