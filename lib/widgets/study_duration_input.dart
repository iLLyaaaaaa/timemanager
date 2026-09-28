import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StudyDurationInput extends StatefulWidget {
  const StudyDurationInput({
    super.key,
    required this.initialSeconds,
    required this.label,
  });

  final int initialSeconds;
  final String label;

  @override
  State<StudyDurationInput> createState() => StudyDurationInputState();
}

class StudyDurationInputState extends State<StudyDurationInput> {
  late final TextEditingController _hours;
  late final TextEditingController _minutes;
  late final TextEditingController _seconds;

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
    if (values.any((value) => value.isEmpty)) return '请填写小时、分钟和秒';
    if (values.any((value) => !RegExp(r'^\d+$').hasMatch(value))) {
      return '时间只能输入非负整数';
    }
    final hours = int.tryParse(values[0]);
    final minutes = int.tryParse(values[1]);
    final seconds = int.tryParse(values[2]);
    if (hours == null || minutes == null || seconds == null) {
      return '时间数值过大，请缩短时长';
    }
    if (minutes > 59 || seconds > 59) return '分钟和秒须在 0 到 59 之间';
    const maxSeconds = 0x7fffffffffffffff;
    if (hours > (maxSeconds - minutes * 60 - seconds) ~/ 3600) {
      return '时间数值过大，请缩短时长';
    }
    if (hours == 0 && minutes == 0 && seconds == 0) {
      return '总时长必须大于 0 秒';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<int>(
      initialValue: widget.initialSeconds,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) => _validationError(),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              _part(_hours, '小时', 'duration_hours', field),
              const SizedBox(width: 8),
              _part(_minutes, '分钟', 'duration_minutes', field),
              const SizedBox(width: 8),
              _part(_seconds, '秒', 'duration_seconds', field),
            ],
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
    String label,
    String key,
    FormFieldState<int> field,
  ) => Expanded(
    child: TextField(
      key: ValueKey(key),
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => field.didChange(totalSeconds),
    ),
  );
}
