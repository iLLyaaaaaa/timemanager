import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.highlighted = false,
    this.padding = const EdgeInsets.all(AppTheme.pagePadding),
  });

  final Widget child;
  final bool highlighted;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: highlighted ? colors.primaryContainer : colors.surface,
      shape: AppTheme.cardShape(colors),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppMetric extends StatelessWidget {
  const AppMetric({
    super.key,
    required this.label,
    required this.value,
    this.foreground,
    this.valueKey,
  });

  final String label;
  final String value;
  final Color? foreground;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: foreground ?? colors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            key: valueKey,
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFeatures: AppTheme.durationFeatures,
              color: foreground ?? colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class AppMetricGrid extends StatelessWidget {
  const AppMetricGrid({super.key, required this.children});

  final List<AppMetric> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 360 ? 3 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (var index = 0; index < children.length; index++)
            SizedBox(
              width:
                  index == children.length - 1 && children.length % columns == 1
                  ? constraints.maxWidth
                  : width,
              child: children[index],
            ),
        ],
      );
    },
  );
}
