import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../data/study_plan_store.dart';
import '../l10n/app_localizations.dart';
import '../models/study_scheme.dart';
import '../services/local_media_store.dart';
import '../utils/study_duration.dart';
import '../widgets/app_section_card.dart';
import '../widgets/save_retry_banner.dart';
import '../widgets/study_scheme_picker.dart';
import 'plan_management_page.dart';

class SchemeManagementPage extends StatefulWidget {
  const SchemeManagementPage({
    super.key,
    required this.store,
    required this.settings,
  });
  final StudyPlanStore store;
  final SettingsStore settings;
  @override
  State<SchemeManagementPage> createState() => _SchemeManagementPageState();
}

class _SchemeManagementPageState extends State<SchemeManagementPage> {
  bool _busy = false;

  Future<String?> _name(String title, {String initial = ''}) {
    var input = initial;
    final form = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            key: const ValueKey('scheme_name'),
            initialValue: initial,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(labelText: l10n.schemeName),
            onChanged: (value) => input = value,
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.planNameRequired
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('save_scheme_name'),
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, input.trim());
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<bool> _save() async {
    final saved = await widget.store.flush();
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.dataSaveFailed)),
      );
    }
    return saved;
  }

  Future<void> _create({StudyScheme? copy}) async {
    if (_busy || widget.store.isReplacing) return;
    final l10n = AppLocalizations.of(context)!;
    final name = await _name(copy == null ? l10n.addScheme : l10n.copyScheme);
    if (name == null || !mounted || widget.store.isReplacing) return;
    setState(() => _busy = true);
    final scheme = widget.store.addScheme(name, copyFrom: copy?.id);
    await _save();
    if (!mounted) return;
    setState(() => _busy = false);
    _editTasks(scheme);
  }

  void _editTasks(StudyScheme scheme) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlanManagementPage(
        store: widget.store,
        settings: widget.settings,
        schemeId: scheme.id,
      ),
    ),
  );

  Future<void> _action(StudyScheme scheme, String action) async {
    if (_busy || widget.store.isReplacing) return;
    if (action == 'copy') {
      await _create(copy: scheme);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    if (action == 'rename') {
      final name = await _name(
        l10n.renameScheme,
        initial: studySchemeName(context, scheme),
      );
      if (name == null || !mounted || widget.store.isReplacing) return;
      widget.store.renameScheme(scheme.id, name);
      await _save();
      return;
    }
    final replacement = await showStudySchemePicker(
      context,
      widget.store,
      title: l10n.deleteSchemeHint,
      excludeId: scheme.id,
    );
    if (replacement == null || !mounted || widget.store.isReplacing) return;
    setState(() => _busy = true);
    final paths = widget.store
        .plansForScheme(scheme.id)
        .map((p) => p.customIconPath)
        .toSet();
    widget.store.deleteScheme(scheme.id, replacementId: replacement.schemeId);
    if (await _save()) {
      final media = LocalMediaStore();
      for (final path in paths) {
        if (path != null &&
            !widget.store.plans.any((p) => p.customIconPath == path)) {
          await media.deleteIfManaged(path, 'custom_icons');
        }
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageSchemes)),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SaveRetryBanner(
              store: widget.store,
              settings: widget.settings,
              enabled: !_busy,
            ),
            Text(l10n.schemeEditHint),
            const SizedBox(height: 12),
            for (final scheme in widget.store.schemes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            color: studySchemeColor(context, scheme.id),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              studySchemeName(context, scheme),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          PopupMenuButton<String>(
                            key: ValueKey('scheme_menu_${scheme.id}'),
                            enabled: !_busy && !widget.store.isReplacing,
                            onSelected: (action) => _action(scheme, action),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(l10n.renameScheme),
                              ),
                              PopupMenuItem(
                                value: 'copy',
                                child: Text(l10n.copyScheme),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                enabled: widget.store.schemes.length > 1,
                                child: Text(l10n.deleteScheme),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        l10n.homeSummary(
                          widget.store.plansForScheme(scheme.id).length,
                          formatStudyDuration(
                            widget.store
                                .plansForScheme(scheme.id)
                                .fold(0, (sum, p) => sum + p.plannedSeconds),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: ValueKey('edit_scheme_${scheme.id}'),
                        onPressed: _busy || widget.store.isReplacing
                            ? null
                            : () => _editTasks(scheme),
                        child: Text(l10n.viewSchemeTasks),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const ValueKey('add_scheme'),
            onPressed: _busy || widget.store.isReplacing
                ? null
                : () => _create(),
            icon: const Icon(Icons.add),
            label: Text(l10n.addScheme),
          ),
        ),
      ),
    );
  }
}
