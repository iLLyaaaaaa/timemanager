import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/study_plan_store.dart';
import '../data/settings_store.dart';
import '../models/study_plan.dart';
import '../widgets/study_duration_input.dart';
import '../widgets/study_icon_picker.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan?.name ?? '');
    _selectedIconId = widget.plan?.iconId ?? 'category';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final seconds = _durationKey.currentState!.totalSeconds!;
    final existing = widget.plan;
    if (existing == null) {
      widget.store.addPlan(
        name: name,
        iconId: _selectedIconId,
        plannedSeconds: seconds,
      );
    } else {
      widget.store.updatePlan(
        existing.copyWith(
          name: name,
          iconId: _selectedIconId,
          plannedSeconds: seconds,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.plan != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? AppLocalizations.of(context)!.editPlan
              : AppLocalizations.of(context)!.addPlan,
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              onSelected: (id) => setState(() => _selectedIconId = id),
            ),
          ],
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
