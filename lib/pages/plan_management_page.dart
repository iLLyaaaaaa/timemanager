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
  bool _bulkMode = false;
  final Set<String> _selectedIds = {};

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

  void _toggleBulkMode() {
    setState(() {
      _bulkMode = !_bulkMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _toggleAll(List<StudyPlan> plans) {
    final ids = plans.map((plan) => plan.id).toSet();
    setState(() {
      if (_selectedIds.containsAll(ids)) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = widget.store.plans
        .where((plan) => _selectedIds.contains(plan.id))
        .map((plan) => plan.id)
        .toSet();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('批量删除计划？'),
        content: Text('确定删除已选择的 ${ids.length} 个计划吗？'),
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
    widget.store.deletePlans(ids);
    setState(() {
      _bulkMode = false;
      _selectedIds.clear();
    });
    if (!await widget.store.flush() && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('删除结果暂未写入本地，请稍后重试')));
    }
  }

  Future<void> _setBackgroundPause(StudyPlan plan, bool enabled) async {
    widget.store.updatePlan(plan.copyWith(pauseWhenBackgrounded: enabled));
    if (!await widget.store.flush() && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('计时设置暂未写入本地，请稍后重试')));
    }
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
        actions: [
          TextButton(
            onPressed: _toggleBulkMode,
            child: Text(_bulkMode ? '完成' : '批量管理'),
          ),
          const SizedBox(width: 8),
        ],
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
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (_bulkMode)
                            Checkbox(
                              key: ValueKey('select_plan_${plan.id}'),
                              value: _selectedIds.contains(plan.id),
                              onChanged: (_) => _toggleSelection(plan.id),
                            )
                          else
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '每日计划 ${formatStudyDuration(plan.plannedSeconds)}',
                                ),
                              ],
                            ),
                          ),
                          if (!_bulkMode) ...[
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
                        ],
                      ),
                      if (!_bulkMode) ...[
                        const Divider(height: 16),
                        SwitchListTile(
                          key: ValueKey('background_pause_${plan.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('后台自动暂停'),
                          value: plan.pauseWhenBackgrounded,
                          onChanged: (value) =>
                              _setBackgroundPause(plan, value),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _bulkMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('新增计划'),
            ),
      bottomNavigationBar: _bulkMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => _toggleAll(widget.store.plans),
                      child: Text(
                        _selectedIds.length == widget.store.plans.length
                            ? '取消全选'
                            : '全选',
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text('删除选中 (${_selectedIds.length})'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
