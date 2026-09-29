import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart' deferred as app_localizations_ar;
import 'app_localizations_de.dart' deferred as app_localizations_de;
import 'app_localizations_en.dart' deferred as app_localizations_en;
import 'app_localizations_es.dart' deferred as app_localizations_es;
import 'app_localizations_fr.dart' deferred as app_localizations_fr;
import 'app_localizations_he.dart' deferred as app_localizations_he;
import 'app_localizations_hi.dart' deferred as app_localizations_hi;
import 'app_localizations_sv.dart' deferred as app_localizations_sv;

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
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('he'),
    Locale('hi'),
    Locale('sv'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ROCI\'s Tasks'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

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

  /// No description provided for @materialTheme.
  ///
  /// In en, this message translates to:
  /// **'Material Theme'**
  String get materialTheme;

  /// No description provided for @useSystemColors.
  ///
  /// In en, this message translates to:
  /// **'Use system colors'**
  String get useSystemColors;

  /// No description provided for @amoledDarkMode.
  ///
  /// In en, this message translates to:
  /// **'AMOLED Dark Mode'**
  String get amoledDarkMode;

  /// No description provided for @pureBlackBackground.
  ///
  /// In en, this message translates to:
  /// **'Pure black background'**
  String get pureBlackBackground;

  /// No description provided for @dataAndSync.
  ///
  /// In en, this message translates to:
  /// **'Data & Sync'**
  String get dataAndSync;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @syncingTasks.
  ///
  /// In en, this message translates to:
  /// **'Syncing tasks...'**
  String get syncingTasks;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// No description provided for @sortAndFilter.
  ///
  /// In en, this message translates to:
  /// **'Sort & Filter'**
  String get sortAndFilter;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @createdDate.
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get createdDate;

  /// No description provided for @dueDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dueDateTime;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get moreOptions;

  /// No description provided for @fewerOptions.
  ///
  /// In en, this message translates to:
  /// **'Fewer Options'**
  String get fewerOptions;

  /// No description provided for @filterByCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by Category'**
  String get filterByCategory;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @showCompletedTasks.
  ///
  /// In en, this message translates to:
  /// **'Show Completed Tasks'**
  String get showCompletedTasks;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @timeFormat24h.
  ///
  /// In en, this message translates to:
  /// **'24h Time Format'**
  String get timeFormat24h;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @hebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get hebrew;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @swedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get swedish;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get newTask;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @noAttachmentsAdded.
  ///
  /// In en, this message translates to:
  /// **'No attachments added'**
  String get noAttachmentsAdded;

  /// No description provided for @attachmentsPremiumOnly.
  ///
  /// In en, this message translates to:
  /// **'Attachments are available with PRO.'**
  String get attachmentsPremiumOnly;

  /// No description provided for @dueDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Due Date & Time'**
  String get dueDateAndTime;

  /// No description provided for @noDateSelected.
  ///
  /// In en, this message translates to:
  /// **'No Date Selected'**
  String get noDateSelected;

  /// No description provided for @syncWithGoogleTasks.
  ///
  /// In en, this message translates to:
  /// **'Sync with Google Tasks'**
  String get syncWithGoogleTasks;

  /// No description provided for @syncWithGoogleTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Creates and syncs a task in Google Tasks'**
  String get syncWithGoogleTasksSubtitle;

  /// No description provided for @googleSignInRequiredForSync.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In is required to sync tasks.'**
  String get googleSignInRequiredForSync;

  /// No description provided for @calendarPermissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Calendar permission not granted'**
  String get calendarPermissionNotGranted;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No Category'**
  String get noCategory;

  /// No description provided for @saveTask.
  ///
  /// In en, this message translates to:
  /// **'Save Task'**
  String get saveTask;

  /// No description provided for @updateTask.
  ///
  /// In en, this message translates to:
  /// **'Update Task'**
  String get updateTask;

  /// No description provided for @pleaseEnterATitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterATitle;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @priorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priorityLabel;

  /// No description provided for @myTasks.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get myTasks;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get noCategoriesYet;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategory;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trashTitle;

  /// No description provided for @trashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashEmpty;

  /// No description provided for @restoredTask.
  ///
  /// In en, this message translates to:
  /// **'Restored {title}'**
  String restoredTask(String title);

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently?'**
  String get deletePermanently;

  /// No description provided for @actionUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get actionUndone;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get noTasksYet;

  /// No description provided for @duePrefix.
  ///
  /// In en, this message translates to:
  /// **'Due: '**
  String get duePrefix;

  /// No description provided for @deleteTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get deleteTaskTitle;

  /// No description provided for @deleteTaskConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this task?'**
  String get deleteTaskConfirmation;

  /// No description provided for @calendarColors.
  ///
  /// In en, this message translates to:
  /// **'Calendar Colors'**
  String get calendarColors;

  /// No description provided for @calendarColorThemingHint.
  ///
  /// In en, this message translates to:
  /// **'To customize calendar colors, open the Calendar Colors sheet (palette icon).'**
  String get calendarColorThemingHint;

  /// No description provided for @calendarFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar Filters'**
  String get calendarFiltersTitle;

  /// No description provided for @showCalendarTasks.
  ///
  /// In en, this message translates to:
  /// **'Show Tasks'**
  String get showCalendarTasks;

  /// No description provided for @showGoogleCalendar.
  ///
  /// In en, this message translates to:
  /// **'Show Google Calendar'**
  String get showGoogleCalendar;

  /// No description provided for @showRocisSchedule.
  ///
  /// In en, this message translates to:
  /// **'Show ROCIs Schedule'**
  String get showRocisSchedule;

  /// No description provided for @taskColor.
  ///
  /// In en, this message translates to:
  /// **'Task Color'**
  String get taskColor;

  /// No description provided for @googleCalendarColor.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar Color'**
  String get googleCalendarColor;

  /// No description provided for @scheduleColor.
  ///
  /// In en, this message translates to:
  /// **'ROCIs Schedule Color'**
  String get scheduleColor;

  /// No description provided for @assignmentColor.
  ///
  /// In en, this message translates to:
  /// **'Assignment Color'**
  String get assignmentColor;

  /// No description provided for @resetColors.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get resetColors;

  /// No description provided for @selectColor.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get selectColor;

  /// No description provided for @subcalendars.
  ///
  /// In en, this message translates to:
  /// **'Subcalendars'**
  String get subcalendars;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

  /// No description provided for @resetToGoogleDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Google Color'**
  String get resetToGoogleDefault;

  /// No description provided for @hexCode.
  ///
  /// In en, this message translates to:
  /// **'HEX Code'**
  String get hexCode;

  /// No description provided for @opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get opacity;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// No description provided for @expandCustomPicker.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get expandCustomPicker;

  /// No description provided for @noEnabledCalendars.
  ///
  /// In en, this message translates to:
  /// **'No enabled Google Calendars'**
  String get noEnabledCalendars;

  /// No description provided for @selectGoogleCalendars.
  ///
  /// In en, this message translates to:
  /// **'Select Google Calendars'**
  String get selectGoogleCalendars;

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

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncComplete;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupAndRestore;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data (JSON)'**
  String get exportData;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup your tasks and categories'**
  String get exportDataSubtitle;

  /// No description provided for @backupCopied.
  ///
  /// In en, this message translates to:
  /// **'Backup copied to clipboard!'**
  String get backupCopied;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data (JSON)'**
  String get importData;

  /// No description provided for @importDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a JSON backup'**
  String get importDataSubtitle;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get importBackup;

  /// No description provided for @pasteJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON backup here...'**
  String get pasteJsonHint;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Import complete!'**
  String get importComplete;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @privacyAndGdpr.
  ///
  /// In en, this message translates to:
  /// **'Privacy & GDPR'**
  String get privacyAndGdpr;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read our data security terms'**
  String get privacyPolicySubtitle;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account & Data'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove all your data'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent and will remove all your tasks, categories, and settings from our servers.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteEverything.
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get deleteEverything;

  /// No description provided for @deletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed. You may need to sign out and back in first for security.'**
  String get deletionFailed;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About ROCI\'s Tasks'**
  String get aboutApp;

  /// No description provided for @aboutAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App version, support, and info'**
  String get aboutAppSubtitle;

  /// No description provided for @aboutAppDescription.
  ///
  /// In en, this message translates to:
  /// **'ROCI\'s Tasks is designed to help you stay organized and productive. Built with Flutter, it provides a seamless experience for managing your daily tasks, categories, and schedule.'**
  String get aboutAppDescription;

  /// No description provided for @visitWebsite.
  ///
  /// In en, this message translates to:
  /// **'Visit our Website'**
  String get visitWebsite;

  /// No description provided for @viewGitHub.
  ///
  /// In en, this message translates to:
  /// **'GitHub Project'**
  String get viewGitHub;

  /// No description provided for @viewGitHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View the source code on GitHub'**
  String get viewGitHubSubtitle;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @rocisTasksPro.
  ///
  /// In en, this message translates to:
  /// **'ROCIs Tasks Pro'**
  String get rocisTasksPro;

  /// No description provided for @youAreProUser.
  ///
  /// In en, this message translates to:
  /// **'You are a Pro user!'**
  String get youAreProUser;

  /// No description provided for @unlockPremiumFeatures.
  ///
  /// In en, this message translates to:
  /// **'Unlock premium features'**
  String get unlockPremiumFeatures;

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription;

  /// No description provided for @manageSubscriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel or change your plan'**
  String get manageSubscriptionSubtitle;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @unlockFullPotential.
  ///
  /// In en, this message translates to:
  /// **'Unlock your full potential'**
  String get unlockFullPotential;

  /// No description provided for @unlimitedCategories.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Categories'**
  String get unlimitedCategories;

  /// No description provided for @unlimitedCategoriesDesc.
  ///
  /// In en, this message translates to:
  /// **'Create as many categories as you need to stay organized.'**
  String get unlimitedCategoriesDesc;

  /// No description provided for @premiumWidgets.
  ///
  /// In en, this message translates to:
  /// **'Premium Widgets'**
  String get premiumWidgets;

  /// No description provided for @premiumWidgetsDesc.
  ///
  /// In en, this message translates to:
  /// **'Access to Month and Full Calendar home screen widgets.'**
  String get premiumWidgetsDesc;

  /// No description provided for @subtasksAndChecklists.
  ///
  /// In en, this message translates to:
  /// **'Subtasks & Checklists'**
  String get subtasksAndChecklists;

  /// No description provided for @subtasksAndChecklistsDesc.
  ///
  /// In en, this message translates to:
  /// **'Break down complex tasks into smaller, manageable steps.'**
  String get subtasksAndChecklistsDesc;

  /// No description provided for @recurringTasks.
  ///
  /// In en, this message translates to:
  /// **'Recurring Tasks'**
  String get recurringTasks;

  /// No description provided for @recurringTasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Automate repeating tasks with daily, weekly, monthly, or custom schedules.'**
  String get recurringTasksDesc;

  /// No description provided for @viewPricingPlans.
  ///
  /// In en, this message translates to:
  /// **'View Pricing Plans'**
  String get viewPricingPlans;

  /// No description provided for @proSubscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Pro Subscription Active'**
  String get proSubscriptionActive;

  /// No description provided for @welcomeToPro.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pro!'**
  String get welcomeToPro;

  /// No description provided for @pickAPlan.
  ///
  /// In en, this message translates to:
  /// **'Pick a Plan'**
  String get pickAPlan;

  /// No description provided for @byContinuingAgreement.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our'**
  String get byContinuingAgreement;

  /// No description provided for @purchasesRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored successfully!'**
  String get purchasesRestored;

  /// No description provided for @noActiveSubscription.
  ///
  /// In en, this message translates to:
  /// **'No active subscription found for this account.'**
  String get noActiveSubscription;

  /// No description provided for @failedToRestore.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore purchases.'**
  String get failedToRestore;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @subtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get subtasks;

  /// No description provided for @noSubtasksAdded.
  ///
  /// In en, this message translates to:
  /// **'No subtasks added'**
  String get noSubtasksAdded;

  /// No description provided for @enterSubtask.
  ///
  /// In en, this message translates to:
  /// **'Enter subtask...'**
  String get enterSubtask;

  /// No description provided for @recurrence.
  ///
  /// In en, this message translates to:
  /// **'Recurrence'**
  String get recurrence;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @titleInvalidContent.
  ///
  /// In en, this message translates to:
  /// **'Title contains invalid content'**
  String get titleInvalidContent;

  /// No description provided for @descriptionInvalidContent.
  ///
  /// In en, this message translates to:
  /// **'Description contains invalid content'**
  String get descriptionInvalidContent;

  /// No description provided for @failedToSaveTask.
  ///
  /// In en, this message translates to:
  /// **'Failed to save task. Please try again.'**
  String get failedToSaveTask;

  /// No description provided for @welcomeToApp.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ROCI\'s Tasks'**
  String get welcomeToApp;

  /// No description provided for @signInToSync.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your tasks across devices'**
  String get signInToSync;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get signInFailed;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ROCI\'s Tasks'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeDesc.
  ///
  /// In en, this message translates to:
  /// **'Organize your life with efficiency and style.'**
  String get onboardingWelcomeDesc;

  /// No description provided for @onboardingSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync & Offline'**
  String get onboardingSyncTitle;

  /// No description provided for @onboardingSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Your tasks follow you everywhere. Access them even without an internet connection.'**
  String get onboardingSyncDesc;

  /// No description provided for @onboardingGesturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Gestures'**
  String get onboardingGesturesTitle;

  /// No description provided for @onboardingGesturesDesc.
  ///
  /// In en, this message translates to:
  /// **'Swipe left to delete, swipe right to complete. Long press for more options.'**
  String get onboardingGesturesDesc;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @searchTasksHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks...'**
  String get searchTasksHint;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash'**
  String get emptyTrash;

  /// No description provided for @productivityTrend.
  ///
  /// In en, this message translates to:
  /// **'Productivity Trend'**
  String get productivityTrend;

  /// No description provided for @categoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get categoryBreakdown;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @taskReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Reminder: {title}'**
  String taskReminderTitle(String title);

  /// No description provided for @taskDueNowBody.
  ///
  /// In en, this message translates to:
  /// **'You have a task due now!'**
  String get taskDueNowBody;

  /// No description provided for @createFirstTask.
  ///
  /// In en, this message translates to:
  /// **'Create your first task'**
  String get createFirstTask;

  /// No description provided for @filterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get filterToday;

  /// No description provided for @filterThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get filterThisWeek;

  /// No description provided for @filterOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get filterOverdue;

  /// No description provided for @filterNoDate.
  ///
  /// In en, this message translates to:
  /// **'No Date'**
  String get filterNoDate;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Filter'**
  String get dateRange;

  /// No description provided for @recurringTaskScheduled.
  ///
  /// In en, this message translates to:
  /// **'Recurring Task Scheduled'**
  String get recurringTaskScheduled;

  /// No description provided for @nextOccurrenceSet.
  ///
  /// In en, this message translates to:
  /// **'Next occurrence of \"{title}\" set for {date}'**
  String nextOccurrenceSet(String title, String date);

  /// No description provided for @initializationFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize app data. Please restart.'**
  String get initializationFailedError;

  /// No description provided for @noTaskDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No task data available'**
  String get noTaskDataAvailable;

  /// No description provided for @retryInitialization.
  ///
  /// In en, this message translates to:
  /// **'Retry Initialization'**
  String get retryInitialization;

  /// No description provided for @criticalErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'CRITICAL ERROR'**
  String get criticalErrorTitle;

  /// No description provided for @appStartupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'ROCI\'s Tasks encountered a problem during startup. Our team has been notified.'**
  String get appStartupErrorBody;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Dotting the i\'s and crossing the t\'s'**
  String get appTagline;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All Day'**
  String get allDay;

  /// No description provided for @event.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get event;

  /// No description provided for @markAsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Mark as incomplete'**
  String get markAsIncomplete;

  /// No description provided for @markAsComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark as complete'**
  String get markAsComplete;

  /// No description provided for @editTaskDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to edit task details'**
  String get editTaskDetailsHint;

  /// No description provided for @pinTask.
  ///
  /// In en, this message translates to:
  /// **'Pin task'**
  String get pinTask;

  /// No description provided for @unpinTask.
  ///
  /// In en, this message translates to:
  /// **'Unpin task'**
  String get unpinTask;

  /// No description provided for @notificationSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze 15m'**
  String get notificationSnooze;

  /// No description provided for @notificationMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark Completed'**
  String get notificationMarkCompleted;

  /// No description provided for @notificationOpenTask.
  ///
  /// In en, this message translates to:
  /// **'Open Task'**
  String get notificationOpenTask;

  /// No description provided for @notificationUncompletedTasks.
  ///
  /// In en, this message translates to:
  /// **'{count} Uncompleted Tasks'**
  String notificationUncompletedTasks(int count);

  /// No description provided for @notificationTasksRemaining.
  ///
  /// In en, this message translates to:
  /// **'Tasks Remaining'**
  String get notificationTasksRemaining;

  /// No description provided for @notificationTasksSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} Tasks'**
  String notificationTasksSummary(int count);

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @productivity.
  ///
  /// In en, this message translates to:
  /// **'Productivity'**
  String get productivity;

  /// No description provided for @smartAdd.
  ///
  /// In en, this message translates to:
  /// **'Smart Add (NLP)'**
  String get smartAdd;

  /// No description provided for @autoRemoveNlpDates.
  ///
  /// In en, this message translates to:
  /// **'Clean Title'**
  String get autoRemoveNlpDates;

  /// No description provided for @autoRemoveNlpDatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove date/time from title when suggested'**
  String get autoRemoveNlpDatesSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get passwordResetEmailSent;

  /// No description provided for @showTaskCounterNotification.
  ///
  /// In en, this message translates to:
  /// **'Show Task Counter'**
  String get showTaskCounterNotification;

  /// No description provided for @showTaskCounterNotificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display a persistent notification with your task count'**
  String get showTaskCounterNotificationSubtitle;

  /// No description provided for @showMyTasksGuideShortcut.
  ///
  /// In en, this message translates to:
  /// **'Show My Tasks help button'**
  String get showMyTasksGuideShortcut;

  /// No description provided for @showMyTasksGuideShortcutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a ? button in My Tasks that opens the App Guide'**
  String get showMyTasksGuideShortcutSubtitle;

  /// No description provided for @appGuide.
  ///
  /// In en, this message translates to:
  /// **'App Guide'**
  String get appGuide;

  /// No description provided for @appGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn how to use ROCI\'s Tasks'**
  String get appGuideSubtitle;

  /// No description provided for @appGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'App Guide'**
  String get appGuideTitle;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @howToUse.
  ///
  /// In en, this message translates to:
  /// **'How to Use'**
  String get howToUse;

  /// No description provided for @guideTaskDesc.
  ///
  /// In en, this message translates to:
  /// **'Create, edit, and organize your daily tasks with ease.'**
  String get guideTaskDesc;

  /// No description provided for @guideCalendarDesc.
  ///
  /// In en, this message translates to:
  /// **'View your tasks and events in a beautiful calendar view.'**
  String get guideCalendarDesc;

  /// No description provided for @guideCategoriesDesc.
  ///
  /// In en, this message translates to:
  /// **'Organize tasks into custom categories with unique icons and colors.'**
  String get guideCategoriesDesc;

  /// No description provided for @guidePriorityDesc.
  ///
  /// In en, this message translates to:
  /// **'Use priorities to highlight what matters most.'**
  String get guidePriorityDesc;

  /// No description provided for @guidePinningDesc.
  ///
  /// In en, this message translates to:
  /// **'Pin important tasks to keep them at the top of your list.'**
  String get guidePinningDesc;

  /// No description provided for @guideAttachmentsDesc.
  ///
  /// In en, this message translates to:
  /// **'Attach files and images to keep everything related to a task in one place.'**
  String get guideAttachmentsDesc;

  /// No description provided for @guideNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get guideNotificationsTitle;

  /// No description provided for @guideNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Stay on top of your schedule with smart reminders and a persistent task counter.'**
  String get guideNotificationsDesc;

  /// No description provided for @guideCloudSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get guideCloudSyncTitle;

  /// No description provided for @guideCloudSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your tasks between your phone and tasks.rocisapps.com. Settings also has Sync now, Trash, and a backup you can export or import.'**
  String get guideCloudSyncDesc;

  /// No description provided for @guideAddingTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Adding Tasks'**
  String get guideAddingTasksTitle;

  /// No description provided for @guideAddingTasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add a new task. Use natural language (e.g., \"Lunch tomorrow at 1pm\") for quick entry.'**
  String get guideAddingTasksDesc;

  /// No description provided for @guideGesturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get guideGesturesTitle;

  /// No description provided for @guideGesturesDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap a task to open it. Swipe right to complete it and left to delete it; deleted tasks wait in Trash, where you can restore them. Long-press a task to select several at once.'**
  String get guideGesturesDesc;

  /// No description provided for @guideWidgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Home Widgets'**
  String get guideWidgetsTitle;

  /// No description provided for @guideWidgetsDesc.
  ///
  /// In en, this message translates to:
  /// **'Long-press your home screen, open Widgets and pick ROCI\'s Tasks: task lists, today\'s agenda, the calendar or the board. Adjust their look in Settings.'**
  String get guideWidgetsDesc;

  /// No description provided for @guideCustomizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Customization'**
  String get guideCustomizationTitle;

  /// No description provided for @guideCustomizationDesc.
  ///
  /// In en, this message translates to:
  /// **'Personalize your experience in Settings with themes, language options, and more.'**
  String get guideCustomizationDesc;

  /// No description provided for @guideHappyOrganizing.
  ///
  /// In en, this message translates to:
  /// **'Happy Organizing!'**
  String get guideHappyOrganizing;

  /// No description provided for @notificationRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Task counter notification refreshed'**
  String get notificationRefreshed;

  /// No description provided for @privateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateLabel;

  /// No description provided for @privateCategory.
  ///
  /// In en, this message translates to:
  /// **'Private category'**
  String get privateCategory;

  /// No description provided for @privateCategorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide tasks from widgets and previews when locked'**
  String get privateCategorySubtitle;

  /// No description provided for @privateMode.
  ///
  /// In en, this message translates to:
  /// **'Private mode'**
  String get privateMode;

  /// No description provided for @privateModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide private categories when locked'**
  String get privateModeSubtitle;

  /// No description provided for @lockPrivate.
  ///
  /// In en, this message translates to:
  /// **'Lock private'**
  String get lockPrivate;

  /// No description provided for @unlockPrivate.
  ///
  /// In en, this message translates to:
  /// **'Unlock private'**
  String get unlockPrivate;

  /// No description provided for @hidePrivateCategories.
  ///
  /// In en, this message translates to:
  /// **'Hide private categories'**
  String get hidePrivateCategories;

  /// No description provided for @showPrivateCategories.
  ///
  /// In en, this message translates to:
  /// **'Show private categories'**
  String get showPrivateCategories;

  /// No description provided for @setPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get setPinTitle;

  /// No description provided for @pinMinDigits.
  ///
  /// In en, this message translates to:
  /// **'PIN (min 4 digits)'**
  String get pinMinDigits;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get confirmPin;

  /// No description provided for @enterPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPinTitle;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinLabel;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get wrongPin;

  /// No description provided for @pinsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get pinsDoNotMatch;

  /// No description provided for @advancedReminders.
  ///
  /// In en, this message translates to:
  /// **'Advanced reminders'**
  String get advancedReminders;

  /// No description provided for @advancedRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Extra snooze buttons on task reminders'**
  String get advancedRemindersSubtitle;

  /// No description provided for @nagReminders.
  ///
  /// In en, this message translates to:
  /// **'Nag reminders'**
  String get nagReminders;

  /// No description provided for @nagRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeat reminders after a task is due'**
  String get nagRemindersSubtitle;

  /// No description provided for @quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get quietHours;

  /// No description provided for @quietHoursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delay reminders during quiet hours'**
  String get quietHoursSubtitle;

  /// No description provided for @quietHoursStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get quietHoursStart;

  /// No description provided for @quietHoursEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get quietHoursEnd;

  /// No description provided for @nagInterval.
  ///
  /// In en, this message translates to:
  /// **'Nag interval'**
  String get nagInterval;

  /// No description provided for @nagCount.
  ///
  /// In en, this message translates to:
  /// **'Nag count'**
  String get nagCount;

  /// No description provided for @snooze10m.
  ///
  /// In en, this message translates to:
  /// **'Snooze 10m'**
  String get snooze10m;

  /// No description provided for @snooze1h.
  ///
  /// In en, this message translates to:
  /// **'Snooze 1h'**
  String get snooze1h;

  /// No description provided for @tomorrowAtNine.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow 9:00'**
  String get tomorrowAtNine;

  /// No description provided for @privateTask.
  ///
  /// In en, this message translates to:
  /// **'Private task'**
  String get privateTask;

  /// No description provided for @privateTaskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock private mode to view details.'**
  String get privateTaskSubtitle;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @accentColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize the app colors (Pro)'**
  String get accentColorSubtitle;

  /// No description provided for @requireSubTasksBeforeReminders.
  ///
  /// In en, this message translates to:
  /// **'Subtasks required'**
  String get requireSubTasksBeforeReminders;

  /// No description provided for @requireSubTasksBeforeRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The task can\'t be checked off until every subtask is done'**
  String get requireSubTasksBeforeRemindersSubtitle;

  /// No description provided for @debugModeUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Debug mode unlocked!'**
  String get debugModeUnlocked;

  /// No description provided for @submitBugReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Bug Report'**
  String get submitBugReport;

  /// No description provided for @submitBugReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill out our Google Form'**
  String get submitBugReportSubtitle;

  /// No description provided for @testCrash.
  ///
  /// In en, this message translates to:
  /// **'Test Crash'**
  String get testCrash;

  /// No description provided for @testCrashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate a crash for Crashlytics'**
  String get testCrashSubtitle;

  /// No description provided for @biometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Biometric Unlock'**
  String get biometricUnlock;

  /// No description provided for @biometricUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock private tasks with Face ID or fingerprint'**
  String get biometricUnlockSubtitle;

  /// No description provided for @useBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use Biometrics'**
  String get useBiometrics;

  /// No description provided for @biometricNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics not available on this device'**
  String get biometricNotAvailable;

  /// No description provided for @biometricAuthReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to access private tasks'**
  String get biometricAuthReason;

  /// No description provided for @usePinInstead.
  ///
  /// In en, this message translates to:
  /// **'Use PIN instead'**
  String get usePinInstead;

  /// No description provided for @securitySettings.
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get securitySettings;

  /// No description provided for @securitySettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage PIN and Biometric access'**
  String get securitySettingsSubtitle;

  /// No description provided for @enableSecurity.
  ///
  /// In en, this message translates to:
  /// **'Enable Security'**
  String get enableSecurity;

  /// No description provided for @enableSecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'You just created a private task. Set up a PIN or biometrics to keep your private content secure.'**
  String get enableSecurityDescription;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setUp;

  /// No description provided for @doNotRemind.
  ///
  /// In en, this message translates to:
  /// **'Do not remind'**
  String get doNotRemind;

  /// No description provided for @doNotRemindSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Suppress all notifications for this task'**
  String get doNotRemindSubtitle;

  /// No description provided for @glassmorphismEffects.
  ///
  /// In en, this message translates to:
  /// **'Glassmorphism Effects'**
  String get glassmorphismEffects;

  /// No description provided for @glassmorphismEffectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apply frosted glass to cards'**
  String get glassmorphismEffectsSubtitle;

  /// No description provided for @noEventsForThisDay.
  ///
  /// In en, this message translates to:
  /// **'No events for this day'**
  String get noEventsForThisDay;

  /// No description provided for @searchSymbols.
  ///
  /// In en, this message translates to:
  /// **'Search Symbols'**
  String get searchSymbols;

  /// No description provided for @searchSymbolsDesc.
  ///
  /// In en, this message translates to:
  /// **'Use symbols to filter tasks: @category (e.g. @work), #title (e.g. #meeting), !priority (e.g. !high), %date (e.g. %2025-06-15), &subtask (e.g. &fix bug), *status (*done or *pending), ? (tasks due today). Combine multiple symbols.'**
  String get searchSymbolsDesc;

  /// No description provided for @widgetSettings.
  ///
  /// In en, this message translates to:
  /// **'Widget Customization'**
  String get widgetSettings;

  /// No description provided for @widgetSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure colors, theme, and features'**
  String get widgetSettingsSubtitle;

  /// No description provided for @widgetTheme.
  ///
  /// In en, this message translates to:
  /// **'Widget Theme'**
  String get widgetTheme;

  /// No description provided for @widgetThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get widgetThemeSystem;

  /// No description provided for @widgetThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Solid Light'**
  String get widgetThemeLight;

  /// No description provided for @widgetThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Solid Dark'**
  String get widgetThemeDark;

  /// No description provided for @widgetThemeGlassmorphic.
  ///
  /// In en, this message translates to:
  /// **'Glassmorphism'**
  String get widgetThemeGlassmorphic;

  /// No description provided for @showWeekNumbers.
  ///
  /// In en, this message translates to:
  /// **'Show Week Numbers'**
  String get showWeekNumbers;

  /// No description provided for @weekendHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlight Weekends'**
  String get weekendHighlights;

  /// No description provided for @startOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Start of Week'**
  String get startOfWeek;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @widgetAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Widget Accent Color'**
  String get widgetAccentColor;

  /// No description provided for @widgetSuiteTitle.
  ///
  /// In en, this message translates to:
  /// **'Available Home Widgets'**
  String get widgetSuiteTitle;

  /// No description provided for @widgetSuiteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose from our suite of widgets. Free users can place 1 active widget on screen; Pro users can place unlimited widgets.'**
  String get widgetSuiteSubtitle;

  /// No description provided for @todayAgendaWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Day Agenda'**
  String get todayAgendaWidgetTitle;

  /// No description provided for @todayAgendaWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Interactive day-by-day task & event viewer with instant completion.'**
  String get todayAgendaWidgetSubtitle;

  /// No description provided for @monthAgendaWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Month & Agenda'**
  String get monthAgendaWidgetTitle;

  /// No description provided for @monthAgendaWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Samsung-style split layout with monthly calendar grid and selected date agenda.'**
  String get monthAgendaWidgetSubtitle;

  /// No description provided for @timelineAgendaWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule Timeline'**
  String get timelineAgendaWidgetTitle;

  /// No description provided for @timelineAgendaWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Google-style continuous multi-day scrollable agenda timeline.'**
  String get timelineAgendaWidgetSubtitle;

  /// No description provided for @quickActionWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions & Ring'**
  String get quickActionWidgetTitle;

  /// No description provided for @quickActionWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-tap task creation with live completion progress counter.'**
  String get quickActionWidgetSubtitle;

  /// No description provided for @upNextWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Up Next Pill'**
  String get upNextWidgetTitle;

  /// No description provided for @upNextWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Minimalist card showing your next urgent task or meeting with countdown badge.'**
  String get upNextWidgetSubtitle;

  /// No description provided for @tasksWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Tasks'**
  String get tasksWidgetTitle;

  /// No description provided for @tasksWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scrollable task list with one-tap completion and smart filters.'**
  String get tasksWidgetSubtitle;

  /// No description provided for @googleTasksDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Google Tasks Disconnected'**
  String get googleTasksDisconnected;

  /// No description provided for @googleTasksDisconnectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to reconnect and resume sync'**
  String get googleTasksDisconnectedSubtitle;

  /// No description provided for @rocisScheduleDisconnected.
  ///
  /// In en, this message translates to:
  /// **'ROCIs Schedule Disconnected'**
  String get rocisScheduleDisconnected;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @webPaywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock ROCIs Tasks Pro on Web'**
  String get webPaywallTitle;

  /// No description provided for @webPaywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to premium to access all advanced features on any platform.'**
  String get webPaywallSubtitle;

  /// No description provided for @webSimulatedUpgradeBtn.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get webSimulatedUpgradeBtn;

  /// No description provided for @webPaywallNotice.
  ///
  /// In en, this message translates to:
  /// **'Payments are securely processed by Lemon Squeezy. Your subscription will be activated automatically.'**
  String get webPaywallNotice;

  /// No description provided for @monthlyPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Plan'**
  String get monthlyPlanTitle;

  /// No description provided for @monthlyPlanPrice.
  ///
  /// In en, this message translates to:
  /// **'\$2.99 / month'**
  String get monthlyPlanPrice;

  /// No description provided for @yearlyPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Yearly Plan'**
  String get yearlyPlanTitle;

  /// No description provided for @yearlyPlanPrice.
  ///
  /// In en, this message translates to:
  /// **'\$29.99 / year'**
  String get yearlyPlanPrice;

  /// No description provided for @yearlyPlanSaving.
  ///
  /// In en, this message translates to:
  /// **'Save 16%'**
  String get yearlyPlanSaving;

  /// No description provided for @lifetimePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get lifetimePlanTitle;

  /// No description provided for @lifetimePlanPrice.
  ///
  /// In en, this message translates to:
  /// **'\$69.99 once'**
  String get lifetimePlanPrice;

  /// No description provided for @lifetimePlanBadge.
  ///
  /// In en, this message translates to:
  /// **'Best Value'**
  String get lifetimePlanBadge;

  /// No description provided for @groceryListMode.
  ///
  /// In en, this message translates to:
  /// **'Task List'**
  String get groceryListMode;

  /// No description provided for @groceryListModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Format task as an interactive task list'**
  String get groceryListModeSubtitle;

  /// No description provided for @itemsInCart.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} completed'**
  String itemsInCart(Object completed, Object total);

  /// No description provided for @toBuy.
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get toBuy;

  /// No description provided for @inCart.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get inCart;

  /// No description provided for @resetCart.
  ///
  /// In en, this message translates to:
  /// **'Reset List'**
  String get resetCart;

  /// No description provided for @clearCartItems.
  ///
  /// In en, this message translates to:
  /// **'Clear List Items'**
  String get clearCartItems;

  /// No description provided for @addItemHint.
  ///
  /// In en, this message translates to:
  /// **'Add item...'**
  String get addItemHint;

  /// No description provided for @quantityHint.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantityHint;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @selectTimezone.
  ///
  /// In en, this message translates to:
  /// **'Select Timezone'**
  String get selectTimezone;

  /// No description provided for @automaticTimezone.
  ///
  /// In en, this message translates to:
  /// **'Automatic (Device Timezone)'**
  String get automaticTimezone;

  /// No description provided for @searchTimezone.
  ///
  /// In en, this message translates to:
  /// **'Search timezone...'**
  String get searchTimezone;

  /// No description provided for @repeatWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays (Mon–Fri)'**
  String get repeatWeekdays;

  /// No description provided for @repeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get repeatYearly;

  /// No description provided for @repeatCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom...'**
  String get repeatCustom;

  /// No description provided for @repeatsEvery.
  ///
  /// In en, this message translates to:
  /// **'Repeats every'**
  String get repeatsEvery;

  /// No description provided for @customRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Custom Recurrence'**
  String get customRecurrence;

  /// No description provided for @daySingular.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get daySingular;

  /// No description provided for @daysPlural.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get daysPlural;

  /// No description provided for @weekSingular.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get weekSingular;

  /// No description provided for @weeksPlural.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get weeksPlural;

  /// No description provided for @monthSingular.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get monthSingular;

  /// No description provided for @monthsPlural.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get monthsPlural;

  /// No description provided for @yearSingular.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get yearSingular;

  /// No description provided for @yearsPlural.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get yearsPlural;

  /// No description provided for @selectRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Select Recurrence'**
  String get selectRecurrence;

  /// No description provided for @guestMode.
  ///
  /// In en, this message translates to:
  /// **'Guest Mode'**
  String get guestMode;

  /// No description provided for @guestModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All data is stored locally on this device. Sign in to back up and sync with the cloud.'**
  String get guestModeSubtitle;

  /// No description provided for @guestAccount.
  ///
  /// In en, this message translates to:
  /// **'Guest Account'**
  String get guestAccount;

  /// No description provided for @signInOrRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign In / Register'**
  String get signInOrRegister;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @cloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Backup & Sync'**
  String get cloudSync;

  /// No description provided for @cloudSyncActive.
  ///
  /// In en, this message translates to:
  /// **'Active & synced'**
  String get cloudSyncActive;

  /// No description provided for @customFields.
  ///
  /// In en, this message translates to:
  /// **'Custom Lines'**
  String get customFields;

  /// No description provided for @customFieldsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Attach contacts, locations, links, or notes'**
  String get customFieldsSubtitle;

  /// No description provided for @addCustomField.
  ///
  /// In en, this message translates to:
  /// **'Add Line'**
  String get addCustomField;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @fieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get fieldLabel;

  /// No description provided for @fieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get fieldValue;

  /// No description provided for @enterContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Phone number or email'**
  String get enterContactInfo;

  /// No description provided for @enterLocation.
  ///
  /// In en, this message translates to:
  /// **'Address or place'**
  String get enterLocation;

  /// No description provided for @enterUrl.
  ///
  /// In en, this message translates to:
  /// **'Website or URL'**
  String get enterUrl;

  /// No description provided for @enterNote.
  ///
  /// In en, this message translates to:
  /// **'Custom details'**
  String get enterNote;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @noCustomFieldsAdded.
  ///
  /// In en, this message translates to:
  /// **'No custom lines added'**
  String get noCustomFieldsAdded;

  /// No description provided for @quickDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get quickDateToday;

  /// No description provided for @quickDateTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get quickDateTomorrow;

  /// No description provided for @quickDateThisWeekend.
  ///
  /// In en, this message translates to:
  /// **'This Weekend'**
  String get quickDateThisWeekend;

  /// No description provided for @quickDateNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next Week'**
  String get quickDateNextWeek;

  /// No description provided for @templateStarterTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Starter Templates'**
  String get templateStarterTitle;

  /// No description provided for @templateGroceryTitle.
  ///
  /// In en, this message translates to:
  /// **'Grocery & Shopping List'**
  String get templateGroceryTitle;

  /// No description provided for @templateGroceryDesc.
  ///
  /// In en, this message translates to:
  /// **'Checklist for groceries & essentials'**
  String get templateGroceryDesc;

  /// No description provided for @templateWorkTitle.
  ///
  /// In en, this message translates to:
  /// **'Work Sprint Task'**
  String get templateWorkTitle;

  /// No description provided for @templateWorkDesc.
  ///
  /// In en, this message translates to:
  /// **'High-priority project milestone'**
  String get templateWorkDesc;

  /// No description provided for @templateRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Routine'**
  String get templateRoutineTitle;

  /// No description provided for @templateRoutineDesc.
  ///
  /// In en, this message translates to:
  /// **'Recurring daily morning habit'**
  String get templateRoutineDesc;

  /// No description provided for @templateStudyTitle.
  ///
  /// In en, this message translates to:
  /// **'Study & Assignment'**
  String get templateStudyTitle;

  /// No description provided for @templateStudyDesc.
  ///
  /// In en, this message translates to:
  /// **'Track course reading & exercises'**
  String get templateStudyDesc;

  /// No description provided for @completedTasksHeader.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String completedTasksHeader(int count);

  /// No description provided for @upcomingRecurringTasksHeader.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Recurring ({count})'**
  String upcomingRecurringTasksHeader(int count);

  /// No description provided for @upcomingRecurringBadge.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingRecurringBadge;

  /// No description provided for @allCaughtUpToday.
  ///
  /// In en, this message translates to:
  /// **'All done for today! 🎉'**
  String get allCaughtUpToday;

  /// No description provided for @allCaughtUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Great job! Take a break or add a new task.'**
  String get allCaughtUpSubtitle;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset All'**
  String get resetFilters;

  /// No description provided for @rescheduleTask.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get rescheduleTask;

  /// No description provided for @plusOneDay.
  ///
  /// In en, this message translates to:
  /// **'+1 Day'**
  String get plusOneDay;

  /// No description provided for @plusOneWeek.
  ///
  /// In en, this message translates to:
  /// **'+1 Week'**
  String get plusOneWeek;

  /// No description provided for @moveToToday.
  ///
  /// In en, this message translates to:
  /// **'Move to Today'**
  String get moveToToday;

  /// No description provided for @activeTasks.
  ///
  /// In en, this message translates to:
  /// **'Active Tasks'**
  String get activeTasks;

  /// No description provided for @boardView.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get boardView;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listView;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group By'**
  String get groupBy;

  /// No description provided for @groupByStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get groupByStatus;

  /// No description provided for @groupByPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get groupByPriority;

  /// No description provided for @groupByCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get groupByCategory;

  /// No description provided for @columnToDo.
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get columnToDo;

  /// No description provided for @columnInFocus.
  ///
  /// In en, this message translates to:
  /// **'In Focus'**
  String get columnInFocus;

  /// No description provided for @columnDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get columnDone;

  /// No description provided for @emptyColumn.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this column'**
  String get emptyColumn;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @highPriority.
  ///
  /// In en, this message translates to:
  /// **'High Priority'**
  String get highPriority;

  /// No description provided for @mediumPriority.
  ///
  /// In en, this message translates to:
  /// **'Medium Priority'**
  String get mediumPriority;

  /// No description provided for @lowPriority.
  ///
  /// In en, this message translates to:
  /// **'Low Priority'**
  String get lowPriority;

  /// No description provided for @kanbanWidget.
  ///
  /// In en, this message translates to:
  /// **'Kanban Board'**
  String get kanbanWidget;

  /// No description provided for @kanbanWidgetDesc.
  ///
  /// In en, this message translates to:
  /// **'Interactive Kanban board with To Do, In Focus, and Done columns'**
  String get kanbanWidgetDesc;

  /// No description provided for @freeTrialBadge.
  ///
  /// In en, this message translates to:
  /// **'{days}-day free trial'**
  String freeTrialBadge(int days);

  /// No description provided for @startFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'Start {days}-day free trial'**
  String startFreeTrial(int days);

  /// No description provided for @trialThenPrice.
  ///
  /// In en, this message translates to:
  /// **'Then {price} per year. Cancel anytime before the trial ends and you won\'t be charged.'**
  String trialThenPrice(String price);

  /// No description provided for @plansUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plans couldn\'t load. Check your connection and try again.'**
  String get plansUnavailable;

  /// No description provided for @addToHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Add to home screen'**
  String get addToHomeScreen;

  /// No description provided for @fullCalendarWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Calendar'**
  String get fullCalendarWidgetTitle;

  /// No description provided for @fullCalendarWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your month at a glance with colored event pills, filters and quick add.'**
  String get fullCalendarWidgetSubtitle;

  /// No description provided for @widgetPinUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Your launcher can\'t add widgets from apps. Long-press your home screen, tap Widgets and find ROCI\'s Tasks.'**
  String get widgetPinUnsupported;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @pinLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs. Try again in {seconds} s.'**
  String pinLockedOut(String seconds);

  /// No description provided for @pinSaved.
  ///
  /// In en, this message translates to:
  /// **'PIN saved'**
  String get pinSaved;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @openExternally.
  ///
  /// In en, this message translates to:
  /// **'Open externally'**
  String get openExternally;

  /// No description provided for @syncDeviceCalendar.
  ///
  /// In en, this message translates to:
  /// **'Sync Device Calendar'**
  String get syncDeviceCalendar;

  /// No description provided for @openInRocisSchedule.
  ///
  /// In en, this message translates to:
  /// **'Open in ROCIs Schedule'**
  String get openInRocisSchedule;

  /// No description provided for @syncCalendars.
  ///
  /// In en, this message translates to:
  /// **'Sync Calendars'**
  String get syncCalendars;

  /// No description provided for @a11yCategory.
  ///
  /// In en, this message translates to:
  /// **'Category: {name}'**
  String a11yCategory(String name);

  /// No description provided for @a11yDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get a11yDeleteCategory;

  /// No description provided for @a11yColorOption.
  ///
  /// In en, this message translates to:
  /// **'Color option {number}'**
  String a11yColorOption(String number);

  /// No description provided for @a11yIconOption.
  ///
  /// In en, this message translates to:
  /// **'Icon option {number}'**
  String a11yIconOption(String number);

  /// No description provided for @a11yColorHex.
  ///
  /// In en, this message translates to:
  /// **'Color {hex}'**
  String a11yColorHex(String hex);

  /// No description provided for @a11yClearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear selected date'**
  String get a11yClearDate;

  /// No description provided for @a11yClearRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Clear recurrence'**
  String get a11yClearRecurrence;

  /// No description provided for @a11yRemoveField.
  ///
  /// In en, this message translates to:
  /// **'Remove field'**
  String get a11yRemoveField;

  /// No description provided for @taskCompletionFeedback.
  ///
  /// In en, this message translates to:
  /// **'Task Completion Feedback'**
  String get taskCompletionFeedback;

  /// No description provided for @taskCompletionFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Haptic pulse when ticking off a task'**
  String get taskCompletionFeedbackSubtitle;

  /// No description provided for @cookiePreferences.
  ///
  /// In en, this message translates to:
  /// **'Cookie Preferences'**
  String get cookiePreferences;

  /// No description provided for @cookiePreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset cookie & storage consent'**
  String get cookiePreferencesSubtitle;

  /// No description provided for @scheduleSynergyTitle.
  ///
  /// In en, this message translates to:
  /// **'ROCIs Schedule'**
  String get scheduleSynergyTitle;

  /// No description provided for @scheduleSynergySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync active with ROCIs Schedule'**
  String get scheduleSynergySubtitle;

  /// No description provided for @openAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openAction;

  /// No description provided for @addedToToday.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\" to Today'**
  String addedToToday(String title);

  /// No description provided for @taskUpdated.
  ///
  /// In en, this message translates to:
  /// **'Task updated'**
  String get taskUpdated;

  /// No description provided for @taskCreated.
  ///
  /// In en, this message translates to:
  /// **'Task created'**
  String get taskCreated;

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// No description provided for @backToTasks.
  ///
  /// In en, this message translates to:
  /// **'Back to tasks'**
  String get backToTasks;

  /// No description provided for @calendarDisconnectedReconnect.
  ///
  /// In en, this message translates to:
  /// **'Calendar disconnected. Tap to reconnect'**
  String get calendarDisconnectedReconnect;

  /// No description provided for @webSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks or jump to... (⌘K)'**
  String get webSearchHint;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @quickAddTodayHint.
  ///
  /// In en, this message translates to:
  /// **'Quick add task to Today... (Press Enter)'**
  String get quickAddTodayHint;

  /// No description provided for @todayAndOverdue.
  ///
  /// In en, this message translates to:
  /// **'Today & Overdue'**
  String get todayAndOverdue;

  /// No description provided for @inboxAndUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Inbox & Upcoming'**
  String get inboxAndUpcoming;

  /// No description provided for @closeEsc.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get closeEsc;

  /// No description provided for @taskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Task title...'**
  String get taskTitleHint;

  /// No description provided for @taskNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add description or notes...'**
  String get taskNotesHint;

  /// No description provided for @addSubtaskHint.
  ///
  /// In en, this message translates to:
  /// **'Add a subtask... (Press Enter)'**
  String get addSubtaskHint;

  /// No description provided for @paletteActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get paletteActions;

  /// No description provided for @cmdNewTaskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new task with full properties'**
  String get cmdNewTaskSubtitle;

  /// No description provided for @cmdTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to the task list'**
  String get cmdTasksSubtitle;

  /// No description provided for @cmdKanbanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to the Kanban board'**
  String get cmdKanbanSubtitle;

  /// No description provided for @cmdCalendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to calendar and agenda'**
  String get cmdCalendarSubtitle;

  /// No description provided for @cmdCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get cmdCategoriesSubtitle;

  /// No description provided for @cmdSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open preferences'**
  String get cmdSettingsSubtitle;

  /// No description provided for @cmdSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync tasks both ways now'**
  String get cmdSyncSubtitle;

  /// No description provided for @cmdToggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme (dark / light)'**
  String get cmdToggleTheme;

  /// No description provided for @cmdToggleThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch the color mode'**
  String get cmdToggleThemeSubtitle;

  /// No description provided for @cmdCategoryFilterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Filter tasks by this category'**
  String get cmdCategoryFilterSubtitle;

  /// No description provided for @cmdSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Type a command or search tasks...'**
  String get cmdSearchHint;

  /// No description provided for @clearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAction;

  /// No description provided for @dismissAction.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissAction;

  /// No description provided for @openingCheckout.
  ///
  /// In en, this message translates to:
  /// **'Opening checkout...'**
  String get openingCheckout;

  /// No description provided for @purchaseError.
  ///
  /// In en, this message translates to:
  /// **'Purchase error: {error}'**
  String purchaseError(String error);

  /// No description provided for @syncedWithGoogleTasks.
  ///
  /// In en, this message translates to:
  /// **'Synced with Google Tasks'**
  String get syncedWithGoogleTasks;

  /// No description provided for @syncingToCloud.
  ///
  /// In en, this message translates to:
  /// **'Syncing changes to the cloud...'**
  String get syncingToCloud;

  /// No description provided for @allSyncedToCloud.
  ///
  /// In en, this message translates to:
  /// **'All changes synced to the cloud'**
  String get allSyncedToCloud;

  /// No description provided for @connectedAndSynced.
  ///
  /// In en, this message translates to:
  /// **'Connected & synced'**
  String get connectedAndSynced;

  /// No description provided for @notificationActionAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get notificationActionAddTask;

  /// No description provided for @couldNotOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {name}'**
  String couldNotOpenUrl(String name);

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found: {name}'**
  String fileNotFound(String name);

  /// No description provided for @noAppToOpen.
  ///
  /// In en, this message translates to:
  /// **'No app found to open {name}'**
  String noAppToOpen(String name);

  /// No description provided for @cannotOpenLocalFileOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Local files can\'t be opened on the web'**
  String get cannotOpenLocalFileOnWeb;

  /// No description provided for @checkingDeviceCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Checking device capabilities...'**
  String get checkingDeviceCapabilities;

  /// No description provided for @noTitle.
  ///
  /// In en, this message translates to:
  /// **'No title'**
  String get noTitle;

  /// No description provided for @scheduleClearForDate.
  ///
  /// In en, this message translates to:
  /// **'Your schedule is clear for this date.'**
  String get scheduleClearForDate;

  /// No description provided for @calendarPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Calendar permission is required to display events.'**
  String get calendarPermissionRequired;

  /// No description provided for @a11yGoogleCalendarEvent.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar event: {title}'**
  String a11yGoogleCalendarEvent(String title);

  /// No description provided for @noCalendarsLoaded.
  ///
  /// In en, this message translates to:
  /// **'No calendars loaded'**
  String get noCalendarsLoaded;

  /// No description provided for @a11yEditCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get a11yEditCategory;

  /// No description provided for @cookiePreferencesReset.
  ///
  /// In en, this message translates to:
  /// **'Cookie preferences reset. The consent banner will appear shortly.'**
  String get cookiePreferencesReset;

  /// No description provided for @betaFeatures.
  ///
  /// In en, this message translates to:
  /// **'Beta Features'**
  String get betaFeatures;

  /// No description provided for @scheduleIntegrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync university timetable events and open ROCIs Schedule from here'**
  String get scheduleIntegrationSubtitle;

  /// No description provided for @noMatchingCommands.
  ///
  /// In en, this message translates to:
  /// **'No matching commands or tasks'**
  String get noMatchingCommands;

  /// No description provided for @cookieBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Cookie & Storage Preferences'**
  String get cookieBannerTitle;

  /// No description provided for @cookieBannerBody.
  ///
  /// In en, this message translates to:
  /// **'We use essential storage and secure session cookies to keep your Google Tasks and Calendar integrations connected across visits. Choose your preference below.'**
  String get cookieBannerBody;

  /// No description provided for @essentialOnly.
  ///
  /// In en, this message translates to:
  /// **'Essential Only'**
  String get essentialOnly;

  /// No description provided for @acceptAll.
  ///
  /// In en, this message translates to:
  /// **'Accept All'**
  String get acceptAll;

  /// No description provided for @a11yPickDateHint.
  ///
  /// In en, this message translates to:
  /// **'Choose date and time'**
  String get a11yPickDateHint;

  /// No description provided for @a11yRecurrenceHint.
  ///
  /// In en, this message translates to:
  /// **'Set up repeat'**
  String get a11yRecurrenceHint;

  /// No description provided for @emptyStateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your mind clear and your day organized.'**
  String get emptyStateSubtitle;

  /// No description provided for @a11ySelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get a11ySelected;

  /// No description provided for @a11yNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get a11yNotSelected;

  /// No description provided for @authenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating...'**
  String get authenticating;

  /// No description provided for @errorScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorScreenTitle;

  /// No description provided for @errorScreenBody.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. It has been reported.'**
  String get errorScreenBody;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @offlineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Offline: changes are saved on this device and sync when you\'re back online'**
  String get offlineTooltip;

  /// No description provided for @syncingLabel.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncingLabel;

  /// No description provided for @syncErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get syncErrorLabel;

  /// No description provided for @syncErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Sync error. Tap to retry.'**
  String get syncErrorRetry;

  /// No description provided for @syncedLabel.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncedLabel;

  /// No description provided for @calendarDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Calendar disconnected'**
  String get calendarDisconnected;

  /// No description provided for @getAndroidApp.
  ///
  /// In en, this message translates to:
  /// **'Get the Android app'**
  String get getAndroidApp;

  /// No description provided for @onGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'On Google Play'**
  String get onGooglePlay;

  /// No description provided for @userProfile.
  ///
  /// In en, this message translates to:
  /// **'User profile'**
  String get userProfile;

  /// No description provided for @userFallbackName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallbackName;

  /// No description provided for @helloUser.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name} 👋'**
  String helloUser(String name);

  /// No description provided for @helloThere.
  ///
  /// In en, this message translates to:
  /// **'Hello 👋'**
  String get helloThere;

  /// No description provided for @webDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize your priorities and keep your sync healthy.'**
  String get webDashboardSubtitle;

  /// No description provided for @totalActive.
  ///
  /// In en, this message translates to:
  /// **'Total active'**
  String get totalActive;

  /// No description provided for @upcomingSection.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingSection;

  /// No description provided for @switchToComfortableView.
  ///
  /// In en, this message translates to:
  /// **'Switch to comfortable view'**
  String get switchToComfortableView;

  /// No description provided for @switchToCompactView.
  ///
  /// In en, this message translates to:
  /// **'Switch to compact view'**
  String get switchToCompactView;

  /// No description provided for @noTasksInSection.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this section'**
  String get noTasksInSection;

  /// No description provided for @selectATask.
  ///
  /// In en, this message translates to:
  /// **'Select a task'**
  String get selectATask;

  /// No description provided for @selectATaskBody.
  ///
  /// In en, this message translates to:
  /// **'Click a task to view and edit it, or click \"+ New Task\" to create one.'**
  String get selectATaskBody;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetails;

  /// No description provided for @savingStatus.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get savingStatus;

  /// No description provided for @savedStatus.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedStatus;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @dueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDateLabel;

  /// No description provided for @setDate.
  ///
  /// In en, this message translates to:
  /// **'Set date'**
  String get setDate;

  /// No description provided for @subtasksProgress.
  ///
  /// In en, this message translates to:
  /// **'Subtasks ({done}/{total})'**
  String subtasksProgress(String done, String total);

  /// No description provided for @liveWidgetPreview.
  ///
  /// In en, this message translates to:
  /// **'Live widget preview'**
  String get liveWidgetPreview;

  /// No description provided for @calendarWidgetBehavior.
  ///
  /// In en, this message translates to:
  /// **'Calendar widget behavior'**
  String get calendarWidgetBehavior;

  /// No description provided for @widgetGeneric.
  ///
  /// In en, this message translates to:
  /// **'Widget'**
  String get widgetGeneric;

  /// No description provided for @widgetNameMonthList.
  ///
  /// In en, this message translates to:
  /// **'Month & List'**
  String get widgetNameMonthList;

  /// No description provided for @widgetNameTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get widgetNameTimeline;

  /// No description provided for @widgetNameQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get widgetNameQuickActions;

  /// No description provided for @widgetNameUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get widgetNameUpNext;

  /// No description provided for @filterWidgetTasks.
  ///
  /// In en, this message translates to:
  /// **'Filter widget tasks'**
  String get filterWidgetTasks;

  /// No description provided for @addSubtask.
  ///
  /// In en, this message translates to:
  /// **'Add subtask'**
  String get addSubtask;

  /// No description provided for @removeSubtask.
  ///
  /// In en, this message translates to:
  /// **'Remove subtask'**
  String get removeSubtask;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @decreaseInterval.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decreaseInterval;

  /// No description provided for @increaseInterval.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increaseInterval;

  /// No description provided for @restoreTask.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreTask;

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @tplGroceryProduce.
  ///
  /// In en, this message translates to:
  /// **'Fresh produce'**
  String get tplGroceryProduce;

  /// No description provided for @tplGroceryDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy & milk'**
  String get tplGroceryDairy;

  /// No description provided for @tplGroceryBakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get tplGroceryBakery;

  /// No description provided for @tplGroceryPantry.
  ///
  /// In en, this message translates to:
  /// **'Pantry staples'**
  String get tplGroceryPantry;

  /// No description provided for @tplWorkSprint.
  ///
  /// In en, this message translates to:
  /// **'Review sprint board'**
  String get tplWorkSprint;

  /// No description provided for @tplWorkTop3.
  ///
  /// In en, this message translates to:
  /// **'Prioritize top 3 tasks'**
  String get tplWorkTop3;

  /// No description provided for @tplWorkStandup.
  ///
  /// In en, this message translates to:
  /// **'Team sync & standup'**
  String get tplWorkStandup;

  /// No description provided for @tplRoutineWater.
  ///
  /// In en, this message translates to:
  /// **'Drink 500 ml water'**
  String get tplRoutineWater;

  /// No description provided for @tplRoutineStretch.
  ///
  /// In en, this message translates to:
  /// **'15 min morning stretch'**
  String get tplRoutineStretch;

  /// No description provided for @tplRoutinePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan the day\'s priorities'**
  String get tplRoutinePlan;

  /// No description provided for @tplStudyRead.
  ///
  /// In en, this message translates to:
  /// **'Read chapter notes'**
  String get tplStudyRead;

  /// No description provided for @tplStudyPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice 5 problems'**
  String get tplStudyPractice;

  /// No description provided for @tplStudyFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Make a flashcard summary'**
  String get tplStudyFlashcards;

  /// No description provided for @previewTasksRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks remaining'**
  String previewTasksRemaining(String count);

  /// No description provided for @previewStartsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in {minutes} min · {time}'**
  String previewStartsIn(String minutes, String time);

  /// No description provided for @previewNextEvent.
  ///
  /// In en, this message translates to:
  /// **'Next: {title}'**
  String previewNextEvent(String title);

  /// No description provided for @previewAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get previewAgenda;

  /// No description provided for @previewGrocery.
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get previewGrocery;

  /// No description provided for @previewSampleDesignReview.
  ///
  /// In en, this message translates to:
  /// **'Design review & handoff'**
  String get previewSampleDesignReview;

  /// No description provided for @previewSampleUpdateDeps.
  ///
  /// In en, this message translates to:
  /// **'Update app dependencies'**
  String get previewSampleUpdateDeps;

  /// No description provided for @previewSampleSprintPlanning.
  ///
  /// In en, this message translates to:
  /// **'Sprint planning'**
  String get previewSampleSprintPlanning;

  /// No description provided for @previewSampleGroceryShopping.
  ///
  /// In en, this message translates to:
  /// **'Grocery shopping'**
  String get previewSampleGroceryShopping;

  /// No description provided for @previewSampleStandup.
  ///
  /// In en, this message translates to:
  /// **'Daily standup call'**
  String get previewSampleStandup;

  /// No description provided for @previewSampleMeet.
  ///
  /// In en, this message translates to:
  /// **'Google Meet · Team'**
  String get previewSampleMeet;

  /// No description provided for @previewSampleRelease.
  ///
  /// In en, this message translates to:
  /// **'Prepare the release'**
  String get previewSampleRelease;

  /// No description provided for @previewSampleProductTasks.
  ///
  /// In en, this message translates to:
  /// **'Product tasks'**
  String get previewSampleProductTasks;

  /// No description provided for @previewSampleLaunchReview.
  ///
  /// In en, this message translates to:
  /// **'Product launch review'**
  String get previewSampleLaunchReview;

  /// No description provided for @shareTaskQr.
  ///
  /// In en, this message translates to:
  /// **'Share via QR Code'**
  String get shareTaskQr;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrCode;

  /// No description provided for @offlineDirect.
  ///
  /// In en, this message translates to:
  /// **'Offline Direct'**
  String get offlineDirect;

  /// No description provided for @offlineDirectDesc.
  ///
  /// In en, this message translates to:
  /// **'100% private. Works without internet. Attachments not included.'**
  String get offlineDirectDesc;

  /// No description provided for @cloudShare7Days.
  ///
  /// In en, this message translates to:
  /// **'Cloud Link (7 Days)'**
  String get cloudShare7Days;

  /// No description provided for @cloudShareDesc.
  ///
  /// In en, this message translates to:
  /// **'Shared securely via cloud. Expires automatically in 7 days.'**
  String get cloudShareDesc;

  /// No description provided for @copyQrPayload.
  ///
  /// In en, this message translates to:
  /// **'Copy QR Data'**
  String get copyQrPayload;

  /// No description provided for @qrDataCopied.
  ///
  /// In en, this message translates to:
  /// **'QR data copied to clipboard'**
  String get qrDataCopied;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from Gallery'**
  String get pickFromGallery;

  /// No description provided for @importTask.
  ///
  /// In en, this message translates to:
  /// **'Import Task'**
  String get importTask;

  /// No description provided for @importTaskPreview.
  ///
  /// In en, this message translates to:
  /// **'Import Task Preview'**
  String get importTaskPreview;

  /// No description provided for @taskImportedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Task imported successfully!'**
  String get taskImportedSuccess;

  /// No description provided for @invalidQrCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or unrecognized task QR code.'**
  String get invalidQrCode;

  /// No description provided for @taskExpired.
  ///
  /// In en, this message translates to:
  /// **'This shared task has expired.'**
  String get taskExpired;

  /// No description provided for @suggestedCategory.
  ///
  /// In en, this message translates to:
  /// **'Suggested category: {category}'**
  String suggestedCategory(String category);

  /// No description provided for @destinationCategory.
  ///
  /// In en, this message translates to:
  /// **'Destination Category'**
  String get destinationCategory;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan QR codes.'**
  String get cameraPermissionRequired;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;

  /// No description provided for @flashOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on flash'**
  String get flashOn;

  /// No description provided for @flashOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off flash'**
  String get flashOff;

  /// No description provided for @flipCamera.
  ///
  /// In en, this message translates to:
  /// **'Flip camera'**
  String get flipCamera;

  /// No description provided for @completeSubtasksFirst.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Finish the last subtask first} other{Finish the {count} open subtasks first}}'**
  String completeSubtasksFirst(int count);

  /// No description provided for @guideSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search the guide'**
  String get guideSearchHint;

  /// No description provided for @guideNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching topics'**
  String get guideNoResults;

  /// No description provided for @guideProBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get guideProBadge;

  /// No description provided for @guideQuickAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick add with smart text'**
  String get guideQuickAddTitle;

  /// No description provided for @guideQuickAddBody.
  ///
  /// In en, this message translates to:
  /// **'Tap + and choose New task, then type naturally. The details are filled in for you:\n• Dates: today, tomorrow, tonight, next week, in 3 days, friday\n• Times: 6pm, 18:30, at 9\n• Priority: !high, !low (or p1 to p3)\n• Category: #work\nExample: \"Call mom tomorrow 6pm !high #family\"'**
  String get guideQuickAddBody;

  /// No description provided for @guideSubtasksBody.
  ///
  /// In en, this message translates to:
  /// **'Open a task and add subtasks to split it into steps. Turn on \"Subtasks required\" and the task can\'t be checked off until every subtask is done. Grocery lists complete themselves once every item is checked.'**
  String get guideSubtasksBody;

  /// No description provided for @guideRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring tasks'**
  String get guideRecurringTitle;

  /// No description provided for @guideRecurringBody.
  ///
  /// In en, this message translates to:
  /// **'Set a task to repeat daily, on weekdays, weekly, monthly, yearly or on a custom rule. When you complete it, the next one is scheduled with its reminder and shows up on its day.'**
  String get guideRecurringBody;

  /// No description provided for @guideRemindersBody.
  ///
  /// In en, this message translates to:
  /// **'A task with a due time reminds you when it\'s due. From the notification you can complete it, open it or snooze it. Pro adds more snooze options, repeat reminders until you act, and quiet hours.'**
  String get guideRemindersBody;

  /// No description provided for @guideViewsTitle.
  ///
  /// In en, this message translates to:
  /// **'List, board and calendar'**
  String get guideViewsTitle;

  /// No description provided for @guideViewsBody.
  ///
  /// In en, this message translates to:
  /// **'Switch between the list, the board and the calendar. The board sorts tasks into To do, In focus and Done, and you can drag cards between columns. The calendar shows your tasks next to Google Calendar events and ROCIs Schedule classes.'**
  String get guideViewsBody;

  /// No description provided for @guideSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Share tasks'**
  String get guideSharingTitle;

  /// No description provided for @guideSharingBody.
  ///
  /// In en, this message translates to:
  /// **'Open a task and share it as a link or a QR code. The other person sees a preview and can import their own copy. To scan a code, tap + and choose Scan QR code.'**
  String get guideSharingBody;

  /// No description provided for @guidePrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Mark a category as private and set a PIN in Settings. While locked, its tasks are hidden from the list, widgets and notifications.'**
  String get guidePrivacyBody;

  /// No description provided for @guideGoogleTasksBody.
  ///
  /// In en, this message translates to:
  /// **'Turn on Sync with Google Tasks for a task to mirror it into your Google Tasks list.'**
  String get guideGoogleTasksBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return lookupAppLocalizations(locale);
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'he',
    'hi',
    'sv',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

Future<AppLocalizations> lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return app_localizations_ar.loadLibrary().then(
        (dynamic _) => app_localizations_ar.AppLocalizationsAr(),
      );
    case 'de':
      return app_localizations_de.loadLibrary().then(
        (dynamic _) => app_localizations_de.AppLocalizationsDe(),
      );
    case 'en':
      return app_localizations_en.loadLibrary().then(
        (dynamic _) => app_localizations_en.AppLocalizationsEn(),
      );
    case 'es':
      return app_localizations_es.loadLibrary().then(
        (dynamic _) => app_localizations_es.AppLocalizationsEs(),
      );
    case 'fr':
      return app_localizations_fr.loadLibrary().then(
        (dynamic _) => app_localizations_fr.AppLocalizationsFr(),
      );
    case 'he':
      return app_localizations_he.loadLibrary().then(
        (dynamic _) => app_localizations_he.AppLocalizationsHe(),
      );
    case 'hi':
      return app_localizations_hi.loadLibrary().then(
        (dynamic _) => app_localizations_hi.AppLocalizationsHi(),
      );
    case 'sv':
      return app_localizations_sv.loadLibrary().then(
        (dynamic _) => app_localizations_sv.AppLocalizationsSv(),
      );
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
