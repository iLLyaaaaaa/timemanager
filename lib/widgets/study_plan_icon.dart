import 'dart:io';

import 'package:flutter/material.dart';

import '../data/study_icon_catalog.dart';
import '../models/study_plan.dart';

class StudyPlanIcon extends StatelessWidget {
  const StudyPlanIcon({
    super.key,
    required this.plan,
    this.size = 32,
    this.color,
  });

  final StudyPlan plan;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
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
