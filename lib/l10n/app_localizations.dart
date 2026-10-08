import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Assistant'**
  String get appTitle;

  /// No description provided for @todayStudy.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Study'**
  String get todayStudy;

  /// No description provided for @studyStatistics.
  ///
  /// In en, this message translates to:
  /// **'Study Statistics'**
  String get studyStatistics;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @managePlans.
  ///
  /// In en, this message translates to:
  /// **'Manage Plans'**
  String get managePlans;

  /// No description provided for @editHomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Edit Home Message'**
  String get editHomeHeadline;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Home Message'**
  String get homeHeadline;

  /// No description provided for @homeHeadlineHint.
  ///
  /// In en, this message translates to:
  /// **'Write a short encouragement'**
  String get homeHeadlineHint;

  /// No description provided for @homeHeadlineRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a short message'**
  String get homeHeadlineRequired;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @headlineSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the home message. Please try again.'**
  String get headlineSaveFailed;

  /// No description provided for @todayPlan.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Plan'**
  String get todayPlan;

  /// No description provided for @planLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load plans. Check local data before making changes.'**
  String get planLoadFailed;

  /// No description provided for @noPlansHome.
  ///
  /// In en, this message translates to:
  /// **'No study plans yet. Create a small goal to start today\'s learning.'**
  String get noPlansHome;

  /// No description provided for @noPlans.
  ///
  /// In en, this message translates to:
  /// **'No study plans yet'**
  String get noPlans;

  /// No description provided for @viewProgress.
  ///
  /// In en, this message translates to:
  /// **'View Progress'**
  String get viewProgress;

  /// No description provided for @continueStudy.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueStudy;

  /// No description provided for @startStudy.
  ///
  /// In en, this message translates to:
  /// **'Start Studying'**
  String get startStudy;

  /// No description provided for @planManagement.
  ///
  /// In en, this message translates to:
  /// **'Plan Management'**
  String get planManagement;

  /// No description provided for @bulkDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected Plans?'**
  String get bulkDeleteTitle;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the deletion. Please try again.'**
  String get deleteSaveFailed;

  /// No description provided for @deletePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Plan?'**
  String get deletePlanTitle;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @bulkManage.
  ///
  /// In en, this message translates to:
  /// **'Select Plans'**
  String get bulkManage;

  /// No description provided for @noPlansManage.
  ///
  /// In en, this message translates to:
  /// **'No plans yet. Tap Add Plan to get started.'**
  String get noPlansManage;

  /// No description provided for @backgroundPause.
  ///
  /// In en, this message translates to:
  /// **'Background auto-pause'**
  String get backgroundPause;

  /// No description provided for @addPlan.
  ///
  /// In en, this message translates to:
  /// **'Add Plan'**
  String get addPlan;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @editPlan.
  ///
  /// In en, this message translates to:
  /// **'Edit Plan'**
  String get editPlan;

  /// No description provided for @planName.
  ///
  /// In en, this message translates to:
  /// **'Plan Name'**
  String get planName;

  /// No description provided for @planNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Reading, Python, Fitness'**
  String get planNameHint;

  /// No description provided for @planNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a plan name'**
  String get planNameRequired;

  /// No description provided for @dailyPlanDuration.
  ///
  /// In en, this message translates to:
  /// **'Daily Plan Duration'**
  String get dailyPlanDuration;

  /// No description provided for @savePlan.
  ///
  /// In en, this message translates to:
  /// **'Save Plan'**
  String get savePlan;

  /// No description provided for @chooseIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose Icon'**
  String get chooseIcon;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get seconds;

  /// No description provided for @durationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter hours, minutes, and seconds'**
  String get durationEmpty;

  /// No description provided for @durationNonnegative.
  ///
  /// In en, this message translates to:
  /// **'Use non-negative whole numbers only'**
  String get durationNonnegative;

  /// No description provided for @durationTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Duration is too large'**
  String get durationTooLarge;

  /// No description provided for @durationRange.
  ///
  /// In en, this message translates to:
  /// **'Minutes and seconds must be 0–59'**
  String get durationRange;

  /// No description provided for @durationPositive.
  ///
  /// In en, this message translates to:
  /// **'Duration must exceed 0 seconds'**
  String get durationPositive;

  /// No description provided for @todayOverview.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Overview'**
  String get todayOverview;

  /// No description provided for @planProgress.
  ///
  /// In en, this message translates to:
  /// **'Plan Progress'**
  String get planProgress;

  /// No description provided for @studyTimer.
  ///
  /// In en, this message translates to:
  /// **'Study Timer'**
  String get studyTimer;

  /// No description provided for @planMissing.
  ///
  /// In en, this message translates to:
  /// **'This plan no longer exists'**
  String get planMissing;

  /// No description provided for @adjustTime.
  ///
  /// In en, this message translates to:
  /// **'Adjust Time'**
  String get adjustTime;

  /// No description provided for @newRemainingTime.
  ///
  /// In en, this message translates to:
  /// **'New Remaining Time'**
  String get newRemainingTime;

  /// No description provided for @timeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save study progress. Please try again.'**
  String get timeSaveFailed;

  /// No description provided for @remainingTime.
  ///
  /// In en, this message translates to:
  /// **'Time Remaining'**
  String get remainingTime;

  /// No description provided for @studiedTime.
  ///
  /// In en, this message translates to:
  /// **'Time Studied'**
  String get studiedTime;

  /// No description provided for @completedToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s plan is complete'**
  String get completedToday;

  /// No description provided for @focusEncouragement.
  ///
  /// In en, this message translates to:
  /// **'Stay focused. Keep going!'**
  String get focusEncouragement;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @timing.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timing;

  /// No description provided for @dailyResetTime.
  ///
  /// In en, this message translates to:
  /// **'Daily Reset Time'**
  String get dailyResetTime;

  /// No description provided for @planSection.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get planSection;

  /// No description provided for @defaultPlanDuration.
  ///
  /// In en, this message translates to:
  /// **'Default New Plan Duration'**
  String get defaultPlanDuration;

  /// No description provided for @defaultDuration.
  ///
  /// In en, this message translates to:
  /// **'Default Duration'**
  String get defaultDuration;

  /// No description provided for @confirmBeforeDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Before Deleting'**
  String get confirmBeforeDelete;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore Default Settings'**
  String get restoreDefaults;

  /// No description provided for @clearStudyData.
  ///
  /// In en, this message translates to:
  /// **'Clear Study Data'**
  String get clearStudyData;

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get clearAllData;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save settings. Please try again.'**
  String get settingsSaveFailed;

  /// No description provided for @restoreDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Default Settings?'**
  String get restoreDefaultsTitle;

  /// No description provided for @restoreDefaultsMessage.
  ///
  /// In en, this message translates to:
  /// **'Only settings will be restored. Plans and history stay.'**
  String get restoreDefaultsMessage;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @clearStudyTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Study Data?'**
  String get clearStudyTitle;

  /// No description provided for @clearStudyMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes today\'s progress and all study history, but keeps plans. This cannot be undone.'**
  String get clearStudyMessage;

  /// No description provided for @studyDataSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save study data. Please try again.'**
  String get studyDataSaveFailed;

  /// No description provided for @clearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data?'**
  String get clearAllTitle;

  /// No description provided for @clearAllMessage.
  ///
  /// In en, this message translates to:
  /// **'All plans, records, and settings will return to their initial state. This cannot be undone.'**
  String get clearAllMessage;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @clearAllAgainTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Clear All Data Again'**
  String get clearAllAgainTitle;

  /// No description provided for @clearAllAgainMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirm: all custom plans and study records will be deleted.'**
  String get clearAllAgainMessage;

  /// No description provided for @confirmClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Everything'**
  String get confirmClear;

  /// No description provided for @dataSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save all data. Please try again.'**
  String get dataSaveFailed;

  /// No description provided for @dataCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Plans, history and settings were cleared, but some local media or recovery copies could not be deleted. Try clearing again.'**
  String get dataCleanupFailed;

  /// No description provided for @timerAlert.
  ///
  /// In en, this message translates to:
  /// **'Timer Alert'**
  String get timerAlert;

  /// No description provided for @alertMode.
  ///
  /// In en, this message translates to:
  /// **'Alert Mode'**
  String get alertMode;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @alertSound.
  ///
  /// In en, this message translates to:
  /// **'Alert Sound'**
  String get alertSound;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @sound1.
  ///
  /// In en, this message translates to:
  /// **'Soft Bell'**
  String get sound1;

  /// No description provided for @sound2.
  ///
  /// In en, this message translates to:
  /// **'Clear Bell'**
  String get sound2;

  /// No description provided for @sound3.
  ///
  /// In en, this message translates to:
  /// **'Digital'**
  String get sound3;

  /// No description provided for @sound4.
  ///
  /// In en, this message translates to:
  /// **'Gentle Chime'**
  String get sound4;

  /// No description provided for @sound5.
  ///
  /// In en, this message translates to:
  /// **'Short Beep'**
  String get sound5;

  /// No description provided for @notificationPermissionHint.
  ///
  /// In en, this message translates to:
  /// **'Notification or exact alarm access is off. Background completion alerts may be delayed or unavailable.'**
  String get notificationPermissionHint;

  /// No description provided for @notificationPermissionAction.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get notificationPermissionAction;

  /// No description provided for @studyCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Session Complete'**
  String get studyCompleteTitle;

  /// No description provided for @completeSnack.
  ///
  /// In en, this message translates to:
  /// **'Great work! Today\'s study plan is complete!'**
  String get completeSnack;

  /// No description provided for @iconLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get iconLanguage;

  /// No description provided for @iconTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get iconTranslate;

  /// No description provided for @iconTextbook.
  ///
  /// In en, this message translates to:
  /// **'Textbook'**
  String get iconTextbook;

  /// No description provided for @iconSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get iconSpeaking;

  /// No description provided for @iconCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get iconCalculate;

  /// No description provided for @iconFunctions.
  ///
  /// In en, this message translates to:
  /// **'Functions'**
  String get iconFunctions;

  /// No description provided for @iconScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get iconScience;

  /// No description provided for @iconAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get iconAnalytics;

  /// No description provided for @iconCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get iconCode;

  /// No description provided for @iconTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get iconTerminal;

  /// No description provided for @iconComputer.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get iconComputer;

  /// No description provided for @iconDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get iconDevelopment;

  /// No description provided for @iconMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get iconMemory;

  /// No description provided for @iconBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get iconBook;

  /// No description provided for @iconReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get iconReading;

  /// No description provided for @iconLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get iconLibrary;

  /// No description provided for @iconFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get iconFitness;

  /// No description provided for @iconRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get iconRunning;

  /// No description provided for @iconSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get iconSports;

  /// No description provided for @iconMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get iconMusic;

  /// No description provided for @iconHeadphones.
  ///
  /// In en, this message translates to:
  /// **'Headphones'**
  String get iconHeadphones;

  /// No description provided for @iconChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get iconChecklist;

  /// No description provided for @iconSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get iconSchedule;

  /// No description provided for @iconWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get iconWork;

  /// No description provided for @iconSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get iconSchool;

  /// No description provided for @iconPsychology.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get iconPsychology;

  /// No description provided for @iconLightbulb.
  ///
  /// In en, this message translates to:
  /// **'Ideas'**
  String get iconLightbulb;

  /// No description provided for @iconStar.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get iconStar;

  /// No description provided for @iconFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get iconFavorite;

  /// No description provided for @iconFlag.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get iconFlag;

  /// No description provided for @iconBolt.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get iconBolt;

  /// No description provided for @iconOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get iconOther;

  /// No description provided for @homeSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} study plans today · {duration}'**
  String homeSummary(int count, String duration);

  /// No description provided for @todayRemainingDuration.
  ///
  /// In en, this message translates to:
  /// **'Remaining today {duration}'**
  String todayRemainingDuration(String duration);

  /// No description provided for @todayPlanDuration.
  ///
  /// In en, this message translates to:
  /// **'Today\'s plan {duration}'**
  String todayPlanDuration(String duration);

  /// No description provided for @planDuration.
  ///
  /// In en, this message translates to:
  /// **'Plan {duration}'**
  String planDuration(String duration);

  /// No description provided for @dailyPlanValue.
  ///
  /// In en, this message translates to:
  /// **'Daily plan {duration}'**
  String dailyPlanValue(String duration);

  /// No description provided for @bulkDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the {count} selected plans?'**
  String bulkDeleteConfirm(int count);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @deletePlanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the “{planName}” plan?'**
  String deletePlanConfirm(String planName);

  /// No description provided for @deletedPlan.
  ///
  /// In en, this message translates to:
  /// **'Deleted “{planName}”'**
  String deletedPlan(String planName);

  /// No description provided for @editPlanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit {planName}'**
  String editPlanTooltip(String planName);

  /// No description provided for @deletePlanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete {planName}'**
  String deletePlanTooltip(String planName);

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected ({count})'**
  String deleteSelected(int count);

  /// No description provided for @currentIcon.
  ///
  /// In en, this message translates to:
  /// **'Current: {label}'**
  String currentIcon(String label);

  /// No description provided for @currentRemaining.
  ///
  /// In en, this message translates to:
  /// **'Current remaining {duration}'**
  String currentRemaining(String duration);

  /// No description provided for @todayPlanTotal.
  ///
  /// In en, this message translates to:
  /// **'Today\'s planned duration {duration}'**
  String todayPlanTotal(String duration);

  /// No description provided for @overviewPlanned.
  ///
  /// In en, this message translates to:
  /// **'Total planned today: {duration}'**
  String overviewPlanned(String duration);

  /// No description provided for @overviewStudied.
  ///
  /// In en, this message translates to:
  /// **'Studied today: {duration}'**
  String overviewStudied(String duration);

  /// No description provided for @overviewRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining today: {duration}'**
  String overviewRemaining(String duration);

  /// No description provided for @overviewCompletion.
  ///
  /// In en, this message translates to:
  /// **'Today\'s completion: {percent}'**
  String overviewCompletion(String percent);

  /// No description provided for @statPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned: {duration}'**
  String statPlanned(String duration);

  /// No description provided for @statStudied.
  ///
  /// In en, this message translates to:
  /// **'Studied: {duration}'**
  String statStudied(String duration);

  /// No description provided for @statRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {duration}'**
  String statRemaining(String duration);

  /// No description provided for @statOver.
  ///
  /// In en, this message translates to:
  /// **'Over plan: {duration}'**
  String statOver(String duration);

  /// No description provided for @notificationBody.
  ///
  /// In en, this message translates to:
  /// **'“{planName}” timer has finished'**
  String notificationBody(String planName);

  /// No description provided for @defaultHomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'A little progress every day'**
  String get defaultHomeHeadline;

  /// No description provided for @chooseLocalImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image from device'**
  String get chooseLocalImage;

  /// No description provided for @invalidLocalImage.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid PNG, JPEG, or WebP image under 8 MB.'**
  String get invalidLocalImage;

  /// No description provided for @chooseLocalSound.
  ///
  /// In en, this message translates to:
  /// **'Choose from device'**
  String get chooseLocalSound;

  /// No description provided for @invalidLocalSound.
  ///
  /// In en, this message translates to:
  /// **'This audio file cannot be used. Please choose a supported audio format.'**
  String get invalidLocalSound;

  /// No description provided for @ncmUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This NCM file cannot be used directly as an alert sound. Please choose a standard audio file such as MP3, WAV, M4A, or OGG.'**
  String get ncmUnsupported;

  /// No description provided for @cropImage.
  ///
  /// In en, this message translates to:
  /// **'Crop image'**
  String get cropImage;

  /// No description provided for @trimSound.
  ///
  /// In en, this message translates to:
  /// **'Trim alert sound'**
  String get trimSound;

  /// No description provided for @audioDuration.
  ///
  /// In en, this message translates to:
  /// **'Total duration'**
  String get audioDuration;

  /// No description provided for @audioStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get audioStart;

  /// No description provided for @audioEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get audioEnd;

  /// No description provided for @clipLength.
  ///
  /// In en, this message translates to:
  /// **'Selection length'**
  String get clipLength;

  /// No description provided for @saveClip.
  ///
  /// In en, this message translates to:
  /// **'Save clip'**
  String get saveClip;

  /// No description provided for @customSound.
  ///
  /// In en, this message translates to:
  /// **'Custom sound'**
  String get customSound;

  /// No description provided for @previewFailed.
  ///
  /// In en, this message translates to:
  /// **'This sound could not be played.'**
  String get previewFailed;

  /// No description provided for @customSoundBackgroundFallback.
  ///
  /// In en, this message translates to:
  /// **'Background and lock-screen alerts try the custom sound; if a notification sound URI is unavailable, the selected built-in sound is used.'**
  String get customSoundBackgroundFallback;

  /// No description provided for @backgroundPauseUpdatedHint.
  ///
  /// In en, this message translates to:
  /// **'Pause when switching apps. Locking the screen keeps the timer running.'**
  String get backgroundPauseUpdatedHint;

  /// No description provided for @statisticsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statisticsToday;

  /// No description provided for @recentWeek.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get recentWeek;

  /// No description provided for @historyTotal.
  ///
  /// In en, this message translates to:
  /// **'Total studied in the last 7 days'**
  String get historyTotal;

  /// No description provided for @historyActiveDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No study days yet} =1{Studied on 1 of 7 days} other{Studied on {count} of 7 days}}'**
  String historyActiveDays(int count);

  /// No description provided for @historyDateRange.
  ///
  /// In en, this message translates to:
  /// **'{startDate} – {endDate}'**
  String historyDateRange(String startDate, String endDate);

  /// No description provided for @dailyStudyDuration.
  ///
  /// In en, this message translates to:
  /// **'Daily study time'**
  String get dailyStudyDuration;

  /// No description provided for @noRecentStudy.
  ///
  /// In en, this message translates to:
  /// **'No study time recorded in the last 7 days. Start a session to build your history.'**
  String get noRecentStudy;

  /// No description provided for @historyExplanation.
  ///
  /// In en, this message translates to:
  /// **'Study days follow your daily reset time. Records from deleted plans are included.'**
  String get historyExplanation;

  /// No description provided for @historyBarExplanation.
  ///
  /// In en, this message translates to:
  /// **'Bar lengths are relative to the longest study day in these 7 days.'**
  String get historyBarExplanation;

  /// No description provided for @plannedTime.
  ///
  /// In en, this message translates to:
  /// **'Planned time'**
  String get plannedTime;

  /// No description provided for @completedPlans.
  ///
  /// In en, this message translates to:
  /// **'Completed plans'**
  String get completedPlans;

  /// No description provided for @completedPlansValue.
  ///
  /// In en, this message translates to:
  /// **'{completed} / {total}'**
  String completedPlansValue(int completed, int total);

  /// No description provided for @timerReadyState.
  ///
  /// In en, this message translates to:
  /// **'Ready to start'**
  String get timerReadyState;

  /// No description provided for @timerRunningState.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get timerRunningState;

  /// No description provided for @timerPausedState.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get timerPausedState;

  /// No description provided for @timerCompleteState.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get timerCompleteState;

  /// No description provided for @backgroundPauseSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Set this separately for each plan in Plan Management. Switching apps pauses enabled plans; locking the screen keeps the timer running.'**
  String get backgroundPauseSettingHint;

  /// No description provided for @planDetails.
  ///
  /// In en, this message translates to:
  /// **'Plan details'**
  String get planDetails;

  /// No description provided for @customPlanImage.
  ///
  /// In en, this message translates to:
  /// **'Custom image selected'**
  String get customPlanImage;

  /// No description provided for @savingPlan.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get savingPlan;

  /// No description provided for @discardPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardPlanTitle;

  /// No description provided for @discardPlanMessage.
  ///
  /// In en, this message translates to:
  /// **'Your changes to this plan have not been saved.'**
  String get discardPlanMessage;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// No description provided for @planNotPersistedTitle.
  ///
  /// In en, this message translates to:
  /// **'Changes haven\'t been saved to this device'**
  String get planNotPersistedTitle;

  /// No description provided for @planNotPersistedMessage.
  ///
  /// In en, this message translates to:
  /// **'The plan is still available in memory, but your changes may be lost if you leave and the app closes. Keep editing to retry saving.'**
  String get planNotPersistedMessage;

  /// No description provided for @leavePage.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leavePage;

  /// No description provided for @planFollowUpFailed.
  ///
  /// In en, this message translates to:
  /// **'The plan was saved, but some follow-up actions failed. Please retry.'**
  String get planFollowUpFailed;

  /// No description provided for @planCompletion.
  ///
  /// In en, this message translates to:
  /// **'Completion: {percentage}'**
  String planCompletion(String percentage);

  /// No description provided for @searchPlans.
  ///
  /// In en, this message translates to:
  /// **'Search plan names'**
  String get searchPlans;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @filterAllPlans.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAllPlans;

  /// No description provided for @filterNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get filterNotStarted;

  /// No description provided for @filterInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get filterInProgress;

  /// No description provided for @filterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterCompleted;

  /// No description provided for @planFilterCount.
  ///
  /// In en, this message translates to:
  /// **'{label} · {count}'**
  String planFilterCount(String label, int count);

  /// No description provided for @noMatchingPlans.
  ///
  /// In en, this message translates to:
  /// **'No matching plans. Try another name or status.'**
  String get noMatchingPlans;

  /// No description provided for @resetPlanFilters.
  ///
  /// In en, this message translates to:
  /// **'Show all plans'**
  String get resetPlanFilters;

  /// No description provided for @bulkAllPlansHint.
  ///
  /// In en, this message translates to:
  /// **'All plans are shown for bulk selection. Your search and filters return when you finish.'**
  String get bulkAllPlansHint;

  /// No description provided for @runningPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Your timer is running'**
  String get runningPlanHint;

  /// No description provided for @pickUpPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Pick up an unfinished plan'**
  String get pickUpPlanHint;

  /// No description provided for @openRunningTimer.
  ///
  /// In en, this message translates to:
  /// **'Open timer'**
  String get openRunningTimer;

  /// No description provided for @allPlansCompleted.
  ///
  /// In en, this message translates to:
  /// **'All of today\'s plans are complete. Your progress is saved in Statistics.'**
  String get allPlansCompleted;

  /// No description provided for @historyDailyAverage.
  ///
  /// In en, this message translates to:
  /// **'Daily average'**
  String get historyDailyAverage;

  /// No description provided for @historyBestDay.
  ///
  /// In en, this message translates to:
  /// **'Highest daily total'**
  String get historyBestDay;

  /// No description provided for @historyBestDayDate.
  ///
  /// In en, this message translates to:
  /// **'Highest study day: {date}'**
  String historyBestDayDate(String date);

  /// No description provided for @historyAverageExplanation.
  ///
  /// In en, this message translates to:
  /// **'The average includes all 7 study days, including days with no recorded study.'**
  String get historyAverageExplanation;

  /// No description provided for @studyReview.
  ///
  /// In en, this message translates to:
  /// **'Study Review'**
  String get studyReview;

  /// No description provided for @reviewCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get reviewCalendar;

  /// No description provided for @reviewRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get reviewRange;

  /// No description provided for @reviewCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get reviewCurrentStreak;

  /// No description provided for @reviewLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get reviewLongestStreak;

  /// No description provided for @reviewStudyDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String reviewStudyDays(int count);

  /// No description provided for @reviewNotStudiedToday.
  ///
  /// In en, this message translates to:
  /// **'No study recorded today yet. Your streak can continue today.'**
  String get reviewNotStudiedToday;

  /// No description provided for @reviewNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No study history yet. Start studying to build your review.'**
  String get reviewNoHistory;

  /// No description provided for @reviewStreakExplanation.
  ///
  /// In en, this message translates to:
  /// **'Any actual study time counts as a study day. Until today ends, a streak ending yesterday is kept. Study days follow your daily reset time.'**
  String get reviewStreakExplanation;

  /// No description provided for @reviewMonthTotal.
  ///
  /// In en, this message translates to:
  /// **'Month total'**
  String get reviewMonthTotal;

  /// No description provided for @reviewActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Study days'**
  String get reviewActiveDays;

  /// No description provided for @reviewPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get reviewPreviousMonth;

  /// No description provided for @reviewNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get reviewNextMonth;

  /// No description provided for @reviewBackToMonth.
  ///
  /// In en, this message translates to:
  /// **'Back to this month'**
  String get reviewBackToMonth;

  /// No description provided for @reviewHeatNone.
  ///
  /// In en, this message translates to:
  /// **'0'**
  String get reviewHeatNone;

  /// No description provided for @reviewHeat15.
  ///
  /// In en, this message translates to:
  /// **'≤15 min'**
  String get reviewHeat15;

  /// No description provided for @reviewHeat30.
  ///
  /// In en, this message translates to:
  /// **'≤30 min'**
  String get reviewHeat30;

  /// No description provided for @reviewHeat60.
  ///
  /// In en, this message translates to:
  /// **'≤60 min'**
  String get reviewHeat60;

  /// No description provided for @reviewHeatOver60.
  ///
  /// In en, this message translates to:
  /// **'>60 min'**
  String get reviewHeatOver60;

  /// No description provided for @reviewDayDescription.
  ///
  /// In en, this message translates to:
  /// **'{date}: studied {duration}'**
  String reviewDayDescription(String date, String duration);

  /// No description provided for @reviewFutureDay.
  ///
  /// In en, this message translates to:
  /// **'{date}: future study day'**
  String reviewFutureDay(String date);

  /// No description provided for @reviewFutureLabel.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get reviewFutureLabel;

  /// No description provided for @reviewNoDayRecords.
  ///
  /// In en, this message translates to:
  /// **'No study time recorded on this day.'**
  String get reviewNoDayRecords;

  /// No description provided for @reviewDayTotal.
  ///
  /// In en, this message translates to:
  /// **'Total studied: {duration}'**
  String reviewDayTotal(String duration);

  /// No description provided for @reviewDeletedPlans.
  ///
  /// In en, this message translates to:
  /// **'Deleted plans ({count})'**
  String reviewDeletedPlans(int count);

  /// No description provided for @reviewLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get reviewLast30Days;

  /// No description provided for @reviewThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get reviewThisMonth;

  /// No description provided for @reviewCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get reviewCustomRange;

  /// No description provided for @reviewTotal.
  ///
  /// In en, this message translates to:
  /// **'Total studied'**
  String get reviewTotal;

  /// No description provided for @reviewAverageExplanation.
  ///
  /// In en, this message translates to:
  /// **'The average includes all {count} calendar study days in this range, including days with no recorded study.'**
  String reviewAverageExplanation(int count);

  /// No description provided for @reviewRecordNamesHint.
  ///
  /// In en, this message translates to:
  /// **'Existing plans show their current names. Deleted plans are combined and their study time is kept.'**
  String get reviewRecordNamesHint;

  /// No description provided for @reviewClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get reviewClose;

  /// No description provided for @reviewPeriodComparison.
  ///
  /// In en, this message translates to:
  /// **'Previous period comparison'**
  String get reviewPeriodComparison;

  /// No description provided for @reviewComparisonPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous {count} days: {start} – {end}'**
  String reviewComparisonPeriod(int count, String start, String end);

  /// No description provided for @reviewTimeIncreased.
  ///
  /// In en, this message translates to:
  /// **'Up {duration}'**
  String reviewTimeIncreased(String duration);

  /// No description provided for @reviewTimeDecreased.
  ///
  /// In en, this message translates to:
  /// **'Down {duration}'**
  String reviewTimeDecreased(String duration);

  /// No description provided for @reviewTimeUnchanged.
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get reviewTimeUnchanged;

  /// No description provided for @reviewChangePercent.
  ///
  /// In en, this message translates to:
  /// **'Change: {percent}'**
  String reviewChangePercent(String percent);

  /// No description provided for @reviewNoPreviousStudy.
  ///
  /// In en, this message translates to:
  /// **'No study time in the previous period; percentage change is unavailable.'**
  String get reviewNoPreviousStudy;

  /// No description provided for @reviewPreviousTotal.
  ///
  /// In en, this message translates to:
  /// **'Previous total: {duration}'**
  String reviewPreviousTotal(String duration);

  /// No description provided for @reviewPlanBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Plan time breakdown'**
  String get reviewPlanBreakdown;

  /// No description provided for @reviewBreakdownExplanation.
  ///
  /// In en, this message translates to:
  /// **'Sorted by actual study time. Shares include deleted plans.'**
  String get reviewBreakdownExplanation;

  /// No description provided for @reviewTimeShare.
  ///
  /// In en, this message translates to:
  /// **'Share: {percent}'**
  String reviewTimeShare(String percent);

  /// No description provided for @reviewAllPlanTimes.
  ///
  /// In en, this message translates to:
  /// **'View all ({count})'**
  String reviewAllPlanTimes(int count);

  /// No description provided for @reviewOnlyStudyDays.
  ///
  /// In en, this message translates to:
  /// **'Studied days only'**
  String get reviewOnlyStudyDays;

  /// No description provided for @reviewNoRangeStudy.
  ///
  /// In en, this message translates to:
  /// **'No study time recorded in this range.'**
  String get reviewNoRangeStudy;

  /// No description provided for @reviewRangeTotal.
  ///
  /// In en, this message translates to:
  /// **'Range total: {duration}'**
  String reviewRangeTotal(String duration);

  /// No description provided for @backupBusy.
  ///
  /// In en, this message translates to:
  /// **'A data operation is in progress. Please wait.'**
  String get backupBusy;

  /// No description provided for @backupCancelled.
  ///
  /// In en, this message translates to:
  /// **'Operation cancelled'**
  String get backupCancelled;

  /// No description provided for @backupConfirmRestore.
  ///
  /// In en, this message translates to:
  /// **'Confirm restore'**
  String get backupConfirmRestore;

  /// No description provided for @backupContinueExport.
  ///
  /// In en, this message translates to:
  /// **'Continue backup'**
  String get backupContinueExport;

  /// No description provided for @backupCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get backupCreatedAt;

  /// No description provided for @backupDescription.
  ///
  /// In en, this message translates to:
  /// **'Backups include plans, study history, settings, custom images and sounds in one JSON file for moving devices or reinstalling.'**
  String get backupDescription;

  /// No description provided for @backupExported.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupExported;

  /// No description provided for @backupExporting.
  ///
  /// In en, this message translates to:
  /// **'Preparing backup…'**
  String get backupExporting;

  /// No description provided for @backupHistoryRange.
  ///
  /// In en, this message translates to:
  /// **'Valid history range'**
  String get backupHistoryRange;

  /// No description provided for @backupInspecting.
  ///
  /// In en, this message translates to:
  /// **'Checking backup…'**
  String get backupInspecting;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'The backup is damaged or invalid. Current data was not replaced.'**
  String get backupInvalid;

  /// No description provided for @backupMedia.
  ///
  /// In en, this message translates to:
  /// **'Images and sounds'**
  String get backupMedia;

  /// No description provided for @backupMediaInvalid.
  ///
  /// In en, this message translates to:
  /// **'An image or sound in the backup cannot be read. Current data was not replaced.'**
  String get backupMediaInvalid;

  /// No description provided for @backupMissingHint.
  ///
  /// In en, this message translates to:
  /// **'All plans and records will be kept. Missing images or sounds will use built-in resources when restored.'**
  String get backupMissingHint;

  /// No description provided for @backupMissingSound.
  ///
  /// In en, this message translates to:
  /// **'Custom sound'**
  String get backupMissingSound;

  /// No description provided for @backupMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Some media files are missing'**
  String get backupMissingTitle;

  /// No description provided for @backupNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No valid history records'**
  String get backupNoHistory;

  /// No description provided for @backupNoPrevious.
  ///
  /// In en, this message translates to:
  /// **'No previous copy yet. Importing a backup will keep a copy of the data it replaces.'**
  String get backupNoPrevious;

  /// No description provided for @backupOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The operation failed. Your input and original data were kept. Please retry.'**
  String get backupOperationFailed;

  /// No description provided for @backupPausedHint.
  ///
  /// In en, this message translates to:
  /// **'Restored timers are paused. Time after the backup is not counted as study.'**
  String get backupPausedHint;

  /// No description provided for @backupPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get backupPlans;

  /// No description provided for @backupPreviousHint.
  ///
  /// In en, this message translates to:
  /// **'Only the copy from before the most recent successful replacement is kept. Clearing all data also deletes this copy.'**
  String get backupPreviousHint;

  /// No description provided for @backupPreviousUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The previous snapshots were unreadable. Their original contents were kept, but cannot be restored as a complete backup.'**
  String get backupPreviousUnreadable;

  /// No description provided for @backupReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Complete data could not be read. Resolve the loading error first. Original snapshots have been kept.'**
  String get backupReadFailed;

  /// No description provided for @backupRecords.
  ///
  /// In en, this message translates to:
  /// **'Study records'**
  String get backupRecords;

  /// No description provided for @backupRecovering.
  ///
  /// In en, this message translates to:
  /// **'Rolling back the unfinished restore…'**
  String get backupRecovering;

  /// No description provided for @backupRecoveryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Original data restored. You can continue.'**
  String get backupRecoveryCompleted;

  /// No description provided for @backupRecoveryNeeded.
  ///
  /// In en, this message translates to:
  /// **'Restore is unfinished. Original data and recovery files have been kept. Retry rollback before continuing.'**
  String get backupRecoveryNeeded;

  /// No description provided for @backupRestoreConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Current plans, history and settings will be replaced. A local copy of the current data will be kept so you can go back.'**
  String get backupRestoreConfirmMessage;

  /// No description provided for @backupRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace current data?'**
  String get backupRestoreConfirmTitle;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Data restored'**
  String get backupRestored;

  /// No description provided for @backupRestorePreview.
  ///
  /// In en, this message translates to:
  /// **'Restore preview'**
  String get backupRestorePreview;

  /// No description provided for @backupRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring. Please wait…'**
  String get backupRestoring;

  /// No description provided for @backupRetryRecovery.
  ///
  /// In en, this message translates to:
  /// **'Retry rollback'**
  String get backupRetryRecovery;

  /// No description provided for @backupSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Restore stopped because current changes could not be saved. Retry saving, or export the current data.'**
  String get backupSaveFirst;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get backupTitle;

  /// No description provided for @backupTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The backup exceeds 64 MiB. Reduce custom media and try again.'**
  String get backupTooLarge;

  /// No description provided for @backupVersionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This backup version is not supported. Use a compatible TimeManager version.'**
  String get backupVersionUnsupported;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore a backup'**
  String get importBackup;

  /// No description provided for @loadingDataFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load local data'**
  String get loadingDataFailed;

  /// No description provided for @loadingDataFailedHint.
  ///
  /// In en, this message translates to:
  /// **'Your original data has been kept. Retry or restore a backup.'**
  String get loadingDataFailedHint;

  /// No description provided for @loadingLocalData.
  ///
  /// In en, this message translates to:
  /// **'Loading local data…'**
  String get loadingLocalData;

  /// No description provided for @restorePreviousBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore data from before the last replacement'**
  String get restorePreviousBackup;

  /// No description provided for @retryingSave.
  ///
  /// In en, this message translates to:
  /// **'Retrying…'**
  String get retryingSave;

  /// No description provided for @retryLoading.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLoading;

  /// No description provided for @retrySave.
  ///
  /// In en, this message translates to:
  /// **'Retry saving'**
  String get retrySave;

  /// No description provided for @unsavedDataHint.
  ///
  /// In en, this message translates to:
  /// **'Changes have not been saved locally. Please retry.'**
  String get unsavedDataHint;

  /// No description provided for @localVersionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This local data version is not supported. Your original data has been kept. Use a compatible TimeManager version or restore a backup.'**
  String get localVersionUnsupported;

  /// No description provided for @resumeTimer.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get resumeTimer;

  /// No description provided for @returnHome.
  ///
  /// In en, this message translates to:
  /// **'Return home'**
  String get returnHome;

  /// No description provided for @timerStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the timer. Check the remaining duration and try again.'**
  String get timerStartFailed;

  /// No description provided for @timerAdjustResumeHint.
  ///
  /// In en, this message translates to:
  /// **'Timing pauses while you edit and continues when you close this panel.'**
  String get timerAdjustResumeHint;

  /// No description provided for @timerSavingTime.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get timerSavingTime;

  /// No description provided for @addStudyMinutes.
  ///
  /// In en, this message translates to:
  /// **'+{minutes} min'**
  String addStudyMinutes(int minutes);

  /// No description provided for @timerAdjustmentExpired.
  ///
  /// In en, this message translates to:
  /// **'The plan or learning day has changed. Close this panel and adjust the current plan again.'**
  String get timerAdjustmentExpired;

  /// No description provided for @timerUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress has not been saved'**
  String get timerUnsavedTitle;

  /// No description provided for @timerUnsavedExitHint.
  ///
  /// In en, this message translates to:
  /// **'Timing is paused. Your progress will stay in memory if you return home, where you can retry saving. Closing the app may lose these unsaved changes.'**
  String get timerUnsavedExitHint;

  /// No description provided for @stayOnTimer.
  ///
  /// In en, this message translates to:
  /// **'Stay here'**
  String get stayOnTimer;

  /// No description provided for @keepChangesAndReturn.
  ///
  /// In en, this message translates to:
  /// **'Keep changes and return'**
  String get keepChangesAndReturn;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
