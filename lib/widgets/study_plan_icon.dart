import 'dart:io';

import 'package:flutter/material.dart';

import '../data/study_icon_catalog.dart';
import '../models/study_plan.dart';
import '../theme/app_theme.dart';

class StudyPlanIcon extends StatelessWidget {
  static const double cardTileSize = 112;

  const StudyPlanIcon({
    super.key,
    required this.plan,
    this.size = 32,
    this.tileSize,
    this.color,
  });

  final StudyPlan plan;
  final double size;
  final double? tileSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tile = tileSize;
    if (tile != null) {
      final colors = Theme.of(context).colorScheme;
      final fallback = ColoredBox(
        color: colors.primaryContainer,
        child: Center(
          child: Icon(
            studyIconFor(plan.iconId).icon,
            size: tile * 0.48,
            color: color ?? colors.onPrimaryContainer,
          ),
        ),
      );
      final path = plan.customIconPath;
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.imageRadius),
        child: SizedBox.square(
          dimension: tile,
          child: path == null || path.isEmpty
              ? fallback
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      );
    }
    final fallback = Icon(
      studyIconFor(plan.iconId).icon,
      size: size,
      color: color,
    );
    final path = plan.customIconPath;
    if (path == null || path.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.23),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
