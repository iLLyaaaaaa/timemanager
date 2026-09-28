import 'package:flutter/material.dart';

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
        Row(
          children: [
            Text('选择图标', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text('当前：${selected.label}'),
            const SizedBox(width: 8),
            Icon(selected.icon, color: colors.primary),
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
              message: option.label,
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
