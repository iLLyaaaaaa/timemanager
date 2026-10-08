import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../data/study_plan_store.dart';
import '../l10n/app_localizations.dart';

class SaveRetryBanner extends StatefulWidget {
  const SaveRetryBanner({
    super.key,
    required this.store,
    required this.settings,
    this.enabled = true,
  });
  final StudyPlanStore store;
  final SettingsStore settings;
  final bool enabled;
  @override
  State<SaveRetryBanner> createState() => _SaveRetryBannerState();
}

class _SaveRetryBannerState extends State<SaveRetryBanner> {
  bool _retrying = false;
  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await Future.wait([
        widget.store.retrySave(),
        widget.settings.retrySave(),
      ]);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.store, widget.settings]),
    builder: (context, _) {
      if (!widget.store.hasSaveError && !widget.settings.hasSaveError) {
        return const SizedBox.shrink();
      }
      final l10n = AppLocalizations.of(context)!;
      final saving =
          _retrying || widget.store.isSaving || widget.settings.isSaving;
      return Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Semantics(liveRegion: true, child: Text(l10n.unsavedDataHint)),
              OutlinedButton(
                key: const ValueKey('retry_save'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: saving || !widget.enabled ? null : _retry,
                child: Text(saving ? l10n.retryingSave : l10n.retrySave),
              ),
            ],
          ),
        ),
      );
    },
  );
}
