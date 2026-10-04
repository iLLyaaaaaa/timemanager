import 'package:flutter/material.dart';

import '../models/study_plan.dart';
import 'study_plan_icon.dart';

/// Keeps plan images fixed while giving text room at narrow widths or large type.
class StudyPlanLayout extends StatelessWidget {
  const StudyPlanLayout({
    super.key,
    required this.plan,
    required this.contentBuilder,
    this.iconKey,
  });

  final StudyPlan plan;
  final Widget Function(BuildContext context, bool stacked) contentBuilder;
  final Key? iconKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final stacked =
          constraints.maxWidth < StudyPlanIcon.cardTileSize + 12 + 176 * scale;
      final icon = StudyPlanIcon(
        key: iconKey,
        plan: plan,
        tileSize: StudyPlanIcon.cardTileSize,
        color: Theme.of(context).colorScheme.primary,
      );
      final content = contentBuilder(context, stacked);
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: icon),
            const SizedBox(height: 16),
            content,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(child: content),
        ],
      );
    },
  );
}

class StudyPlanTitle extends StatelessWidget {
  const StudyPlanTitle({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Text(
    name,
    semanticsLabel: name,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.titleLarge,
  );
}
