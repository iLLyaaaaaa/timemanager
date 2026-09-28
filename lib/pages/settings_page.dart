import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../data/study_plan_store.dart';
import '../utils/study_duration.dart';
import '../widgets/study_duration_input.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings, required this.plans});

  final SettingsStore settings;
  final StudyPlanStore plans;

  Future<void> _saveSettings(BuildContext context) async {
    if (!await settings.flush() && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('设置暂未写入本地，请稍后重试')));
    }
  }

  Future<void> _chooseTheme(BuildContext context) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('主题模式'),
        children: [
          for (final (mode, label) in [
            (ThemeMode.system, '跟随系统'),
            (ThemeMode.light, '浅色模式'),
            (ThemeMode.dark, '深色模式'),
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
      helpText: '每日重置时间',
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
        title: const Text('新增计划默认时长'),
        scrollable: true,
        content: Form(
          key: formKey,
          child: StudyDurationInput(
            key: durationKey,
            initialSeconds: settings.settings.defaultPlanSeconds,
            label: '默认时长',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
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
            child: const Text('保存'),
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
                child: const Text('取消'),
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
      title: '恢复默认设置？',
      message: '只恢复设置，不删除学习计划和历史记录。',
      action: '恢复',
    );
    if (!confirmed || !context.mounted) return;
    settings.restoreDefaults();
    await _saveSettings(context);
  }

  Future<void> _clearLearningData(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: '清空学习数据？',
      message: '这会清空今日进度和全部学习历史，保留现有计划。此操作无法撤销。',
      action: '清空学习数据',
    );
    if (!confirmed || !context.mounted) return;
    plans.clearLearningData();
    if (!await plans.flush() && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('学习数据暂未写入本地，请稍后重试')));
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    final first = await _confirm(
      context,
      title: '清空全部数据？',
      message: '所有计划、学习记录和设置都会恢复到首次安装状态。此操作无法撤销。',
      action: '继续',
    );
    if (!first || !context.mounted) return;
    final second = await _confirm(
      context,
      title: '再次确认清空全部数据',
      message: '请确认：这会删除所有自定义计划和学习记录。',
      action: '确认清空',
    );
    if (!second || !context.mounted) return;
    plans.clearAllData();
    settings.restoreDefaults();
    final saved = await Future.wait([plans.flush(), settings.flush()]);
    if (saved.contains(false) && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('数据暂未全部写入本地，请稍后重试')));
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
    final resetTime =
        '${value.dailyResetHour.toString().padLeft(2, '0')}:'
        '${value.dailyResetMinute.toString().padLeft(2, '0')}';
    final themeName = switch (value.themeMode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色模式',
      ThemeMode.dark => '深色模式',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _section(context, '外观', [
          ListTile(
            title: const Text('主题模式'),
            subtitle: Text(themeName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseTheme(context),
          ),
        ]),
        _section(context, '计时', [
          SwitchListTile(
            title: const Text('进入后台时自动暂停计时'),
            subtitle: const Text('为了保证计时准确，进入后台时会自动暂停。'),
            value: value.pauseWhenBackgrounded,
            onChanged: null,
          ),
          SwitchListTile(
            title: const Text('倒计时结束提醒'),
            subtitle: const Text('完成时显示 App 内提示'),
            value: value.completionAlertEnabled,
            onChanged: (enabled) {
              settings.update(value.copyWith(completionAlertEnabled: enabled));
              _saveSettings(context);
            },
          ),
          ListTile(
            title: const Text('每日重置时间'),
            subtitle: Text(resetTime),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseResetTime(context),
          ),
        ]),
        _section(context, '计划', [
          ListTile(
            title: const Text('新增计划默认时长'),
            subtitle: Text(formatStudyDuration(value.defaultPlanSeconds)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseDefaultDuration(context),
          ),
          SwitchListTile(
            title: const Text('删除计划前确认'),
            value: value.confirmBeforeDelete,
            onChanged: (enabled) {
              settings.update(value.copyWith(confirmBeforeDelete: enabled));
              _saveSettings(context);
            },
          ),
        ]),
        _section(context, '数据管理', [
          ListTile(
            title: const Text('恢复默认设置'),
            onTap: () => _restoreDefaults(context),
          ),
          ListTile(
            title: const Text('清空学习数据'),
            onTap: () => _clearLearningData(context),
          ),
          ListTile(
            title: const Text('清空全部数据'),
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
