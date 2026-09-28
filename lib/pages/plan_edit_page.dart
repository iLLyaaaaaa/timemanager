import 'package:flutter/material.dart';

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
        title: Text(isEditing ? '编辑计划' : '新增计划'),
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
              decoration: const InputDecoration(
                labelText: '计划名称',
                hintText: '例如：阅读、Python、健身',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入计划名称' : null,
            ),
            const SizedBox(height: 16),
            StudyDurationInput(
              key: _durationKey,
              initialSeconds:
                  widget.plan?.plannedSeconds ??
                  widget.settings?.settings.defaultPlanSeconds ??
                  3600,
              label: '每日计划时长',
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
          child: FilledButton(onPressed: _save, child: const Text('保存计划')),
        ),
      ),
    );
  }
}
