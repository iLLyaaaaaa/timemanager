String formatStudyDuration(int seconds) {
  assert(seconds >= 0);
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = remainder.toString().padLeft(2, '0');
  if (hours == 0) return '$minuteText:$secondText';
  return '${hours.toString().padLeft(2, '0')}:$minuteText:$secondText';
}
