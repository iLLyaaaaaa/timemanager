import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/study_duration.dart';
import 'study_duration_input.dart';

/// Edits a proposed duration; only confirmation updates the live plan.
class StudyTimeAdjustmentDialog extends StatefulWidget {
  const StudyTimeAdjustmentDialog({
    super.key,
    required this.initialSeconds,
    required this.onApply,
    this.resumeAfterwards = false,
  });

  final int initialSeconds;
  final Future<String?> Function(int) onApply;
  final bool resumeAfterwards;

  @override
  State<StudyTimeAdjustmentDialog> createState() =>
      _StudyTimeAdjustmentDialogState();
}

class _StudyTimeAdjustmentDialogState extends State<StudyTimeAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _durationKey = GlobalKey<StudyDurationInputState>();
  late int? _seconds = widget.initialSeconds > 0 ? widget.initialSeconds : null;
  bool _submitting = false;
  String? _error;

  Future<void> _apply() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) {
      _durationKey.currentState!.focusInvalidPart();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final error = await widget.onApply(
        _durationKey.currentState!.totalSeconds!,
      );
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = error);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context)!.timeSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // AlertDialog measures intrinsic sizes, so calculate the responsive form
    // width without a LayoutBuilder inside its content.
    final media = MediaQuery.of(context);
    final contentWidth =
        media.size.width -
        media.padding.horizontal -
        media.viewInsets.horizontal -
        128;
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        key: const ValueKey('adjust_time_dialog'),
        title: Text(l10n.adjustTime),
        scrollable: true,
        content: SizedBox(
          width: 360,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.currentRemaining(
                    formatStudyDuration(widget.initialSeconds),
                  ),
                ),
                if (widget.resumeAfterwards) ...[
                  const SizedBox(height: 8),
                  Text(l10n.timerAdjustResumeHint),
                ],
                const SizedBox(height: 16),
                StudyDurationInput(
                  key: _durationKey,
                  initialSeconds: widget.initialSeconds,
                  label: l10n.newRemainingTime,
                  enabled: !_submitting,
                  stacked:
                      contentWidth < 320 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.2,
                  onChanged: (seconds) => setState(() => _seconds = seconds),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutes in [1, 5, 15])
                      OutlinedButton(
                        key: ValueKey('add_time_$minutes'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed:
                            _submitting ||
                                _seconds == null ||
                                _seconds! > 0x7fffffffffffffff - minutes * 60
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                _durationKey.currentState!.setTotalSeconds(
                                  _seconds! + minutes * 60,
                                );
                              },
                        child: Text(l10n.addStudyMinutes(minutes)),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancel_adjust_time'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm_adjust_time'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _submitting ? null : _apply,
            child: Semantics(
              liveRegion: true,
              child: Text(_submitting ? l10n.timerSavingTime : l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}
