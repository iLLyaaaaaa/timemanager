// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Study Assistant';

  @override
  String get todayStudy => 'Today\'s Study';

  @override
  String get studyStatistics => 'Study Statistics';

  @override
  String get settings => 'Settings';

  @override
  String get home => 'Home';

  @override
  String get statistics => 'Statistics';

  @override
  String get managePlans => 'Manage Plans';

  @override
  String get editHomeHeadline => 'Edit Home Message';

  @override
  String get homeHeadline => 'Home Message';

  @override
  String get homeHeadlineHint => 'Write a short encouragement';

  @override
  String get homeHeadlineRequired => 'Enter a short message';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get headlineSaveFailed =>
      'Could not save the home message. Please try again.';

  @override
  String get todayPlan => 'Today\'s Plan';

  @override
  String get planLoadFailed =>
      'Could not load plans. Check local data before making changes.';

  @override
  String get noPlansHome => 'No study plans yet. Tap Manage Plans to add one.';

  @override
  String get noPlans => 'No study plans yet';

  @override
  String get viewProgress => 'View Progress';

  @override
  String get continueStudy => 'Continue';

  @override
  String get startStudy => 'Start Studying';

  @override
  String get planManagement => 'Plan Management';

  @override
  String get bulkDeleteTitle => 'Delete Selected Plans?';

  @override
  String get delete => 'Delete';

  @override
  String get deleteSaveFailed =>
      'Could not save the deletion. Please try again.';

  @override
  String get timerSettingSaveFailed =>
      'Could not save the timer setting. Please try again.';

  @override
  String get deletePlanTitle => 'Delete Plan?';

  @override
  String get undo => 'Undo';

  @override
  String get done => 'Done';

  @override
  String get bulkManage => 'Select Plans';

  @override
  String get noPlansManage => 'No plans yet. Tap Add Plan to get started.';

  @override
  String get backgroundPause => 'Auto-pause in Background';

  @override
  String get enableBackgroundPause => 'Enable background auto-pause';

  @override
  String get disableBackgroundPause => 'Disable background auto-pause';

  @override
  String get addPlan => 'Add Plan';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get editPlan => 'Edit Plan';

  @override
  String get planName => 'Plan Name';

  @override
  String get planNameHint => 'For example: Reading, Python, Fitness';

  @override
  String get planNameRequired => 'Enter a plan name';

  @override
  String get dailyPlanDuration => 'Daily Plan Duration';

  @override
  String get savePlan => 'Save Plan';

  @override
  String get chooseIcon => 'Choose Icon';

  @override
  String get hours => 'Hours';

  @override
  String get minutes => 'Minutes';

  @override
  String get seconds => 'Seconds';

  @override
  String get durationEmpty => 'Enter hours, minutes, and seconds';

  @override
  String get durationNonnegative => 'Use non-negative whole numbers only';

  @override
  String get durationTooLarge => 'Duration is too large';

  @override
  String get durationRange => 'Minutes and seconds must be 0–59';

  @override
  String get durationPositive => 'Duration must exceed 0 seconds';

  @override
  String get todayOverview => 'Today\'s Overview';

  @override
  String get planProgress => 'Plan Progress';

  @override
  String get studyTimer => 'Study Timer';

  @override
  String get planMissing => 'This plan no longer exists';

  @override
  String get adjustTime => 'Adjust Time';

  @override
  String get newRemainingTime => 'New Remaining Time';

  @override
  String get timeSaveFailed =>
      'Could not save study progress. Please try again.';

  @override
  String get remainingTime => 'Time Remaining';

  @override
  String get studiedTime => 'Time Studied';

  @override
  String get completedToday => 'Today\'s plan is complete';

  @override
  String get focusEncouragement => 'Stay focused. Keep going!';

  @override
  String get pause => 'Pause';

  @override
  String get start => 'Start';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get followSystem => 'Follow System';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get language => 'Language';

  @override
  String get chinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get timing => 'Timer';

  @override
  String get backgroundPauseHint =>
      'Set this separately for each plan in Manage Plans';

  @override
  String get dailyResetTime => 'Daily Reset Time';

  @override
  String get planSection => 'Plans';

  @override
  String get defaultPlanDuration => 'Default New Plan Duration';

  @override
  String get defaultDuration => 'Default Duration';

  @override
  String get confirmBeforeDelete => 'Confirm Before Deleting';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get restoreDefaults => 'Restore Default Settings';

  @override
  String get clearStudyData => 'Clear Study Data';

  @override
  String get clearAllData => 'Clear All Data';

  @override
  String get settingsSaveFailed => 'Could not save settings. Please try again.';

  @override
  String get restoreDefaultsTitle => 'Restore Default Settings?';

  @override
  String get restoreDefaultsMessage =>
      'Only settings will be restored. Plans and history stay.';

  @override
  String get restore => 'Restore';

  @override
  String get clearStudyTitle => 'Clear Study Data?';

  @override
  String get clearStudyMessage =>
      'This deletes today\'s progress and all study history, but keeps plans. This cannot be undone.';

  @override
  String get studyDataSaveFailed =>
      'Could not save study data. Please try again.';

  @override
  String get clearAllTitle => 'Clear All Data?';

  @override
  String get clearAllMessage =>
      'All plans, records, and settings will return to their initial state. This cannot be undone.';

  @override
  String get continueAction => 'Continue';

  @override
  String get clearAllAgainTitle => 'Confirm Clear All Data Again';

  @override
  String get clearAllAgainMessage =>
      'Confirm: all custom plans and study records will be deleted.';

  @override
  String get confirmClear => 'Clear Everything';

  @override
  String get dataSaveFailed => 'Could not save all data. Please try again.';

  @override
  String get timerAlert => 'Timer Alert';

  @override
  String get alertMode => 'Alert Mode';

  @override
  String get sound => 'Sound';

  @override
  String get vibration => 'Vibration';

  @override
  String get none => 'None';

  @override
  String get alertSound => 'Alert Sound';

  @override
  String get preview => 'Preview';

  @override
  String get sound1 => 'Soft Bell';

  @override
  String get sound2 => 'Clear Bell';

  @override
  String get sound3 => 'Digital';

  @override
  String get sound4 => 'Gentle Chime';

  @override
  String get sound5 => 'Short Beep';

  @override
  String get notificationPermissionHint =>
      'Notification or exact alarm access is off. Background completion alerts may be delayed or unavailable.';

  @override
  String get notificationPermissionAction => 'Enable Notifications';

  @override
  String get studyCompleteTitle => 'Study Session Complete';

  @override
  String get completeSnack => 'Great work! Today\'s study plan is complete!';

  @override
  String get iconLanguage => 'Language';

  @override
  String get iconTranslate => 'Translate';

  @override
  String get iconTextbook => 'Textbook';

  @override
  String get iconSpeaking => 'Speaking';

  @override
  String get iconCalculate => 'Calculate';

  @override
  String get iconFunctions => 'Functions';

  @override
  String get iconScience => 'Science';

  @override
  String get iconAnalytics => 'Analytics';

  @override
  String get iconCode => 'Code';

  @override
  String get iconTerminal => 'Terminal';

  @override
  String get iconComputer => 'Computer';

  @override
  String get iconDevelopment => 'Development';

  @override
  String get iconMemory => 'Memory';

  @override
  String get iconBook => 'Book';

  @override
  String get iconReading => 'Reading';

  @override
  String get iconLibrary => 'Library';

  @override
  String get iconFitness => 'Fitness';

  @override
  String get iconRunning => 'Running';

  @override
  String get iconSports => 'Sports';

  @override
  String get iconMusic => 'Music';

  @override
  String get iconHeadphones => 'Headphones';

  @override
  String get iconChecklist => 'Checklist';

  @override
  String get iconSchedule => 'Schedule';

  @override
  String get iconWork => 'Work';

  @override
  String get iconSchool => 'School';

  @override
  String get iconPsychology => 'Thinking';

  @override
  String get iconLightbulb => 'Ideas';

  @override
  String get iconStar => 'Star';

  @override
  String get iconFavorite => 'Favorite';

  @override
  String get iconFlag => 'Goal';

  @override
  String get iconBolt => 'Energy';

  @override
  String get iconOther => 'Other';

  @override
  String homeSummary(int count, String duration) {
    return '$count study plans today · $duration';
  }

  @override
  String todayRemainingDuration(String duration) {
    return 'Remaining today $duration';
  }

  @override
  String todayPlanDuration(String duration) {
    return 'Today\'s plan $duration';
  }

  @override
  String planDuration(String duration) {
    return 'Plan $duration';
  }

  @override
  String dailyPlanValue(String duration) {
    return 'Daily plan $duration';
  }

  @override
  String bulkDeleteConfirm(int count) {
    return 'Delete the $count selected plans?';
  }

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String backgroundPauseEnabledCount(int count) {
    return 'Background auto-pause enabled for $count plans.';
  }

  @override
  String backgroundPauseDisabledCount(int count) {
    return 'Background auto-pause disabled for $count plans.';
  }

  @override
  String deletePlanConfirm(String planName) {
    return 'Delete the “$planName” plan?';
  }

  @override
  String deletedPlan(String planName) {
    return 'Deleted “$planName”';
  }

  @override
  String editPlanTooltip(String planName) {
    return 'Edit $planName';
  }

  @override
  String deletePlanTooltip(String planName) {
    return 'Delete $planName';
  }

  @override
  String deleteSelected(int count) {
    return 'Delete Selected ($count)';
  }

  @override
  String currentIcon(String label) {
    return 'Current: $label';
  }

  @override
  String currentRemaining(String duration) {
    return 'Current remaining $duration';
  }

  @override
  String todayPlanTotal(String duration) {
    return 'Today\'s planned duration $duration';
  }

  @override
  String overviewPlanned(String duration) {
    return 'Total planned today: $duration';
  }

  @override
  String overviewStudied(String duration) {
    return 'Studied today: $duration';
  }

  @override
  String overviewRemaining(String duration) {
    return 'Remaining today: $duration';
  }

  @override
  String overviewCompletion(String percent) {
    return 'Today\'s completion: $percent';
  }

  @override
  String statPlanned(String duration) {
    return 'Planned: $duration';
  }

  @override
  String statStudied(String duration) {
    return 'Studied: $duration';
  }

  @override
  String statRemaining(String duration) {
    return 'Remaining: $duration';
  }

  @override
  String statOver(String duration) {
    return 'Over plan: $duration';
  }

  @override
  String notificationBody(String planName) {
    return '“$planName” timer has finished';
  }

  @override
  String get defaultHomeHeadline => 'A little progress every day';

  @override
  String get chooseLocalImage => 'Choose image from device';

  @override
  String get invalidLocalImage =>
      'Choose a valid PNG, JPEG, or WebP image under 8 MB.';

  @override
  String get chooseLocalSound => 'Choose from device';

  @override
  String get invalidLocalSound =>
      'This audio file cannot be used. Please choose a supported audio format.';

  @override
  String get ncmUnsupported =>
      'This NCM file cannot be used directly as an alert sound. Please choose a standard audio file such as MP3, WAV, M4A, or OGG.';

  @override
  String get cropImage => 'Crop image';

  @override
  String get trimSound => 'Trim alert sound';

  @override
  String get audioDuration => 'Total duration';

  @override
  String get audioStart => 'Start';

  @override
  String get audioEnd => 'End';

  @override
  String get clipLength => 'Selection length';

  @override
  String get saveClip => 'Save clip';

  @override
  String get customSound => 'Custom sound';

  @override
  String get previewFailed => 'This sound could not be played.';

  @override
  String get customSoundBackgroundFallback =>
      'Background and lock-screen alerts try the custom sound; if a notification sound URI is unavailable, the selected built-in sound is used.';

  @override
  String get backgroundPauseUpdatedHint =>
      'Pause when switching apps. Locking the screen keeps the timer running.';
}
