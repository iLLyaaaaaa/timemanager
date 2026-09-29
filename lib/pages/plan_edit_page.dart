import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:io';

import '../l10n/app_localizations.dart';

import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../models/app_settings.dart';
import '../widgets/study_duration_input.dart';
import '../widgets/study_icon_picker.dart';
import '../services/local_media_store.dart';
import '../services/timer_alert_service.dart';

class PlanEditPage extends StatefulWidget {
  const PlanEditPage({
    super.key,
    required this.store,
    this.settings,
    this.plan,
  });

  final StudyPlanStore store;
  final SettingsStore? settings;
  final StudyPlan? plan;

  @override
  State<PlanEditPage> createState() => _PlanEditPageState();
}

class _PlanEditPageState extends State<PlanEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _durationKey = GlobalKey<StudyDurationInputState>();
  late String _selectedIconId;
  String? _customIconPath;
  String? _unsavedIconPath;
  final _media = LocalMediaStore();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan?.name ?? '');
    _selectedIconId = widget.plan?.iconId ?? 'category';
    _customIconPath = widget.plan?.customIconPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (_unsavedIconPath != null) {
      unawaited(_media.deleteIfManaged(_unsavedIconPath, 'custom_icons'));
    }
    super.dispose();
  }

  Future<void> _chooseLocalIcon() async {
    try {
      final chosen = await _media.chooseIcon(
        cropTitle: AppLocalizations.of(context)!.cropImage,
      );
      if (chosen == null) return;
      if (!mounted) {
        await _media.deleteIfManaged(chosen.path, 'custom_icons');
        return;
      }
      final previousUnsaved = _unsavedIconPath;
      setState(() {
        _customIconPath = chosen.path;
        _unsavedIconPath = chosen.path;
      });
      if (previousUnsaved != null) {
        await _media.deleteIfManaged(previousUnsaved, 'custom_icons');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.invalidLocalImage),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final seconds = _durationKey.currentState!.totalSeconds!;
    final existing = widget.plan;
    final previousSessionId = existing?.sessionId;
    if (existing == null) {
      widget.store.addPlan(
        name: name,
        iconId: _selectedIconId,
        plannedSeconds: seconds,
        customIconPath: _customIconPath,
      );
    } else {
      widget.store.updatePlan(
        existing.copyWith(
          name: name,
          iconId: _selectedIconId,
          plannedSeconds: seconds,
          customIconPath: _customIconPath,
          clearCustomIcon: _customIconPath == null,
        ),
      );
    }
    final unusedNewIcon = _unsavedIconPath != _customIconPath
        ? _unsavedIconPath
        : null;
    final saved = await widget.store.flush();
    if (!saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.dataSaveFailed)),
        );
      }
      return;
    }
    if (previousSessionId != null) {
      final alerts = TimerAlertService();
      try {
        await alerts.cancelBackgroundCompletion(previousSessionId);
        final updated = widget.store.planById(existing!.id);
        if (updated?.isRunning == true && mounted) {
          await alerts.scheduleBackgroundCompletion(
            plan: updated!,
            settings: widget.settings?.settings ?? const AppSettings(),
            l10n: AppLocalizations.of(context)!,
          );
        }
      } finally {
        await alerts.dispose();
      }
    }
    _unsavedIconPath = null;
    if (unusedNewIcon != null) {
      await _media.deleteIfManaged(unusedNewIcon, 'custom_icons');
    }
    if (saved &&
        existing?.customIconPath != null &&
        existing!.customIconPath != _customIconPath &&
        !widget.store.plans.any(
          (plan) => plan.customIconPath == existing.customIconPath,
        )) {
      await _media.deleteIfManaged(existing.customIconPath, 'custom_icons');
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.plan != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          isEditing
              ? AppLocalizations.of(context)!.editPlan
              : AppLocalizations.of(context)!.addPlan,
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              TextFormField(
                key: const ValueKey('plan_name'),
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.planName,
                  hintText: AppLocalizations.of(context)!.planNameHint,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? AppLocalizations.of(context)!.planNameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              StudyDurationInput(
                key: _durationKey,
                initialSeconds:
                    widget.plan?.plannedSeconds ??
                    widget.settings?.settings.defaultPlanSeconds ??
                    3600,
                label: AppLocalizations.of(context)!.dailyPlanDuration,
              ),
              const SizedBox(height: 24),
              StudyIconPicker(
                selectedId: _selectedIconId,
                onSelected: (id) => setState(() {
                  _selectedIconId = id;
                  _customIconPath = null;
                }),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _chooseLocalIcon,
                icon: const Icon(Icons.image_outlined),
                label: Text(AppLocalizations.of(context)!.chooseLocalImage),
              ),
              if (_customIconPath != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(
                    dimension: 88,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_customIconPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _save,
            child: Text(AppLocalizations.of(context)!.savePlan),
          ),
        ),
      ),
    );
  }
}
