import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/study_icon_catalog.dart';

class StudyIconPicker extends StatelessWidget {
  const StudyIconPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = studyIconFor(selectedId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.chooseIcon,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(selected.icon, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.currentIcon(
                  localizedStudyIconLabel(
                    AppLocalizations.of(context)!,
                    selectedId,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: studyIconOptions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final option = studyIconOptions[index];
            final isSelected = option.id == selectedId;
            return Tooltip(
              message: localizedStudyIconLabel(
                AppLocalizations.of(context)!,
                option.id,
              ),
              child: Material(
                color: isSelected ? colors.primaryContainer : colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey('icon_option_${option.id}'),
                  onTap: () => onSelected(option.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(
                    option.icon,
                    color: isSelected
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
