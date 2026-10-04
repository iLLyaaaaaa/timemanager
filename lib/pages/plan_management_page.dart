import 'package:flutter/material.dart';

import 'dart:async';

import '../l10n/app_localizations.dart';

import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../utils/study_duration.dart';
import '../utils/study_plan_query.dart';
import '../widgets/study_plan_filter_bar.dart';
import 'plan_edit_page.dart';
import '../widgets/study_plan_layout.dart';
import '../widgets/app_section_card.dart';
import '../services/local_media_store.dart';
import '../services/timer_alert_service.dart';
import '../theme/app_theme.dart';

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
  final _searchController = TextEditingController();
  StudyPlanFilter _filter = StudyPlanFilter.all;
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
    _searchController.dispose();
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
    FocusScope.of(context).unfocus();
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

  Future<void> _setBackgroundPause(StudyPlan plan, bool enabled) async {
    widget.store.updatePlan(plan.copyWith(pauseWhenBackgrounded: enabled));
    if (!await widget.store.flush() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.settingsSaveFailed),
        ),
      );
    }
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

  Widget _planCard(BuildContext context, StudyPlan plan) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Card(
      key: ValueKey('manage_plan_${plan.id}'),
      color: colors.surface,
      shape: AppTheme.cardShape(colors),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StudyPlanLayout(
              plan: plan,
              iconKey: ValueKey('manage_icon_${plan.id}'),
              contentBuilder: (context, stacked) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StudyPlanTitle(name: plan.name),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dailyPlanValue(
                      formatStudyDuration(plan.plannedSeconds),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                      fontFeatures: AppTheme.durationFeatures,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _bulkMode
                        ? Semantics(
                            label: plan.name,
                            child: Checkbox(
                              key: ValueKey('select_plan_${plan.id}'),
                              value: _selectedIds.contains(plan.id),
                              onChanged: (_) => _toggleSelection(plan.id),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _openEditor(plan),
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                tooltip: l10n.editPlanTooltip(plan.name),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _deletePlan(plan),
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                tooltip: l10n.deletePlanTooltip(plan.name),
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: colors.error,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            if (!_bulkMode) ...[
              const Divider(height: 20),
              SwitchListTile(
                key: ValueKey('background_pause_${plan.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.backgroundPause,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                value: plan.pauseWhenBackgrounded,
                onChanged: (value) => _setBackgroundPause(plan, value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact =
        MediaQuery.sizeOf(context).width < 390 ||
        MediaQuery.textScalerOf(context).scale(20) > 24;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.planManagement,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (compact)
            IconButton(
              key: const ValueKey('toggle_bulk_mode'),
              onPressed: _toggleBulkMode,
              tooltip: _bulkMode ? l10n.done : l10n.bulkManage,
              icon: Icon(
                _bulkMode ? Icons.check_rounded : Icons.checklist_rounded,
              ),
            )
          else
            TextButton(
              key: const ValueKey('toggle_bulk_mode'),
              onPressed: _toggleBulkMode,
              child: Text(_bulkMode ? l10n.done : l10n.bulkManage),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final plans = widget.store.plans;
          if (plans.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppTheme.pagePadding),
              children: [
                AppSectionCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.library_add_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.noPlansManage, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const ValueKey('management_empty_add'),
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.addPlan),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          // Bulk selection always uses the full list, including select-all.
          final visiblePlans = _bulkMode
              ? plans
              : filterStudyPlans(
                  plans,
                  query: _searchController.text,
                  filter: _filter,
                );
          return ListView.builder(
            key: const PageStorageKey('management_scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              16,
              AppTheme.pagePadding,
              compact ? 24 : 96,
            ),
            itemCount: 1 + (visiblePlans.isEmpty ? 1 : visiblePlans.length),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _bulkMode
                      ? Text(l10n.bulkAllPlansHint)
                      : StudyPlanFilterBar(
                          plans: plans,
                          controller: _searchController,
                          filter: _filter,
                          onQueryChanged: (_) => setState(() {}),
                          onFilterChanged: (filter) =>
                              setState(() => _filter = filter),
                        ),
                );
              }
              if (visiblePlans.isEmpty) {
                return StudyPlanSearchEmpty(
                  onReset: () => setState(() {
                    _searchController.clear();
                    _filter = StudyPlanFilter.all;
                  }),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.cardSpacing),
                child: _planCard(context, visiblePlans[index - 1]),
              );
            },
          );
        },
      ),
      floatingActionButton: _bulkMode || compact
          ? null
          : AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) => widget.store.plans.isEmpty
                  ? const SizedBox.shrink()
                  : FloatingActionButton.extended(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.addPlan),
                    ),
            ),
      bottomNavigationBar: _bulkMode
          ? AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) {
                final plans = widget.store.plans;
                final selectedCount = plans
                    .where((plan) => _selectedIds.contains(plan.id))
                    .length;
                final l10n = AppLocalizations.of(context)!;
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(l10n.selectedCount(selectedCount)),
                            ),
                            TextButton(
                              onPressed: () => _toggleAll(plans),
                              child: Text(
                                selectedCount == plans.length
                                    ? l10n.deselectAll
                                    : l10n.selectAll,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: selectedCount == 0
                                ? null
                                : _deleteSelected,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: Text(l10n.deleteSelected(selectedCount)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : compact
          ? AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) => widget.store.plans.isEmpty
                  ? const SizedBox.shrink()
                  : Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.pagePadding,
                            12,
                            AppTheme.pagePadding,
                            16,
                          ),
                          child: FilledButton.icon(
                            key: const ValueKey('add_plan_compact'),
                            onPressed: () => _openEditor(),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(l10n.addPlan),
                          ),
                        ),
                      ),
                    ),
            )
          : null,
    );
  }
}
