import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

class StudyDurationInput extends StatefulWidget {
  const StudyDurationInput({
    super.key,
    required this.initialSeconds,
    required this.label,
    this.onChanged,
    this.enabled = true,
    this.stacked = false,
  });

  final int initialSeconds;
  final String label;
  final ValueChanged<int?>? onChanged;
  final bool enabled;
  final bool stacked;

  @override
  State<StudyDurationInput> createState() => StudyDurationInputState();
}

class StudyDurationInputState extends State<StudyDurationInput> {
  late final TextEditingController _hours;
  late final TextEditingController _minutes;
  late final TextEditingController _seconds;
  final _hoursFocus = FocusNode();
  final _minutesFocus = FocusNode();
  final _secondsFocus = FocusNode();

  void focusFirstPart() => _hoursFocus.requestFocus();

  BuildContext? get focusedPartContext {
    for (final node in [_hoursFocus, _minutesFocus, _secondsFocus]) {
      if (node.hasFocus) return node.context;
    }
    return null;
  }

  void focusInvalidPart() {
    final controllers = [_hours, _minutes, _seconds];
    final nodes = [_hoursFocus, _minutesFocus, _secondsFocus];
    for (var index = 0; index < controllers.length; index++) {
      final value = int.tryParse(controllers[index].text);
      if (value == null || value < 0 || (index > 0 && value > 59)) {
        nodes[index].requestFocus();
        return;
      }
    }
    _hoursFocus.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _hours = TextEditingController(
      text: (widget.initialSeconds ~/ 3600).toString(),
    );
    _minutes = TextEditingController(
      text: ((widget.initialSeconds % 3600) ~/ 60).toString(),
    );
    _seconds = TextEditingController(
      text: (widget.initialSeconds % 60).toString(),
    );
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _seconds.dispose();
    _hoursFocus.dispose();
    _minutesFocus.dispose();
    _secondsFocus.dispose();
    super.dispose();
  }

  int? get totalSeconds {
    if (_validationError() != null) return null;
    return int.parse(_hours.text) * 3600 +
        int.parse(_minutes.text) * 60 +
        int.parse(_seconds.text);
  }

  String? _validationError() {
    final values = [_hours.text, _minutes.text, _seconds.text];
    if (values.any((value) => value.isEmpty)) return 'durationEmpty';
    if (values.any((value) => !RegExp(r'^\d+$').hasMatch(value))) {
      return 'durationNonnegative';
    }
    final hours = int.tryParse(values[0]);
    final minutes = int.tryParse(values[1]);
    final seconds = int.tryParse(values[2]);
    if (hours == null || minutes == null || seconds == null) {
      return 'durationTooLarge';
    }
    if (minutes > 59 || seconds > 59) return 'durationRange';
    const maxSeconds = 0x7fffffffffffffff;
    if (hours > (maxSeconds - minutes * 60 - seconds) ~/ 3600) {
      return 'durationTooLarge';
    }
    if (hours == 0 && minutes == 0 && seconds == 0) {
      return 'durationPositive';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String? localizedError() => switch (_validationError()) {
      'durationEmpty' => l10n.durationEmpty,
      'durationNonnegative' => l10n.durationNonnegative,
      'durationTooLarge' => l10n.durationTooLarge,
      'durationRange' => l10n.durationRange,
      'durationPositive' => l10n.durationPositive,
      _ => null,
    };
    return FormField<int>(
      initialValue: widget.initialSeconds,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) => localizedError(),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final parts = [
                _part(
                  _hours,
                  _hoursFocus,
                  _minutesFocus,
                  l10n.hours,
                  'duration_hours',
                  field,
                ),
                _part(
                  _minutes,
                  _minutesFocus,
                  _secondsFocus,
                  l10n.minutes,
                  'duration_minutes',
                  field,
                ),
                _part(
                  _seconds,
                  _secondsFocus,
                  null,
                  l10n.seconds,
                  'duration_seconds',
                  field,
                ),
              ];
              if (widget.stacked) {
                return Column(
                  children: [
                    for (var index = 0; index < parts.length; index++) ...[
                      if (index > 0) const SizedBox(height: 12),
                      parts[index],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var index = 0; index < parts.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(child: parts[index]),
                  ],
                ],
              );
            },
          ),
          if (field.hasError) ...[
            const SizedBox(height: 8),
            Text(
              field.errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _part(
    TextEditingController controller,
    FocusNode focusNode,
    FocusNode? nextFocus,
    String label,
    String key,
    FormFieldState<int> field,
  ) => TextField(
    key: ValueKey(key),
    controller: controller,
    focusNode: focusNode,
    enabled: widget.enabled,
    textInputAction: nextFocus == null
        ? TextInputAction.done
        : TextInputAction.next,
    onSubmitted: (_) =>
        nextFocus == null ? focusNode.unfocus() : nextFocus.requestFocus(),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    onChanged: (_) {
      final seconds = totalSeconds;
      field.didChange(seconds);
      widget.onChanged?.call(seconds);
    },
  );
}
