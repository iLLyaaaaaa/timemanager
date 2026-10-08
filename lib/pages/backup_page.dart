import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/study_backup.dart';
import '../services/study_backup_service.dart';
import '../theme/app_theme.dart';
import '../utils/study_history.dart';
import '../widgets/app_section_card.dart';

enum BackupAction { none, exportData, importData, previous }

String backupErrorMessage(Object error, AppLocalizations l10n) {
  if (error is! BackupException) return l10n.backupOperationFailed;
  return switch (error.code) {
    'tooLarge' => l10n.backupTooLarge,
    'invalid' => l10n.backupInvalid,
    'version' => l10n.backupVersionUnsupported,
    'media' => l10n.backupMediaInvalid,
    'save' => l10n.backupSaveFirst,
    'read' => l10n.backupReadFailed,
    'recovery' => l10n.backupRecoveryNeeded,
    'previousUnreadable' => l10n.backupPreviousUnreadable,
    'busy' => l10n.backupBusy,
    _ => l10n.backupOperationFailed,
  };
}

class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    required this.service,
    this.initialAction = BackupAction.none,
    this.closeAfterRestore = false,
  });
  final StudyBackupService service;
  final BackupAction initialAction;
  final bool closeAfterRestore;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;
  bool _showProgress = false;
  bool _failed = false;
  String? _message;
  StudyBackup? _preview;
  StudyBackupService get service => widget.service;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (service.requiresRecovery) {
        setState(
          () => _message = AppLocalizations.of(context)!.backupRecoveryNeeded,
        );
        return;
      }
      switch (widget.initialAction) {
        case BackupAction.exportData:
          _export();
        case BackupAction.importData:
          _choose();
        case BackupAction.previous:
          _previous();
        case BackupAction.none:
          break;
      }
    });
  }

  Future<void> _run(
    String message,
    Future<void> Function() action, {
    bool progress = true,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _showProgress = progress;
      _message = progress ? message : null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = backupErrorMessage(error, AppLocalizations.of(context)!);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _missingLabel(String value, AppLocalizations l10n) =>
      value.startsWith('sound:')
      ? '${l10n.backupMissingSound}${value.length > 6 ? ': ${value.substring(6)}' : ''}'
      : value.startsWith('icon:')
      ? value.substring(5)
      : value;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    await _run(l10n.backupExporting, () async {
      final backup = await service.capture();
      if (!mounted) return;
      if (backup.missingMedia.isNotEmpty) {
        setState(() {
          _showProgress = false;
          _message = null;
        });
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.backupMissingTitle),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.backupMissingHint),
                    const SizedBox(height: 12),
                    for (final missing in backup.missingMedia)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_missingLabel(missing, l10n)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const ValueKey('continue_backup'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.backupContinueExport),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirmed != true) {
          _message = l10n.backupCancelled;
          return;
        }
      }
      setState(() {
        _showProgress = true;
        _message = l10n.backupExporting;
      });
      final saved = await service.export(backup);
      if (mounted) {
        _message = saved ? l10n.backupExported : l10n.backupCancelled;
      }
    });
  }

  Future<void> _choose() async {
    final l10n = AppLocalizations.of(context)!;
    await _run(l10n.backupInspecting, () async {
      final backup = await service.chooseBackup();
      if (!mounted) return;
      if (backup == null) {
        _message = l10n.backupCancelled;
        return;
      }
      _preview = backup;
      _message = null;
    });
  }

  Future<void> _previous() async {
    final l10n = AppLocalizations.of(context)!;
    await _run(l10n.backupInspecting, () async {
      final backup = await service.previousBackup();
      if (!mounted) return;
      if (backup == null) {
        _message = l10n.backupNoPrevious;
        return;
      }
      _preview = backup;
      _message = null;
    });
  }

  Future<void> _restore() async {
    final backup = _preview;
    if (_busy || backup == null) return;
    final l10n = AppLocalizations.of(context)!;
    await _run(l10n.backupRestoring, () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.backupRestoreConfirmTitle),
          content: SingleChildScrollView(
            child: Text(l10n.backupRestoreConfirmMessage),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const ValueKey('confirm_backup_restore'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.backupConfirmRestore),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        _message = l10n.backupCancelled;
        return;
      }
      setState(() {
        _showProgress = true;
        _message = l10n.backupRestoring;
      });
      await service.restore(backup);
      if (!mounted) return;
      _preview = null;
      _message = AppLocalizations.of(context)!.backupRestored;
      if (widget.closeAfterRestore) {
        setState(() => _busy = false);
        Navigator.of(context).pop(true);
      }
    }, progress: false);
  }

  Future<void> _recover() async {
    final l10n = AppLocalizations.of(context)!;
    await _run(l10n.backupRecovering, () async {
      final committed = await service.recoverPending();
      if (mounted) {
        _message = committed
            ? l10n.backupRestored
            : l10n.backupRecoveryCompleted;
      }
    });
  }

  Widget _button(String key, String text, IconData icon, VoidCallback action) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: ValueKey(key),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onPressed: _busy || service.requiresRecovery ? null : action,
            icon: Icon(icon),
            label: Text(text, textAlign: TextAlign.center),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final backup = _preview;
    return PopScope(
      canPop: !_busy && !service.requiresRecovery,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.backupTitle),
          automaticallyImplyLeading: !_busy && !service.requiresRecovery,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            children: [
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.backupDescription),
                    const SizedBox(height: 12),
                    Text(l10n.backupPausedHint),
                    const SizedBox(height: 12),
                    Text(
                      l10n.backupPreviousHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_message != null || service.requiresRecovery)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_busy && _showProgress)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(),
                          ),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _message ?? l10n.backupRecoveryNeeded,
                            key: const ValueKey('backup_status'),
                            style: TextStyle(
                              color: _failed
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                        if (service.requiresRecovery && !_busy)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: FilledButton(
                              key: const ValueKey('retry_backup_recovery'),
                              onPressed: _recover,
                              child: Text(l10n.backupRetryRecovery),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              _button(
                'export_backup',
                l10n.exportBackup,
                Icons.upload_file_outlined,
                _export,
              ),
              _button(
                'import_backup',
                l10n.importBackup,
                Icons.download_outlined,
                _choose,
              ),
              _button(
                'previous_backup',
                l10n.restorePreviousBackup,
                Icons.restore_rounded,
                _previous,
              ),
              if (backup != null) _previewCard(backup, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewCard(StudyBackup backup, AppLocalizations l10n) {
    final dates = StudyHistoryIndex(
      records: backup.plans.records,
      lastDay: backup.settings.studyDate(service.currentTime),
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final format = DateFormat.yMMMd(locale);
    Widget detail(String title, String value) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          Text(value),
        ],
      ),
    );
    return AppSectionCard(
      key: const ValueKey('backup_preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.backupRestorePreview,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          detail(
            l10n.backupCreatedAt,
            DateFormat.yMMMd(locale)
                .add_Hm()
                .format(backup.createdAt.toLocal()),
          ),
          Wrap(
            spacing: 32,
            runSpacing: 8,
            children: [
              detail(l10n.backupPlans, '${backup.plans.plans.length}'),
              detail(l10n.backupRecords, '${backup.plans.records.length}'),
              detail(l10n.backupMedia, '${backup.media.length}'),
            ],
          ),
          detail(
            l10n.backupHistoryRange,
            dates.earliestDay == null
                ? l10n.backupNoHistory
                : '${format.format(dates.earliestDay!)} – ${format.format(dates.latestDay!)}',
          ),
          if (backup.missingMedia.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.backupMissingHint),
            for (final item in backup.missingMedia)
              Text(_missingLabel(item, l10n)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('restore_backup'),
              onPressed: _busy || service.requiresRecovery ? null : _restore,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.all(14),
              ),
              icon: const Icon(Icons.restore),
              label: Text(
                l10n.backupConfirmRestore,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
