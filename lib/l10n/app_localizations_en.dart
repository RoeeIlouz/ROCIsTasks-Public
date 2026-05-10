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
  String get tasks => 'Tasks';

  @override
  String get editTask => 'Edit Task';

  @override
  String get newTask => 'New Task';

  @override
  String get description => 'Description';

  @override
  String get dueDateAndTime => 'Due Date & Time';

  @override
  String get noDateSelected => 'No Date Selected';

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
  String restoredTask(Object title) {
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
      'Automate your routine with flexible repetition rules.';

  @override
  String get viewPricingPlans => 'View Pricing Plans';

  @override
  String get proSubscriptionActive => 'Pro Subscription Active';

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
  String get searchTasksHint => 'Search tasks...';

  @override
  String get emptyTrash => 'Empty Trash';
}
