import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../data/study_plan_store.dart';
import '../l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../models/study_plan.dart';
import '../services/local_media_store.dart';
import '../services/timer_alert_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/study_duration_input.dart';
import '../widgets/study_icon_picker.dart';

class PlanEditPage extends StatefulWidget {
  const PlanEditPage({
    super.key,
    required this.store,
    this.settings,
    this.plan,
    this.media,
  });

  final StudyPlanStore store;
  final SettingsStore? settings;
  final StudyPlan? plan;
  final LocalMediaStore? media;

  @override
  State<PlanEditPage> createState() => _PlanEditPageState();
}

class _PlanEditPageState extends State<PlanEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameKey = GlobalKey();
  final _nameFocus = FocusNode();
  final _durationKey = GlobalKey<StudyDurationInputState>();
  late final TextEditingController _nameController;
  late final LocalMediaStore _media = widget.media ?? LocalMediaStore();
  late String _initialName;
  late int _initialSeconds;
  late String _initialIconId;
  String? _initialCustomPath;
  int? _seconds;
  late String _selectedIconId;
  String? _customIconPath;
  String? _editingPlanId;
  final _newIconPaths = <String>{};
  final _replacedIconPaths = <String>{};
  final _sessionsToCancel = <String>{};
  bool _isSaving = false;
  bool _isChoosingImage = false;
  bool _saveFailed = false;
  bool _leaveDialogOpen = false;
  bool _allowPop = false;

  bool get _hasChanges =>
      _nameController.text.trim() != _initialName ||
      _seconds != _initialSeconds ||
      _customIconPath != _initialCustomPath ||
      (_customIconPath == null && _selectedIconId != _initialIconId);

  @override
  void initState() {
    super.initState();
    _initialName = widget.plan?.name.trim() ?? '';
    _initialSeconds =
        widget.plan?.plannedSeconds ??
        widget.settings?.settings.defaultPlanSeconds ??
        3600;
    _initialIconId = widget.plan?.iconId ?? 'category';
    _initialCustomPath = widget.plan?.customIconPath;
    _seconds = _initialSeconds;
    _selectedIconId = _initialIconId;
    _customIconPath = _initialCustomPath;
    _editingPlanId = widget.plan?.id;
    _nameController = TextEditingController(text: widget.plan?.name ?? '')
      ..addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  Future<void> _removeUnreferencedIcons(Iterable<String> paths) async {
    for (final path in paths.toSet()) {
      if (!widget.store.plans.any((plan) => plan.customIconPath == path)) {
        await _media.deleteIfManaged(path, 'custom_icons');
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocus.dispose();
    // Failed writes still leave the plan in memory, so referenced drafts survive.
    unawaited(
      _removeUnreferencedIcons(_newIconPaths).catchError((Object error) {
        debugPrint(
          'TimeManager: draft image cleanup failed (${error.runtimeType})',
        );
      }),
    );
    super.dispose();
  }

  Future<void> _chooseLocalIcon() async {
    if (_isSaving || _isChoosingImage) return;
    setState(() => _isChoosingImage = true);
    try {
      final chosen = await _media.chooseIcon(
        cropTitle: AppLocalizations.of(context)!.cropImage,
      );
      if (chosen == null) return;
      if (!mounted) {
        await _removeUnreferencedIcons([chosen.path]);
        return;
      }
      _newIconPaths.add(chosen.path);
      setState(() => _customIconPath = chosen.path);
      await _removeUnreferencedIcons(
        _newIconPaths.where((path) => path != _customIconPath),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.invalidLocalImage),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChoosingImage = false);
    }
  }

  void _popEditor() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _requestLeave() async {
    if (_isSaving || _isChoosingImage || _leaveDialogOpen || _allowPop) return;
    if (!_hasChanges && !_saveFailed) {
      _popEditor();
      return;
    }
    _leaveDialogOpen = true;
    try {
      final l10n = AppLocalizations.of(context)!;
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(
            _saveFailed ? l10n.planNotPersistedTitle : l10n.discardPlanTitle,
          ),
          content: Text(
            _saveFailed
                ? l10n.planNotPersistedMessage
                : l10n.discardPlanMessage,
          ),
          actions: [
            TextButton(
              key: const ValueKey('keep_editing'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.keepEditing),
            ),
            FilledButton(
              key: const ValueKey('leave_editor'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_saveFailed ? l10n.leavePage : l10n.discardChanges),
            ),
          ],
        ),
      );
      if (mounted && leave == true) _popEditor();
    } finally {
      _leaveDialogOpen = false;
    }
  }

  void _revealValidationError() {
    final invalidName = _nameController.text.trim().isEmpty;
    if (invalidName) {
      _nameFocus.requestFocus();
    } else {
      _durationKey.currentState?.focusInvalidPart();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = invalidName
          ? _nameKey.currentContext
          : _durationKey.currentState?.focusedPartContext ??
                _durationKey.currentContext;
      if (target != null) {
        unawaited(Scrollable.ensureVisible(target, alignment: 0.1));
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving || _isChoosingImage) return;
    if (!_formKey.currentState!.validate()) {
      _revealValidationError();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    var persisted = false;
    try {
      final name = _nameController.text.trim();
      final seconds = _durationKey.currentState!.totalSeconds!;
      final existing = _editingPlanId == null
          ? null
          : widget.store.planById(_editingPlanId!);
      if (_editingPlanId != null && existing == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.planMissing)),
        );
        return;
      }
      if (existing?.sessionId != null) {
        _sessionsToCancel.add(existing!.sessionId!);
      }
      if (existing?.customIconPath != null &&
          existing!.customIconPath != _customIconPath) {
        _replacedIconPaths.add(existing.customIconPath!);
      }
      if (existing == null) {
        _editingPlanId = widget.store
            .addPlan(
              name: name,
              iconId: _selectedIconId,
              plannedSeconds: seconds,
              customIconPath: _customIconPath,
            )
            .id;
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
      persisted = await widget.store.flush();
      if (!persisted) {
        _saveFailed = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.dataSaveFailed),
            ),
          );
        }
        return;
      }
      _saveFailed = false;
      _initialName = name;
      _initialSeconds = seconds;
      _initialIconId = _selectedIconId;
      _initialCustomPath = _customIconPath;
      if (_sessionsToCancel.isNotEmpty) {
        final alerts = TimerAlertService();
        try {
          for (final sessionId in _sessionsToCancel) {
            await alerts.cancelBackgroundCompletion(sessionId);
          }
          final updated = widget.store.planById(_editingPlanId!);
          if (updated?.isRunning == true && mounted) {
            await alerts.scheduleBackgroundCompletion(
              plan: updated!,
              settings: widget.settings?.settings ?? const AppSettings(),
              l10n: AppLocalizations.of(context)!,
            );
          }
          _sessionsToCancel.clear();
        } finally {
          await alerts.dispose();
        }
      }
      await _removeUnreferencedIcons({..._newIconPaths, ..._replacedIconPaths});
      _newIconPaths.clear();
      _replacedIconPaths.clear();
      if (mounted) _popEditor();
    } catch (_) {
      _saveFailed = !persisted;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              persisted
                  ? AppLocalizations.of(context)!.planFollowUpFailed
                  : AppLocalizations.of(context)!.dataSaveFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop:
          _allowPop ||
          (!_isSaving && !_isChoosingImage && !_hasChanges && !_saveFailed),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestLeave());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            widget.plan == null ? l10n.addPlan : l10n.editPlan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  key: const ValueKey('editor_back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const BackButtonIcon(),
                  onPressed: _isSaving || _isChoosingImage
                      ? null
                      : _requestLeave,
                )
              : null,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                16,
                AppTheme.pagePadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSectionCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.planDetails,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        KeyedSubtree(
                          key: _nameKey,
                          child: TextFormField(
                            key: const ValueKey('plan_name'),
                            controller: _nameController,
                            focusNode: _nameFocus,
                            enabled: !_isSaving,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _durationKey.currentState?.focusFirstPart(),
                            decoration: InputDecoration(
                              labelText: l10n.planName,
                              hintText: l10n.planNameHint,
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? l10n.planNameRequired
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) => StudyDurationInput(
                            key: _durationKey,
                            initialSeconds: _initialSeconds,
                            label: l10n.dailyPlanDuration,
                            enabled: !_isSaving,
                            stacked:
                                constraints.maxWidth <
                                216 *
                                        MediaQuery.textScalerOf(context)
                                            .scale(14) /
                                        14 +
                                    16,
                            onChanged: (seconds) =>
                                setState(() => _seconds = seconds),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.cardSpacing),
                  AppSectionCard(
                    padding: const EdgeInsets.all(16),
                    child: IgnorePointer(
                      ignoring: _isSaving || _isChoosingImage,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StudyIconPicker(
                            selectedId: _selectedIconId,
                            customSelected: _customIconPath != null,
                            onSelected: (id) => setState(() {
                              _selectedIconId = id;
                              _customIconPath = null;
                            }),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const ValueKey('choose_plan_image'),
                              onPressed: _isSaving || _isChoosingImage
                                  ? null
                                  : _chooseLocalIcon,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                l10n.chooseLocalImage,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          if (_customIconPath != null) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppTheme.imageRadius,
                              ),
                              child: SizedBox.square(
                                dimension: 112,
                                child: Image.file(
                                  File(_customIconPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: AnimatedPadding(
          duration: AppTheme.transitionDuration(context),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Material(
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
                child: FilledButton(
                  key: const ValueKey('save_plan'),
                  onPressed: _isSaving || _isChoosingImage ? null : _save,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSaving) ...[
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Text(
                          _isSaving ? l10n.savingPlan : l10n.savePlan,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
