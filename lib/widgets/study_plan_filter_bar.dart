import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/study_plan.dart';
import '../utils/study_plan_query.dart';
import 'app_section_card.dart';

class StudyPlanFilterBar extends StatelessWidget {
  const StudyPlanFilterBar({
    super.key,
    required this.plans,
    required this.controller,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  final List<StudyPlan> plans;
  final TextEditingController controller;
  final StudyPlanFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<StudyPlanFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('plan_search'),
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: onQueryChanged,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: l10n.searchPlans,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('clear_plan_search'),
                    tooltip: l10n.clearSearch,
                    onPressed: () {
                      controller.clear();
                      onQueryChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in StudyPlanFilter.values)
              ChoiceChip(
                key: ValueKey('plan_filter_${option.name}'),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                label: Text(
                  l10n.planFilterCount(
                    switch (option) {
                      StudyPlanFilter.all => l10n.filterAllPlans,
                      StudyPlanFilter.notStarted => l10n.filterNotStarted,
                      StudyPlanFilter.inProgress => l10n.filterInProgress,
                      StudyPlanFilter.completed => l10n.filterCompleted,
                    },
                    filterStudyPlans(
                      plans,
                      query: controller.text,
                      filter: option,
                    ).length,
                  ),
                ),
                selected: option == filter,
                onSelected: (_) {
                  FocusScope.of(context).unfocus();
                  onFilterChanged(option);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class StudyPlanSearchEmpty extends StatelessWidget {
  const StudyPlanSearchEmpty({super.key, required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSectionCard(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(l10n.noMatchingPlans, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('reset_plan_filters'),
              onPressed: () {
                FocusScope.of(context).unfocus();
                onReset();
              },
              child: Text(l10n.resetPlanFilters),
            ),
          ],
        ),
      ),
    );
  }
}
