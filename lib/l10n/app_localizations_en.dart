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
  String get noPlansHome =>
      'No study plans yet. Create a small goal to start today\'s learning.';

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
  String get backgroundPause => 'Background auto-pause';

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

  @override
  String get statisticsToday => 'Today';

  @override
  String get recentWeek => 'Last 7 days';

  @override
  String get historyTotal => 'Total studied in the last 7 days';

  @override
  String historyActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Studied on $count of 7 days',
      one: 'Studied on 1 of 7 days',
      zero: 'No study days yet',
    );
    return '$_temp0';
  }

  @override
  String historyDateRange(String startDate, String endDate) {
    return '$startDate – $endDate';
  }

  @override
  String get dailyStudyDuration => 'Daily study time';

  @override
  String get noRecentStudy =>
      'No study time recorded in the last 7 days. Start a session to build your history.';

  @override
  String get historyExplanation =>
      'Study days follow your daily reset time. Records from deleted plans are included.';

  @override
  String get historyBarExplanation =>
      'Bar lengths are relative to the longest study day in these 7 days.';

  @override
  String get plannedTime => 'Planned time';

  @override
  String get completedPlans => 'Completed plans';

  @override
  String completedPlansValue(int completed, int total) {
    return '$completed / $total';
  }

  @override
  String get timerReadyState => 'Ready to start';

  @override
  String get timerRunningState => 'In progress';

  @override
  String get timerPausedState => 'Paused';

  @override
  String get timerCompleteState => 'Complete';

  @override
  String get backgroundPauseSettingHint =>
      'Set this separately for each plan in Plan Management. Switching apps pauses enabled plans; locking the screen keeps the timer running.';

  @override
  String get planDetails => 'Plan details';

  @override
  String get customPlanImage => 'Custom image selected';

  @override
  String get savingPlan => 'Saving…';

  @override
  String get discardPlanTitle => 'Discard changes?';

  @override
  String get discardPlanMessage =>
      'Your changes to this plan have not been saved.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get planNotPersistedTitle =>
      'Changes haven\'t been saved to this device';

  @override
  String get planNotPersistedMessage =>
      'The plan is still available in memory, but your changes may be lost if you leave and the app closes. Keep editing to retry saving.';

  @override
  String get leavePage => 'Leave';

  @override
  String get planFollowUpFailed =>
      'The plan was saved, but some follow-up actions failed. Please retry.';

  @override
  String planCompletion(String percentage) {
    return 'Completion: $percentage';
  }

  @override
  String get searchPlans => 'Search plan names';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get filterAllPlans => 'All';

  @override
  String get filterNotStarted => 'Not started';

  @override
  String get filterInProgress => 'In progress';

  @override
  String get filterCompleted => 'Completed';

  @override
  String planFilterCount(String label, int count) {
    return '$label · $count';
  }

  @override
  String get noMatchingPlans =>
      'No matching plans. Try another name or status.';

  @override
  String get resetPlanFilters => 'Show all plans';

  @override
  String get bulkAllPlansHint =>
      'All plans are shown for bulk selection. Your search and filters return when you finish.';

  @override
  String get runningPlanHint => 'Your timer is running';

  @override
  String get pickUpPlanHint => 'Pick up an unfinished plan';

  @override
  String get openRunningTimer => 'Open timer';

  @override
  String get allPlansCompleted =>
      'All of today\'s plans are complete. Your progress is saved in Statistics.';

  @override
  String get historyDailyAverage => 'Daily average';

  @override
  String get historyBestDay => 'Highest daily total';

  @override
  String historyBestDayDate(String date) {
    return 'Highest study day: $date';
  }

  @override
  String get historyAverageExplanation =>
      'The average includes all 7 study days, including days with no recorded study.';

  @override
  String get studyReview => 'Study Review';

  @override
  String get reviewCalendar => 'Calendar';

  @override
  String get reviewRange => 'Date range';

  @override
  String get reviewCurrentStreak => 'Current streak';

  @override
  String get reviewLongestStreak => 'Longest streak';

  @override
  String reviewStudyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get reviewNotStudiedToday =>
      'No study recorded today yet. Your streak can continue today.';

  @override
  String get reviewNoHistory =>
      'No study history yet. Start studying to build your review.';

  @override
  String get reviewStreakExplanation =>
      'Any actual study time counts as a study day. Until today ends, a streak ending yesterday is kept. Study days follow your daily reset time.';

  @override
  String get reviewMonthTotal => 'Month total';

  @override
  String get reviewActiveDays => 'Study days';

  @override
  String get reviewPreviousMonth => 'Previous month';

  @override
  String get reviewNextMonth => 'Next month';

  @override
  String get reviewBackToMonth => 'Back to this month';

  @override
  String get reviewHeatNone => '0';

  @override
  String get reviewHeat15 => '≤15 min';

  @override
  String get reviewHeat30 => '≤30 min';

  @override
  String get reviewHeat60 => '≤60 min';

  @override
  String get reviewHeatOver60 => '>60 min';

  @override
  String reviewDayDescription(String date, String duration) {
    return '$date: studied $duration';
  }

  @override
  String reviewFutureDay(String date) {
    return '$date: future study day';
  }

  @override
  String get reviewFutureLabel => 'Upcoming';

  @override
  String get reviewNoDayRecords => 'No study time recorded on this day.';

  @override
  String reviewDayTotal(String duration) {
    return 'Total studied: $duration';
  }

  @override
  String reviewDeletedPlans(int count) {
    return 'Deleted plans ($count)';
  }

  @override
  String get reviewLast30Days => 'Last 30 days';

  @override
  String get reviewThisMonth => 'This month';

  @override
  String get reviewCustomRange => 'Custom';

  @override
  String get reviewTotal => 'Total studied';

  @override
  String reviewAverageExplanation(int count) {
    return 'The average includes all $count calendar study days in this range, including days with no recorded study.';
  }

  @override
  String get reviewRecordNamesHint =>
      'Existing plans show their current names. Deleted plans are combined and their study time is kept.';

  @override
  String get reviewClose => 'Close';
}
