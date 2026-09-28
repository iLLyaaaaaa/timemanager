import 'package:flutter/material.dart';

import '../data/study_icon_catalog.dart';
import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import 'plan_edit_page.dart';

class PlanManagementPage extends StatefulWidget {
  const PlanManagementPage({super.key, required this.store, this.settings});

  final StudyPlanStore store;
  final SettingsStore? settings;

  @override
  State<PlanManagementPage> createState() => _PlanManagementPageState();
}

class _PlanManagementPageState extends State<PlanManagementPage> {
  late final SettingsStore _settings = widget.settings ?? SettingsStore();

  @override
  void dispose() {
    if (widget.settings == null) _settings.dispose();
    super.dispose();
  }

  void _openEditor([StudyPlan? plan]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlanEditPage(store: widget.store, settings: _settings, plan: plan),
      ),
    );
  }

  Future<void> _deletePlan(StudyPlan plan) async {
    final confirmFirst = _settings.settings.confirmBeforeDelete;
    if (confirmFirst) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('删除计划？'),
          content: Text('确定删除“${plan.name}”计划吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final index = widget.store.plans.indexWhere((item) => item.id == plan.id);
    widget.store.deletePlan(plan.id);
    if (!confirmFirst && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除“${plan.name}”计划'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => widget.store.restorePlan(plan, index: index),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划管理'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final plans = widget.store.plans;
          if (plans.isEmpty) {
            return const Center(child: Text('还没有计划，点击“新增计划”开始吧。'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: plans.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Card(
                key: ValueKey('manage_plan_${plan.id}'),
                margin: EdgeInsets.zero,
                elevation: 0,
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      Icon(
                        studyIconFor(plan.iconId).icon,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '每日计划 ${formatStudyDuration(plan.plannedSeconds)}',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openEditor(plan),
                        tooltip: '编辑${plan.name}计划',
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => _deletePlan(plan),
                        tooltip: '删除${plan.name}计划',
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增计划'),
      ),
    );
  }
}
