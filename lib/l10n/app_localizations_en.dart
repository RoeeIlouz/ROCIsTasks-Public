// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ROCI\'s Tasks';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign Out';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get systemDefault => 'System Default';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get materialTheme => 'Material Theme';

  @override
  String get useSystemColors => 'Use system colors';

  @override
  String get amoledDarkMode => 'AMOLED Dark Mode';

  @override
  String get pureBlackBackground => 'Pure black background';

  @override
  String get dataAndSync => 'Data & Sync';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncingTasks => 'Syncing tasks...';

  @override
  String get trash => 'Trash';

  @override
  String get sortAndFilter => 'Sort & Filter';

  @override
  String get sortBy => 'Sort By';

  @override
  String get date => 'Date';

  @override
  String get priority => 'Priority';

  @override
  String get title => 'Title';

  @override
  String get createdDate => 'Created Date';

  @override
  String get filterByCategory => 'Filter by Category';

  @override
  String get all => 'All';

  @override
  String get showCompletedTasks => 'Show Completed Tasks';

  @override
  String get done => 'Done';

  @override
  String get timeFormat24h => '24h Time Format';

  @override
  String get language => 'Language';

  @override
  String get hebrew => 'Hebrew';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';

  @override
  String get arabic => 'Arabic';

  @override
  String get swedish => 'Swedish';

  @override
  String get german => 'German';

  @override
  String get french => 'French';

  @override
  String get hindi => 'Hindi';

  @override
  String get tasks => 'Tasks';

  @override
  String get editTask => 'Edit Task';

  @override
  String get newTask => 'New Task';

  @override
  String get description => 'Description';

  @override
  String get attachments => 'Attachments';

  @override
  String get noAttachmentsAdded => 'No attachments added';

  @override
  String get attachmentsPremiumOnly => 'Attachments are available with PRO.';

  @override
  String get dueDateAndTime => 'Due Date & Time';

  @override
  String get noDateSelected => 'No Date Selected';

  @override
  String get syncWithGoogleTasks => 'Sync with Google Tasks';

  @override
  String get syncWithGoogleTasksSubtitle =>
      'Creates and syncs a task in Google Tasks';

  @override
  String get googleSignInRequiredForSync =>
      'Google Sign-In is required to sync tasks.';

  @override
  String get calendarPermissionNotGranted => 'Calendar permission not granted';

  @override
  String get category => 'Category';

  @override
  String get noCategory => 'No Category';

  @override
  String get saveTask => 'Save Task';

  @override
  String get updateTask => 'Update Task';

  @override
  String get pleaseEnterATitle => 'Please enter a title';

  @override
  String get high => 'High';

  @override
  String get medium => 'Medium';

  @override
  String get low => 'Low';

  @override
  String get priorityLabel => 'Priority';

  @override
  String get myTasks => 'My Tasks';

  @override
  String get calendar => 'Calendar';

  @override
  String get categories => 'Categories';

  @override
  String get noCategoriesYet => 'No categories yet';

  @override
  String get addCategory => 'Add Category';

  @override
  String get newCategory => 'New Category';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get name => 'Name';

  @override
  String get color => 'Color';

  @override
  String get icon => 'Icon';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String restoredTask(String title) {
    return 'Restored $title';
  }

  @override
  String get deletePermanently => 'Delete Permanently?';

  @override
  String get actionUndone => 'This action cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get noTasksYet => 'No tasks yet';

  @override
  String get duePrefix => 'Due: ';

  @override
  String get deleteTaskTitle => 'Delete Task';

  @override
  String get deleteTaskConfirmation =>
      'Are you sure you want to delete this task?';

  @override
  String get calendarColors => 'Calendar Colors';

  @override
  String get calendarFiltersTitle => 'Calendar Filters';

  @override
  String get showCalendarTasks => 'Show Tasks';

  @override
  String get showGoogleCalendar => 'Show Google Calendar';

  @override
  String get showRocisSchedule => 'Show ROCIs Schedule';

  @override
  String get taskColor => 'Task Color';

  @override
  String get googleCalendarColor => 'Google Calendar Color';

  @override
  String get scheduleColor => 'ROCIs Schedule Color';

  @override
  String get assignmentColor => 'Assignment Color';

  @override
  String get resetColors => 'Reset to Defaults';

  @override
  String get selectColor => 'Select Color';

  @override
  String get selectGoogleCalendars => 'Select Google Calendars';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get offlineMode => 'Offline Mode';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String get backupAndRestore => 'Backup & Restore';

  @override
  String get exportData => 'Export Data (JSON)';

  @override
  String get exportDataSubtitle => 'Backup your tasks and categories';

  @override
  String get backupCopied => 'Backup copied to clipboard!';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get importData => 'Import Data (JSON)';

  @override
  String get importDataSubtitle => 'Restore from a JSON backup';

  @override
  String get importBackup => 'Import Backup';

  @override
  String get pasteJsonHint => 'Paste JSON backup here...';

  @override
  String get import => 'Import';

  @override
  String get importComplete => 'Import complete!';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get privacyAndGdpr => 'Privacy & GDPR';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicySubtitle => 'Read our data security terms';

  @override
  String get deleteAccountTitle => 'Delete My Account & Data';

  @override
  String get deleteAccountSubtitle => 'Permanently remove all your data';

  @override
  String get deleteAccountConfirmTitle => 'Delete Account?';

  @override
  String get deleteAccountConfirmBody =>
      'This action is permanent and will remove all your tasks, categories, and settings from our servers.';

  @override
  String get deleteEverything => 'Delete Everything';

  @override
  String get deletionFailed =>
      'Deletion failed. You may need to sign out and back in first for security.';

  @override
  String get about => 'About';

  @override
  String get aboutApp => 'About ROCI\'s Tasks';

  @override
  String get aboutAppSubtitle => 'App version, support, and info';

  @override
  String get aboutAppDescription =>
      'ROCI\'s Tasks is designed to help you stay organized and productive. Built with Flutter, it provides a seamless experience for managing your daily tasks, categories, and schedule.';

  @override
  String get visitWebsite => 'Visit our Website';

  @override
  String get viewGitHub => 'GitHub Project';

  @override
  String get viewGitHubSubtitle => 'View the source code on GitHub';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get rocisTasksPro => 'ROCIs Tasks Pro';

  @override
  String get youAreProUser => 'You are a Pro user!';

  @override
  String get unlockPremiumFeatures => 'Unlock premium features';

  @override
  String get manageSubscription => 'Manage Subscription';

  @override
  String get manageSubscriptionSubtitle => 'Cancel or change your plan';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get unlockFullPotential => 'Unlock your full potential';

  @override
  String get unlimitedCategories => 'Unlimited Categories';

  @override
  String get unlimitedCategoriesDesc =>
      'Create as many categories as you need to stay organized.';

  @override
  String get premiumWidgets => 'Premium Widgets';

  @override
  String get premiumWidgetsDesc =>
      'Access to Month and Full Calendar home screen widgets.';

  @override
  String get subtasksAndChecklists => 'Subtasks & Checklists';

  @override
  String get subtasksAndChecklistsDesc =>
      'Break down complex tasks into smaller, manageable steps.';

  @override
  String get recurringTasks => 'Recurring Tasks';

  @override
  String get recurringTasksDesc =>
      'Automate repeating tasks with daily, weekly, monthly, or custom schedules.';

  @override
  String get viewPricingPlans => 'View Pricing Plans';

  @override
  String get proSubscriptionActive => 'Pro Subscription Active';

  @override
  String get welcomeToPro => 'Welcome to Pro!';

  @override
  String get pickAPlan => 'Pick a Plan';

  @override
  String get byContinuingAgreement => 'By continuing, you agree to our';

  @override
  String get purchasesRestored => 'Purchases restored successfully!';

  @override
  String get noActiveSubscription =>
      'No active subscription found for this account.';

  @override
  String get failedToRestore => 'Failed to restore purchases.';

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get subtasks => 'Subtasks';

  @override
  String get noSubtasksAdded => 'No subtasks added';

  @override
  String get enterSubtask => 'Enter subtask...';

  @override
  String get recurrence => 'Recurrence';

  @override
  String get repeat => 'Repeat';

  @override
  String get repeatNone => 'None';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get titleInvalidContent => 'Title contains invalid content';

  @override
  String get descriptionInvalidContent =>
      'Description contains invalid content';

  @override
  String get failedToSaveTask => 'Failed to save task. Please try again.';

  @override
  String get welcomeToApp => 'Welcome to ROCI\'s Tasks';

  @override
  String get signInToSync => 'Sign in to sync your tasks across devices';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInFailed => 'Sign in failed';

  @override
  String get onboardingWelcomeTitle => 'Welcome to ROCI\'s Tasks';

  @override
  String get onboardingWelcomeDesc =>
      'Organize your life with efficiency and style.';

  @override
  String get onboardingSyncTitle => 'Sync & Offline';

  @override
  String get onboardingSyncDesc =>
      'Your tasks follow you everywhere. Access them even without an internet connection.';

  @override
  String get onboardingGesturesTitle => 'Smart Gestures';

  @override
  String get onboardingGesturesDesc =>
      'Swipe left to delete, swipe right to complete. Long press for more options.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get next => 'Next';

  @override
  String get insights => 'Insights';

  @override
  String get searchTasksHint => 'Search tasks...';

  @override
  String get emptyTrash => 'Empty Trash';

  @override
  String get productivityTrend => 'Productivity Trend';

  @override
  String get categoryBreakdown => 'Category Breakdown';

  @override
  String get completed => 'Completed';

  @override
  String get pending => 'Pending';

  @override
  String taskReminderTitle(String title) {
    return 'Task Reminder: $title';
  }

  @override
  String get taskDueNowBody => 'You have a task due now!';

  @override
  String get createFirstTask => 'Create your first task';

  @override
  String get filterToday => 'Today';

  @override
  String get filterThisWeek => 'This Week';

  @override
  String get filterOverdue => 'Overdue';

  @override
  String get filterNoDate => 'No Date';

  @override
  String get dateRange => 'Date Filter';

  @override
  String get recurringTaskScheduled => 'Recurring Task Scheduled';

  @override
  String nextOccurrenceSet(String title, String date) {
    return 'Next occurrence of \"$title\" set for $date';
  }

  @override
  String get initializationFailedError =>
      'Failed to initialize app data. Please restart.';

  @override
  String get noTaskDataAvailable => 'No task data available';

  @override
  String get retryInitialization => 'Retry Initialization';

  @override
  String get criticalErrorTitle => 'CRITICAL ERROR';

  @override
  String get appStartupErrorBody =>
      'ROCI\'s Tasks encountered a problem during startup. Our team has been notified.';

  @override
  String get appTagline => 'Dotting the i\'s and crossing the t\'s';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get allDay => 'All Day';

  @override
  String get event => 'Event';

  @override
  String get markAsIncomplete => 'Mark as incomplete';

  @override
  String get markAsComplete => 'Mark as complete';

  @override
  String get editTaskDetailsHint => 'Double tap to edit task details';

  @override
  String get pinTask => 'Pin task';

  @override
  String get unpinTask => 'Unpin task';

  @override
  String get notificationSnooze => 'Snooze 15m';

  @override
  String get notificationMarkCompleted => 'Mark Completed';

  @override
  String get notificationOpenTask => 'Open Task';

  @override
  String notificationUncompletedTasks(int count) {
    return '$count Uncompleted Tasks';
  }

  @override
  String get notificationTasksRemaining => 'Tasks Remaining';

  @override
  String notificationTasksSummary(int count) {
    return '$count Tasks';
  }

  @override
  String get skip => 'Skip';

  @override
  String get productivity => 'Productivity';

  @override
  String get smartAdd => 'Smart Add (NLP)';

  @override
  String get autoRemoveNlpDates => 'Clean Title';

  @override
  String get autoRemoveNlpDatesSubtitle =>
      'Remove date/time from title when suggested';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get register => 'Register';

  @override
  String get createAccount => 'Create Account';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get invalidEmail => 'Please enter a valid email';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordResetEmailSent => 'Password reset email sent';

  @override
  String get showTaskCounterNotification => 'Show Task Counter';

  @override
  String get showTaskCounterNotificationSubtitle =>
      'Display a persistent notification with your task count';

  @override
  String get showMyTasksGuideShortcut => 'Show My Tasks help button';

  @override
  String get showMyTasksGuideShortcutSubtitle =>
      'Show a ? button in My Tasks that opens the App Guide';

  @override
  String get appGuide => 'App Guide';

  @override
  String get appGuideSubtitle => 'Learn how to use ROCI\'s Tasks';

  @override
  String get appGuideTitle => 'App Guide';

  @override
  String get features => 'Features';

  @override
  String get howToUse => 'How to Use';

  @override
  String get guideTaskDesc =>
      'Create, edit, and organize your daily tasks with ease.';

  @override
  String get guideCalendarDesc =>
      'View your tasks and events in a beautiful calendar view.';

  @override
  String get guideCategoriesDesc =>
      'Organize tasks into custom categories with unique icons and colors.';

  @override
  String get guidePriorityDesc =>
      'Use priorities to highlight what matters most.';

  @override
  String get guidePinningDesc =>
      'Pin important tasks to keep them at the top of your list.';

  @override
  String get guideAttachmentsDesc =>
      'Attach files and images to keep everything related to a task in one place.';

  @override
  String get guideNotificationsTitle => 'Notifications';

  @override
  String get guideNotificationsDesc =>
      'Stay on top of your schedule with smart reminders and a persistent task counter.';

  @override
  String get guideCloudSyncTitle => 'Cloud Sync';

  @override
  String get guideCloudSyncDesc =>
      'Access your tasks from any device with secure cloud synchronization.';

  @override
  String get guideAddingTasksTitle => 'Adding Tasks';

  @override
  String get guideAddingTasksDesc =>
      'Tap the + button to add a new task. Use natural language (e.g., \"Lunch tomorrow at 1pm\") for quick entry.';

  @override
  String get guideGesturesTitle => 'Gestures';

  @override
  String get guideGesturesDesc =>
      'Swipe right to complete a task, swipe left to delete it. Long-press for more options.';

  @override
  String get guideWidgetsTitle => 'Home Widgets';

  @override
  String get guideWidgetsDesc =>
      'Add ROCI\'s Tasks widgets to your home screen for quick access and status updates.';

  @override
  String get guideCustomizationTitle => 'Customization';

  @override
  String get guideCustomizationDesc =>
      'Personalize your experience in Settings with themes, language options, and more.';

  @override
  String get guideHappyOrganizing => 'Happy Organizing!';

  @override
  String get notificationRefreshed => 'Task counter notification refreshed';

  @override
  String get privateLabel => 'Private';

  @override
  String get privateCategory => 'Private category';

  @override
  String get privateCategorySubtitle =>
      'Hide tasks from widgets and previews when locked';

  @override
  String get privateMode => 'Private mode';

  @override
  String get privateModeSubtitle => 'Hide private categories when locked';

  @override
  String get lockPrivate => 'Lock private';

  @override
  String get unlockPrivate => 'Unlock private';

  @override
  String get hidePrivateCategories => 'Hide private categories';

  @override
  String get showPrivateCategories => 'Show private categories';

  @override
  String get setPinTitle => 'Set PIN';

  @override
  String get pinMinDigits => 'PIN (min 4 digits)';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get enterPinTitle => 'Enter PIN';

  @override
  String get pinLabel => 'PIN';

  @override
  String get unlock => 'Unlock';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String get pinsDoNotMatch => 'PINs do not match';

  @override
  String get advancedReminders => 'Advanced reminders';

  @override
  String get advancedRemindersSubtitle =>
      'Extra snooze buttons on task reminders';

  @override
  String get nagReminders => 'Nag reminders';

  @override
  String get nagRemindersSubtitle => 'Repeat reminders after a task is due';

  @override
  String get quietHours => 'Quiet hours';

  @override
  String get quietHoursSubtitle => 'Delay reminders during quiet hours';

  @override
  String get quietHoursStart => 'Quiet hours start';

  @override
  String get quietHoursEnd => 'Quiet hours end';

  @override
  String get nagInterval => 'Nag interval';

  @override
  String get nagCount => 'Nag count';

  @override
  String get snooze10m => 'Snooze 10m';

  @override
  String get snooze1h => 'Snooze 1h';

  @override
  String get tomorrowAtNine => 'Tomorrow 9:00';

  @override
  String get privateTask => 'Private task';

  @override
  String get privateTaskSubtitle => 'Unlock private mode to view details.';

  @override
  String get accentColor => 'Accent color';

  @override
  String get accentColorSubtitle => 'Customize the app colors (Pro)';

  @override
  String get requireSubTasksBeforeReminders => 'Subtasks required';

  @override
  String get requireSubTasksBeforeRemindersSubtitle =>
      'Don’t send reminders until all subtasks are completed';

  @override
  String get debugModeUnlocked => 'Debug mode unlocked!';

  @override
  String get submitBugReport => 'Submit Bug Report';

  @override
  String get submitBugReportSubtitle => 'Fill out our Google Form';

  @override
  String get testCrash => 'Test Crash';

  @override
  String get testCrashSubtitle => 'Simulate a crash for Crashlytics';

  @override
  String get biometricUnlock => 'Biometric Unlock';

  @override
  String get biometricUnlockSubtitle =>
      'Unlock private tasks with Face ID or fingerprint';

  @override
  String get useBiometrics => 'Use Biometrics';

  @override
  String get biometricNotAvailable => 'Biometrics not available on this device';

  @override
  String get biometricAuthReason => 'Authenticate to access private tasks';

  @override
  String get usePinInstead => 'Use PIN instead';

  @override
  String get securitySettings => 'Security Settings';

  @override
  String get securitySettingsSubtitle => 'Manage PIN and Biometric access';

  @override
  String get enableSecurity => 'Enable Security';

  @override
  String get enableSecurityDescription =>
      'You just created a private task. Set up a PIN or biometrics to keep your private content secure.';

  @override
  String get notNow => 'Not now';

  @override
  String get setUp => 'Set up';

  @override
  String get doNotRemind => 'Do not remind';

  @override
  String get doNotRemindSubtitle => 'Suppress all notifications for this task';

  @override
  String get glassmorphismEffects => 'Glassmorphism Effects';

  @override
  String get glassmorphismEffectsSubtitle => 'Apply frosted glass to cards';

  @override
  String get noEventsForThisDay => 'No events for this day';

  @override
  String get searchSymbols => 'Search Symbols';

  @override
  String get searchSymbolsDesc =>
      'Use symbols to filter tasks: @category (e.g. @work), #title (e.g. #meeting), !priority (e.g. !high), %date (e.g. %2025-06-15), &subtask (e.g. &fix bug), *status (*done or *pending), ? (tasks due today). Combine multiple symbols.';

  @override
  String get widgetSettings => 'Widget Customization';

  @override
  String get widgetSettingsSubtitle => 'Configure colors, theme, and features';

  @override
  String get widgetTheme => 'Widget Theme';

  @override
  String get widgetThemeSystem => 'System Default';

  @override
  String get widgetThemeLight => 'Solid Light';

  @override
  String get widgetThemeDark => 'Solid Dark';

  @override
  String get widgetThemeGlassmorphic => 'Glassmorphism';

  @override
  String get showWeekNumbers => 'Show Week Numbers';

  @override
  String get weekendHighlights => 'Highlight Weekends';

  @override
  String get startOfWeek => 'Start of Week';

  @override
  String get sunday => 'Sunday';

  @override
  String get monday => 'Monday';

  @override
  String get saturday => 'Saturday';

  @override
  String get widgetAccentColor => 'Widget Accent Color';

  @override
  String get widgetSuiteTitle => 'Available Home Widgets';

  @override
  String get widgetSuiteSubtitle =>
      'Choose from our suite of widgets. Free users can place 1 active widget on screen; Pro users can place unlimited widgets.';

  @override
  String get todayAgendaWidgetTitle => 'Day Agenda';

  @override
  String get todayAgendaWidgetSubtitle =>
      'Interactive day-by-day task & event viewer with instant completion.';

  @override
  String get monthAgendaWidgetTitle => 'Month & Agenda';

  @override
  String get monthAgendaWidgetSubtitle =>
      'Samsung-style split layout with monthly calendar grid and selected date agenda.';

  @override
  String get timelineAgendaWidgetTitle => 'Schedule Timeline';

  @override
  String get timelineAgendaWidgetSubtitle =>
      'Google-style continuous multi-day scrollable agenda timeline.';

  @override
  String get quickActionWidgetTitle => 'Quick Actions & Ring';

  @override
  String get quickActionWidgetSubtitle =>
      'One-tap task creation with live completion progress counter.';

  @override
  String get upNextWidgetTitle => 'Up Next Pill';

  @override
  String get upNextWidgetSubtitle =>
      'Minimalist card showing your next urgent task or meeting with countdown badge.';

  @override
  String get tasksWidgetTitle => 'Pending Tasks';

  @override
  String get tasksWidgetSubtitle =>
      'Scrollable task list with one-tap completion and smart filters.';

  @override
  String get googleTasksDisconnected => 'Google Tasks Disconnected';

  @override
  String get googleTasksDisconnectedSubtitle =>
      'Tap to reconnect and resume sync';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get webPaywallTitle => 'Unlock ROCIs Tasks Pro on Web';

  @override
  String get webPaywallSubtitle =>
      'Upgrade to premium to access all advanced features on any platform.';

  @override
  String get webSimulatedUpgradeBtn => 'Upgrade to Pro';

  @override
  String get webPaywallNotice =>
      'Payments are securely processed by Lemon Squeezy. Your subscription will be activated automatically.';

  @override
  String get monthlyPlanTitle => 'Monthly Plan';

  @override
  String get monthlyPlanPrice => '\$4.99 / month';

  @override
  String get yearlyPlanTitle => 'Yearly Plan';

  @override
  String get yearlyPlanPrice => '\$39.99 / year';

  @override
  String get yearlyPlanSaving => 'Save 33%';

  @override
  String get lifetimePlanTitle => 'Lifetime';

  @override
  String get lifetimePlanPrice => '\$49.99 once';

  @override
  String get lifetimePlanBadge => 'Best Value';

  @override
  String get groceryListMode => 'Task List';

  @override
  String get groceryListModeSubtitle =>
      'Format task as an interactive task list';

  @override
  String itemsInCart(Object completed, Object total) {
    return '$completed/$total completed';
  }

  @override
  String get toBuy => 'To Do';

  @override
  String get inCart => 'Completed';

  @override
  String get resetCart => 'Reset List';

  @override
  String get clearCartItems => 'Clear List Items';

  @override
  String get addItemHint => 'Add item...';

  @override
  String get quantityHint => 'Qty';

  @override
  String get timezone => 'Timezone';

  @override
  String get selectTimezone => 'Select Timezone';

  @override
  String get automaticTimezone => 'Automatic (Device Timezone)';

  @override
  String get searchTimezone => 'Search timezone...';

  @override
  String get repeatWeekdays => 'Weekdays (Mon–Fri)';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String get repeatCustom => 'Custom...';

  @override
  String get repeatsEvery => 'Repeats every';

  @override
  String get customRecurrence => 'Custom Recurrence';

  @override
  String get daySingular => 'day';

  @override
  String get daysPlural => 'days';

  @override
  String get weekSingular => 'week';

  @override
  String get weeksPlural => 'weeks';

  @override
  String get monthSingular => 'month';

  @override
  String get monthsPlural => 'months';

  @override
  String get yearSingular => 'year';

  @override
  String get yearsPlural => 'years';

  @override
  String get selectRecurrence => 'Select Recurrence';

  @override
  String get guestMode => 'Guest Mode';

  @override
  String get guestModeSubtitle =>
      'All data is stored locally on this device. Sign in to back up and sync with the cloud.';

  @override
  String get guestAccount => 'Guest Account';

  @override
  String get signInOrRegister => 'Sign In / Register';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get cloudSync => 'Cloud Backup & Sync';

  @override
  String get cloudSyncActive => 'Active & synced';

  @override
  String get customFields => 'Custom Lines';

  @override
  String get customFieldsSubtitle =>
      'Attach contacts, locations, links, or notes';

  @override
  String get addCustomField => 'Add Line';

  @override
  String get contact => 'Contact';

  @override
  String get location => 'Location';

  @override
  String get link => 'Link';

  @override
  String get note => 'Note';

  @override
  String get fieldLabel => 'Label';

  @override
  String get fieldValue => 'Value';

  @override
  String get enterContactInfo => 'Phone number or email';

  @override
  String get enterLocation => 'Address or place';

  @override
  String get enterUrl => 'Website or URL';

  @override
  String get enterNote => 'Custom details';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get noCustomFieldsAdded => 'No custom lines added';

  @override
  String get quickDateToday => 'Today';

  @override
  String get quickDateTomorrow => 'Tomorrow';

  @override
  String get quickDateThisWeekend => 'This Weekend';

  @override
  String get quickDateNextWeek => 'Next Week';

  @override
  String get templateStarterTitle => 'Quick Starter Templates';

  @override
  String get templateGroceryTitle => 'Grocery & Shopping List';

  @override
  String get templateGroceryDesc => 'Checklist for groceries & essentials';

  @override
  String get templateWorkTitle => 'Work Sprint Task';

  @override
  String get templateWorkDesc => 'High-priority project milestone';

  @override
  String get templateRoutineTitle => 'Daily Routine';

  @override
  String get templateRoutineDesc => 'Recurring daily morning habit';

  @override
  String get templateStudyTitle => 'Study & Assignment';

  @override
  String get templateStudyDesc => 'Track course reading & exercises';

  @override
  String completedTasksHeader(int count) {
    return 'Completed ($count)';
  }

  @override
  String get allCaughtUpToday => 'All done for today! 🎉';

  @override
  String get allCaughtUpSubtitle =>
      'Great job! Take a break or add a new task.';

  @override
  String get resetFilters => 'Reset All';

  @override
  String get rescheduleTask => 'Reschedule';

  @override
  String get plusOneDay => '+1 Day';

  @override
  String get plusOneWeek => '+1 Week';

  @override
  String get moveToToday => 'Move to Today';

  @override
  String get activeTasks => 'Active Tasks';
}
