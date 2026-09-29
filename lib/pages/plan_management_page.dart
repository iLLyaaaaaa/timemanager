import 'package:flutter/material.dart';

import 'dart:async';

import '../l10n/app_localizations.dart';

import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import 'plan_edit_page.dart';
import '../widgets/study_plan_icon.dart';
import '../services/local_media_store.dart';
import '../services/timer_alert_service.dart';

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
  final _media = LocalMediaStore();
  final _alerts = TimerAlertService();

  Future<void> _removeUnusedIcons(Iterable<String?> paths) async {
    for (final path in paths.toSet()) {
      if (path != null &&
          !widget.store.plans.any((plan) => plan.customIconPath == path)) {
        await _media.deleteIfManaged(path, 'custom_icons');
      }
    }
  }

  Future<void> _restoreDeletedPlan(StudyPlan plan, int index) async {
    widget.store.restorePlan(plan, index: index);
    if (!mounted || !plan.isRunning || plan.sessionId == null) return;
    await _alerts.scheduleBackgroundCompletion(
      plan: plan,
      settings: _settings.settings,
      l10n: AppLocalizations.of(context)!,
    );
  }

  @override
  void dispose() {
    unawaited(_alerts.dispose());
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
        title: Text(AppLocalizations.of(context)!.bulkDeleteTitle),
        content: Text(
          AppLocalizations.of(context)!.bulkDeleteConfirm(ids.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final removedPlans = widget.store.plans
        .where((plan) => ids.contains(plan.id))
        .toList();
    final removedIcons = removedPlans
        .map((plan) => plan.customIconPath)
        .toList();
    widget.store.deletePlans(ids);
    for (final plan in removedPlans) {
      if (plan.sessionId != null) {
        await _alerts.cancelBackgroundCompletion(plan.sessionId!);
      }
    }
    setState(() {
      _bulkMode = false;
      _selectedIds.clear();
    });
    final saved = await widget.store.flush();
    if (saved) await _removeUnusedIcons(removedIcons);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.deleteSaveFailed)),
      );
    }
  }

  Future<void> _setBackgroundPause(StudyPlan plan, bool enabled) async {
    widget.store.updatePlan(plan.copyWith(pauseWhenBackgrounded: enabled));
    if (!await widget.store.flush() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.timerSettingSaveFailed),
        ),
      );
    }
  }

  Future<void> _deletePlan(StudyPlan plan) async {
    final confirmFirst = _settings.settings.confirmBeforeDelete;
    if (confirmFirst) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.deletePlanTitle),
          content: Text(
            AppLocalizations.of(context)!.deletePlanConfirm(plan.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppLocalizations.of(context)!.delete),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final index = widget.store.plans.indexWhere((item) => item.id == plan.id);
    widget.store.deletePlan(plan.id);
    if (plan.sessionId != null) {
      await _alerts.cancelBackgroundCompletion(plan.sessionId!);
    }
    if (!confirmFirst && mounted) {
      final controller = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.deletedPlan(plan.name)),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.undo,
            onPressed: () => unawaited(_restoreDeletedPlan(plan, index)),
          ),
        ),
      );
      unawaited(
        controller.closed.then((_) async {
          if (await widget.store.flush()) {
            await _removeUnusedIcons([plan.customIconPath]);
          }
        }),
      );
    } else if (await widget.store.flush()) {
      await _removeUnusedIcons([plan.customIconPath]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.planManagement),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _toggleBulkMode,
            child: Text(
              _bulkMode
                  ? AppLocalizations.of(context)!.done
                  : AppLocalizations.of(context)!.bulkManage,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final plans = widget.store.plans;
          if (plans.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context)!.noPlansManage),
            );
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
                            StudyPlanIcon(plan: plan, color: colors.primary),
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
                                  AppLocalizations.of(context)!.dailyPlanValue(
                                    formatStudyDuration(plan.plannedSeconds),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_bulkMode) ...[
                            IconButton(
                              onPressed: () => _openEditor(plan),
                              tooltip: AppLocalizations.of(context)!
                                  .editPlanTooltip(plan.name),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () => _deletePlan(plan),
                              tooltip: AppLocalizations.of(context)!
                                  .deletePlanTooltip(plan.name),
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
                          title: Text(
                            AppLocalizations.of(context)!.backgroundPause,
                          ),
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
              label: Text(AppLocalizations.of(context)!.addPlan),
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
                            ? AppLocalizations.of(context)!.deselectAll
                            : AppLocalizations.of(context)!.selectAll,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        AppLocalizations.of(context)!
                            .deleteSelected(_selectedIds.length),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
