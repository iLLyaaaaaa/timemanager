import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/settings_store.dart';
import '../data/study_plan_store.dart';
import '../utils/study_duration.dart';
import '../widgets/study_duration_input.dart';
import '../services/timer_alert_service.dart';
import '../services/local_media_store.dart';
import 'sound_trim_page.dart';
import '../widgets/app_section_card.dart';
import '../theme/app_theme.dart';

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
  final _media = LocalMediaStore();
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

  Future<void> _syncRunningNotifications() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    for (final plan in plans.plans) {
      final sessionId = plan.sessionId;
      if (!plan.isRunning || sessionId == null) continue;
      await _alerts.cancelBackgroundCompletion(sessionId);
      if (!mounted) return;
      await _alerts.scheduleBackgroundCompletion(
        plan: plan,
        settings: settings.settings,
        l10n: l10n,
      );
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
    await _syncRunningNotifications();
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

  Future<void> _chooseCustomSound() async {
    PickedLocalSound? picked;
    try {
      picked = await _media.chooseSound();
      if (picked == null || !mounted) return;
      await _alerts.stopPreview();
      if (!mounted) return;
      final selection = await Navigator.of(context).push<SoundTrimSelection>(
        MaterialPageRoute(builder: (_) => SoundTrimPage(sound: picked!)),
      );
      if (selection == null || !mounted) return;
      final chosen = await _media.saveTrimmedSound(
        picked,
        startMilliseconds: selection.startMilliseconds,
        endMilliseconds: selection.endMilliseconds,
      );
      if (!mounted) {
        await _media.deleteIfManaged(chosen.path, 'custom_sounds');
        return;
      }
      final previousSettings = settings.settings;
      final oldPath = settings.settings.customSoundPath;
      settings.update(
        settings.settings.copyWith(
          soundSource: 'custom',
          customSoundPath: chosen.path,
          customSoundName: chosen.name,
        ),
      );
      final saved = await settings.flush();
      if (saved) {
        await _syncRunningNotifications();
        await _media.deleteIfManaged(oldPath, 'custom_sounds');
      } else if (mounted) {
        settings.update(previousSettings);
        await _media.deleteIfManaged(chosen.path, 'custom_sounds');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsSaveFailed),
          ),
        );
      }
    } on UnsupportedNcmSound {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.ncmUnsupported)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.invalidLocalSound),
          ),
        );
      }
    } finally {
      if (picked != null) await _media.deleteTemporarySound(picked);
    }
  }

  Future<void> _previewSound({int? builtin, String? customPath}) async {
    try {
      if (customPath != null) {
        await _alerts.previewCustom(customPath);
      } else if (builtin != null) {
        await _alerts.preview(builtin);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.previewFailed)),
        );
      }
    }
  }

  String _soundName(int sound, AppLocalizations l10n) => switch (sound) {
    1 => l10n.sound1,
    2 => l10n.sound2,
    3 => l10n.sound3,
    4 => l10n.sound4,
    _ => l10n.sound5,
  };

  Future<void> _selectBuiltinSound(int sound) async {
    await _alerts.stopPreview();
    if (!mounted) return;
    final oldPath = settings.settings.customSoundPath;
    settings.update(
      settings.settings.copyWith(
        selectedAlertSound: sound,
        soundSource: 'builtin',
        clearCustomSound: true,
      ),
    );
    await _saveSettings(context);
    if (await settings.flush()) {
      await _syncRunningNotifications();
      await _media.deleteIfManaged(oldPath, 'custom_sounds');
    }
  }

  Future<void> _chooseSound() async {
    String? action;
    try {
      action = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => AnimatedBuilder(
          animation: settings,
          builder: (context, _) {
            final value = settings.settings;
            final l10n = AppLocalizations.of(context)!;
            return SafeArea(
              top: false,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.alertSound,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('close_sound_picker'),
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                        children: [
                          for (var sound = 1; sound <= 5; sound++)
                            ListTile(
                              key: ValueKey('alert_sound_$sound'),
                              selected:
                                  value.soundSource == 'builtin' &&
                                  value.selectedAlertSound == sound,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              leading: Icon(
                                value.soundSource == 'builtin' &&
                                        value.selectedAlertSound == sound
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              title: Text(_soundName(sound, l10n)),
                              trailing: IconButton(
                                tooltip: l10n.preview,
                                icon: const Icon(Icons.play_arrow_rounded),
                                onPressed: () => _previewSound(builtin: sound),
                              ),
                              onTap: () => _selectBuiltinSound(sound),
                            ),
                          const Divider(indent: 16, endIndent: 16),
                          ListTile(
                            key: const ValueKey('choose_local_sound'),
                            leading: const Icon(Icons.audio_file_outlined),
                            title: Text(l10n.chooseLocalSound),
                            subtitle: value.soundSource == 'custom'
                                ? Text(
                                    value.customSoundName ?? l10n.customSound,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            selected: value.soundSource == 'custom',
                            trailing:
                                value.soundSource == 'custom' &&
                                    value.customSoundPath != null
                                ? IconButton(
                                    tooltip: l10n.preview,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    onPressed: () => _previewSound(
                                      customPath: value.customSoundPath,
                                    ),
                                  )
                                : null,
                            onTap: () => Navigator.pop(sheetContext, 'custom'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      await _alerts.stopPreview();
    }
    if (action == 'custom' && mounted) await _chooseCustomSound();
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
    final previousSound = settings.settings.customSoundPath;
    settings.restoreDefaults();
    await _saveSettings(context);
    await _syncRunningNotifications();
    if (await settings.flush()) {
      await _media.deleteIfManaged(previousSound, 'custom_sounds');
    }
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
    unawaited(_alerts.cancelAllCompletions());
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
    unawaited(_alerts.cancelAllCompletions());
    settings.restoreDefaults();
    final saved = await Future.wait([plans.flush(), settings.flush()]);
    if (!saved.contains(false)) await _media.clearAll();
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
      ThemeMode.system => l10n.followSystem,
      ThemeMode.light => l10n.lightMode,
      ThemeMode.dark => l10n.darkMode,
    };
    return ListView(
      key: const PageStorageKey('settings_scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        12,
        AppTheme.pagePadding,
        24,
      ),
      children: [
        _section(context, l10n.appearance, [
          ListTile(
            leading: const _SettingIcon(Icons.palette_outlined),
            title: Text(l10n.themeMode),
            subtitle: Text(themeName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseTheme(context),
          ),
          ListTile(
            leading: const _SettingIcon(Icons.language_rounded),
            title: Text(l10n.language),
            subtitle: Text(
              value.localeCode == 'en' ? l10n.english : l10n.chinese,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseLanguage(context),
          ),
        ]),
        _section(context, l10n.timing, [
          ListTile(
            leading: const _SettingIcon(Icons.pause_circle_outline_rounded),
            title: Text(l10n.backgroundPause),
            subtitle: Text(l10n.backgroundPauseSettingHint),
          ),
          ListTile(
            leading: const _SettingIcon(Icons.schedule_rounded),
            title: Text(l10n.dailyResetTime),
            subtitle: Text(resetTime),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseResetTime(context),
          ),
        ]),
        _section(context, l10n.timerAlert, [
          ListTile(
            leading: const _SettingIcon(Icons.notifications_none_rounded),
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
            ListTile(
              key: const ValueKey('open_sound_picker'),
              leading: const _SettingIcon(Icons.music_note_outlined),
              title: Text(l10n.alertSound),
              subtitle: Text(
                value.soundSource == 'custom'
                    ? (value.customSoundName ?? l10n.customSound)
                    : _soundName(value.selectedAlertSound, l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _chooseSound,
            ),
            if (value.soundSource == 'custom')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  l10n.customSoundBackgroundFallback,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
          if (value.timerAlertMode != 'none' &&
              (_notificationsAllowed == false || _exactAlarmsAllowed == false))
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.notificationPermissionHint),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _requestNotifications,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(l10n.notificationPermissionAction),
                  ),
                ],
              ),
            ),
        ]),
        _section(context, l10n.planSection, [
          ListTile(
            leading: const _SettingIcon(Icons.timer_outlined),
            title: Text(l10n.defaultPlanDuration),
            subtitle: Text(formatStudyDuration(value.defaultPlanSeconds)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseDefaultDuration(context),
          ),
          SwitchListTile(
            title: Text(l10n.confirmBeforeDelete),
            value: value.confirmBeforeDelete,
            onChanged: (enabled) {
              settings.update(value.copyWith(confirmBeforeDelete: enabled));
              _saveSettings(context);
            },
          ),
        ]),
        _section(context, l10n.dataManagement, [
          ListTile(
            leading: const _SettingIcon(Icons.restore_rounded),
            title: Text(l10n.restoreDefaults),
            subtitle: Text(l10n.restoreDefaultsMessage),
            onTap: () => _restoreDefaults(context),
          ),
          ListTile(
            leading: const _SettingIcon(Icons.history_rounded),
            title: Text(l10n.clearStudyData),
            subtitle: Text(l10n.clearStudyMessage),
            onTap: () => _clearLearningData(context),
          ),
          ListTile(
            leading: const _SettingIcon(
              Icons.delete_forever_outlined,
              danger: true,
            ),
            title: Text(l10n.clearAllData),
            subtitle: Text(l10n.clearAllMessage),
            textColor: Theme.of(context).colorScheme.error,
            onTap: () => _clearAllData(context),
          ),
        ]),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          AppSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  children[index],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon(this.icon, {this.danger = false});
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: danger ? colors.errorContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 20,
        color: danger ? colors.onErrorContainer : colors.onPrimaryContainer,
      ),
    );
  }
}
