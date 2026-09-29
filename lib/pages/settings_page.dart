import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/settings_store.dart';
import '../data/study_plan_store.dart';
import '../utils/study_duration.dart';
import '../widgets/study_duration_input.dart';
import '../services/timer_alert_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.plans,
    this.alerts,
  });

  final SettingsStore settings;
  final StudyPlanStore plans;
  final TimerAlertService? alerts;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsStore get settings => widget.settings;
  StudyPlanStore get plans => widget.plans;
  late final TimerAlertService _alerts = widget.alerts ?? TimerAlertService();
  bool? _notificationsAllowed;
  bool? _exactAlarmsAllowed;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshNotificationPermission());
  }

  Future<void> _refreshNotificationPermission() async {
    final enabled = await _alerts.notificationsEnabled();
    final exact = await _alerts.exactAlarmsEnabled();
    if (mounted) {
      setState(() {
        _notificationsAllowed = enabled;
        _exactAlarmsAllowed = exact;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_stopAndDisposeAlerts());
    super.dispose();
  }

  Future<void> _stopAndDisposeAlerts() async {
    await _alerts.stopPreview();
    if (widget.alerts == null) await _alerts.dispose();
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          for (final (code, label) in [
            ('zh', l10n.chinese),
            ('en', l10n.english),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, code),
              child: Row(
                children: [
                  if (settings.settings.localeCode == code) ...[
                    const Icon(Icons.check_rounded),
                    const SizedBox(width: 12),
                  ],
                  Text(label),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    settings.update(settings.settings.copyWith(localeCode: selected));
    await _saveSettings(context);
  }

  Future<void> _chooseAlertMode(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.alertMode),
        children: [
          for (final (mode, label) in [
            ('sound', l10n.sound),
            ('vibration', l10n.vibration),
            ('none', l10n.none),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, mode),
              child: Row(
                children: [
                  if (settings.settings.timerAlertMode == mode) ...[
                    const Icon(Icons.check_rounded),
                    const SizedBox(width: 12),
                  ],
                  Text(label),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    if (selected != 'sound') await _alerts.stopPreview();
    if (!context.mounted) return;
    settings.update(settings.settings.copyWith(timerAlertMode: selected));
    await _saveSettings(context);
    if (selected != 'none') await _refreshNotificationPermission();
  }

  Future<void> _requestNotifications() async {
    await _alerts.requestNotificationPermission();
    if (!mounted) return;
    if (await _alerts.notificationsEnabled()) {
      await _alerts.requestExactAlarmPermission();
    }
    await _refreshNotificationPermission();
  }

  Future<void> _saveSettings(BuildContext context) async {
    if (!await settings.flush() && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.settingsSaveFailed),
        ),
      );
    }
  }

  Future<void> _chooseTheme(BuildContext context) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.themeMode),
        children: [
          for (final (mode, label) in [
            (ThemeMode.system, AppLocalizations.of(context)!.followSystem),
            (ThemeMode.light, AppLocalizations.of(context)!.lightMode),
            (ThemeMode.dark, AppLocalizations.of(context)!.darkMode),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, mode),
              child: Row(
                children: [
                  if (settings.settings.themeMode == mode)
                    const Icon(Icons.check_rounded),
                  if (settings.settings.themeMode == mode)
                    const SizedBox(width: 12),
                  Text(label),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    settings.update(settings.settings.copyWith(themeMode: selected));
    await _saveSettings(context);
  }

  Future<void> _chooseResetTime(BuildContext context) async {
    final current = settings.settings;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.dailyResetHour,
        minute: current.dailyResetMinute,
      ),
      helpText: AppLocalizations.of(context)!.dailyResetTime,
      builder: (pickerContext, child) => MediaQuery(
        data: MediaQuery.of(pickerContext)
            .copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null || !context.mounted) return;
    settings.update(
      settings.settings.copyWith(
        dailyResetHour: selected.hour,
        dailyResetMinute: selected.minute,
      ),
    );
    await _saveSettings(context);
  }

  Future<void> _chooseDefaultDuration(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final durationKey = GlobalKey<StudyDurationInputState>();
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.defaultPlanDuration),
        scrollable: true,
        content: Form(
          key: formKey,
          child: StudyDurationInput(
            key: durationKey,
            initialSeconds: settings.settings.defaultPlanSeconds,
            label: AppLocalizations.of(context)!.defaultDuration,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  dialogContext,
                  durationKey.currentState!.totalSeconds,
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    settings.update(settings.settings.copyWith(defaultPlanSeconds: selected));
    await _saveSettings(context);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _restoreDefaults(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: AppLocalizations.of(context)!.restoreDefaultsTitle,
      message: AppLocalizations.of(context)!.restoreDefaultsMessage,
      action: AppLocalizations.of(context)!.restore,
    );
    if (!confirmed || !context.mounted) return;
    settings.restoreDefaults();
    await _saveSettings(context);
  }

  Future<void> _clearLearningData(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: AppLocalizations.of(context)!.clearStudyTitle,
      message: AppLocalizations.of(context)!.clearStudyMessage,
      action: AppLocalizations.of(context)!.clearStudyData,
    );
    if (!confirmed || !context.mounted) return;
    plans.clearLearningData();
    if (!await plans.flush() && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.studyDataSaveFailed),
        ),
      );
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    final first = await _confirm(
      context,
      title: AppLocalizations.of(context)!.clearAllTitle,
      message: AppLocalizations.of(context)!.clearAllMessage,
      action: AppLocalizations.of(context)!.continueAction,
    );
    if (!first || !context.mounted) return;
    final second = await _confirm(
      context,
      title: AppLocalizations.of(context)!.clearAllAgainTitle,
      message: AppLocalizations.of(context)!.clearAllAgainMessage,
      action: AppLocalizations.of(context)!.confirmClear,
    );
    if (!second || !context.mounted) return;
    plans.clearAllData();
    settings.restoreDefaults();
    final saved = await Future.wait([plans.flush(), settings.flush()]);
    if (saved.contains(false) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.dataSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final value = settings.settings;
    final l10n = AppLocalizations.of(context)!;
    final resetTime =
        '${value.dailyResetHour.toString().padLeft(2, '0')}:'
        '${value.dailyResetMinute.toString().padLeft(2, '0')}';
    final themeName = switch (value.themeMode) {
      ThemeMode.system => AppLocalizations.of(context)!.followSystem,
      ThemeMode.light => AppLocalizations.of(context)!.lightMode,
      ThemeMode.dark => AppLocalizations.of(context)!.darkMode,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _section(context, AppLocalizations.of(context)!.appearance, [
          ListTile(
            title: Text(AppLocalizations.of(context)!.themeMode),
            subtitle: Text(themeName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseTheme(context),
          ),
          ListTile(
            title: Text(l10n.language),
            subtitle: Text(
              value.localeCode == 'en' ? l10n.english : l10n.chinese,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseLanguage(context),
          ),
        ]),
        _section(context, AppLocalizations.of(context)!.timing, [
          ListTile(
            title: Text(AppLocalizations.of(context)!.backgroundPause),
            subtitle: Text(AppLocalizations.of(context)!.backgroundPauseHint),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.dailyResetTime),
            subtitle: Text(resetTime),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseResetTime(context),
          ),
        ]),
        _section(context, l10n.timerAlert, [
          ListTile(
            title: Text(l10n.alertMode),
            subtitle: Text(switch (value.timerAlertMode) {
              'vibration' => l10n.vibration,
              'none' => l10n.none,
              _ => l10n.sound,
            }),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseAlertMode(context),
          ),
          if (value.timerAlertMode == 'sound') ...[
            ListTile(title: Text(l10n.alertSound)),
            for (var sound = 1; sound <= 5; sound++)
              ListTile(
                key: ValueKey('alert_sound_$sound'),
                leading: Icon(
                  value.selectedAlertSound == sound
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(switch (sound) {
                  1 => l10n.sound1,
                  2 => l10n.sound2,
                  3 => l10n.sound3,
                  4 => l10n.sound4,
                  _ => l10n.sound5,
                }),
                trailing: IconButton(
                  tooltip: l10n.preview,
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () => _alerts.preview(sound),
                ),
                onTap: () {
                  settings.update(value.copyWith(selectedAlertSound: sound));
                  _saveSettings(context);
                },
              ),
          ],
          if (value.timerAlertMode != 'none' &&
              (_notificationsAllowed == false || _exactAlarmsAllowed == false))
            ListTile(
              title: Text(l10n.notificationPermissionHint),
              trailing: TextButton(
                onPressed: _requestNotifications,
                child: Text(l10n.notificationPermissionAction),
              ),
            ),
        ]),
        _section(context, AppLocalizations.of(context)!.planSection, [
          ListTile(
            title: Text(AppLocalizations.of(context)!.defaultPlanDuration),
            subtitle: Text(formatStudyDuration(value.defaultPlanSeconds)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseDefaultDuration(context),
          ),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.confirmBeforeDelete),
            value: value.confirmBeforeDelete,
            onChanged: (enabled) {
              settings.update(value.copyWith(confirmBeforeDelete: enabled));
              _saveSettings(context);
            },
          ),
        ]),
        _section(context, AppLocalizations.of(context)!.dataManagement, [
          ListTile(
            title: Text(AppLocalizations.of(context)!.restoreDefaults),
            onTap: () => _restoreDefaults(context),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.clearStudyData),
            onTap: () => _clearLearningData(context),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.clearAllData),
            textColor: Theme.of(context).colorScheme.error,
            onTap: () => _clearAllData(context),
          ),
        ]),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
