// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'המשימות של ROCI';

  @override
  String get settings => 'הגדרות';

  @override
  String get account => 'חשבון';

  @override
  String get signOut => 'התנתק';

  @override
  String get appearance => 'מראה';

  @override
  String get darkMode => 'מצב כהה';

  @override
  String get materialTheme => 'עיצוב Material';

  @override
  String get useSystemColors => 'השתמש בצבעי המערכת';

  @override
  String get amoledDarkMode => 'מצב כהה AMOLED';

  @override
  String get pureBlackBackground => 'רקע שחור מוחלט';

  @override
  String get dataAndSync => 'נתונים וסנכרון';

  @override
  String get syncNow => 'סנכרן עכשיו';

  @override
  String get syncingTasks => 'מסנכרן משימות...';

  @override
  String get trash => 'אשפה';

  @override
  String get sortAndFilter => 'מיון וסינון';

  @override
  String get sortBy => 'מיין לפי';

  @override
  String get date => 'תאריך';

  @override
  String get priority => 'עדיפות';

  @override
  String get title => 'כותרת';

  @override
  String get createdDate => 'תאריך יצירה';

  @override
  String get filterByCategory => 'סנן לפי קטגוריה';

  @override
  String get all => 'הכל';

  @override
  String get showCompletedTasks => 'הצג משימות שהושלמו';

  @override
  String get done => 'בוצע';

  @override
  String get timeFormat24h => 'פורמט זמן 24 שעות';

  @override
  String get language => 'שפה';

  @override
  String get hebrew => 'עברית';

  @override
  String get english => 'אנגלית';

  @override
  String get spanish => 'ספרדית';

  @override
  String get tasks => 'משימות';

  @override
  String get editTask => 'ערוך משימה';

  @override
  String get newTask => 'משימה חדשה';

  @override
  String get description => 'תיאור';

  @override
  String get dueDateAndTime => 'תאריך ושעה לסיום';

  @override
  String get noDateSelected => 'לא נבחר תאריך';

  @override
  String get category => 'קטגוריה';

  @override
  String get noCategory => 'ללא קטגוריה';

  @override
  String get saveTask => 'שמור משימה';

  @override
  String get updateTask => 'עדכן משימה';

  @override
  String get pleaseEnterATitle => 'אנא הזן כותרת';

  @override
  String get high => 'גבוהה';

  @override
  String get medium => 'בינונית';

  @override
  String get low => 'נמוכה';

  @override
  String get priorityLabel => 'עדיפות';

  @override
  String get myTasks => 'המשימות שלי';

  @override
  String get calendar => 'לוח שנה';

  @override
  String get categories => 'קטגוריות';

  @override
  String get noCategoriesYet => 'אין קטגוריות עדיין';

  @override
  String get addCategory => 'הוסף קטגוריה';

  @override
  String get newCategory => 'קטגוריה חדשה';

  @override
  String get editCategory => 'ערוך קטגוריה';

  @override
  String get name => 'שם';

  @override
  String get color => 'צבע';

  @override
  String get icon => 'אייקון';

  @override
  String get cancel => 'ביטול';

  @override
  String get add => 'הוסף';

  @override
  String get save => 'שמור';

  @override
  String get trashTitle => 'אשפה';

  @override
  String get trashEmpty => 'האשפה ריקה';

  @override
  String restoredTask(Object title) {
    return 'המשימה \"$title\" שוחזרה';
  }

  @override
  String get deletePermanently => 'למחוק לצמיתות?';

  @override
  String get actionUndone => 'פעולה זו אינה ניתנת לביטול.';

  @override
  String get delete => 'מחק';

  @override
  String get noTasksYet => 'אין משימות עדיין';

  @override
  String get duePrefix => 'יעד: ';

  @override
  String get deleteTaskTitle => 'מחק משימה';

  @override
  String get deleteTaskConfirmation => 'האם אתה בטוח שברצונך למחוק משימה זו?';

  @override
  String get calendarColors => 'צבעי לוח שנה';

  @override
  String get calendarFiltersTitle => 'מסנני לוח שנה';

  @override
  String get showCalendarTasks => 'הצג משימות';

  @override
  String get showGoogleCalendar => 'הצג יומן Google';

  @override
  String get showRocisSchedule => 'הצג מערכת שעות ROCIs';

  @override
  String get taskColor => 'צבע משימות';

  @override
  String get googleCalendarColor => 'צבע יומן Google';

  @override
  String get scheduleColor => 'צבע מערכת שעות ROCIs';

  @override
  String get assignmentColor => 'צבע מטלות';

  @override
  String get resetColors => 'אפס לברירת מחדל';

  @override
  String get selectColor => 'בחר צבע';

  @override
  String get selectGoogleCalendars => 'בחר יומני Google';

  @override
  String get selectAll => 'בחר הכל';

  @override
  String get deselectAll => 'בטל בחירת הכל';

  @override
  String get offlineMode => 'מצב לא מקוון';

  @override
  String get syncComplete => 'הסנכרון הושלם';

  @override
  String get backupAndRestore => 'גיבוי ושחזור';

  @override
  String get exportData => 'ייצוא נתונים (JSON)';

  @override
  String get exportDataSubtitle => 'גבה את המשימות והקטגוריות שלך';

  @override
  String get backupCopied => 'הגיבוי הועתק ללוח!';

  @override
  String exportFailed(String error) {
    return 'הייצוא נכשל: $error';
  }

  @override
  String get importData => 'ייבוא נתונים (JSON)';

  @override
  String get importDataSubtitle => 'שחזר מגיבוי JSON';

  @override
  String get importBackup => 'ייבוא גיבוי';

  @override
  String get pasteJsonHint => 'הדבק גיבוי JSON כאן...';

  @override
  String get import => 'ייבא';

  @override
  String get importComplete => 'הייבוא הושלם!';

  @override
  String importFailed(String error) {
    return 'הייבוא נכשל: $error';
  }

  @override
  String get privacyAndGdpr => 'פרטיות ו-GDPR';

  @override
  String get privacyPolicy => 'מדיניות פרטיות';

  @override
  String get privacyPolicySubtitle => 'קרא את תנאי אבטחת הנתונים שלנו';

  @override
  String get deleteAccountTitle => 'מחק את החשבון והנתונים שלי';

  @override
  String get deleteAccountSubtitle => 'הסר לצמיתות את כל הנתונים שלך';

  @override
  String get deleteAccountConfirmTitle => 'למחוק חשבון?';

  @override
  String get deleteAccountConfirmBody =>
      'פעולה זו הינה קבועה ותסיר את כל המשימות, הקטגוריות וההגדרות שלך מהשרתים שלנו.';

  @override
  String get deleteEverything => 'מחק הכל';

  @override
  String get deletionFailed =>
      'המחיקה נכשלה. ייתכן שתצטרך להתנתק ולהתחבר מחדש מסיבות אבטחה.';

  @override
  String get about => 'אודות';

  @override
  String get aboutApp => 'אודות ROCIs Tasks';

  @override
  String get aboutAppSubtitle => 'גרסת אפליקציה, תמיכה ומידע';

  @override
  String get aboutAppDescription =>
      'ROCIs Tasks נועד לעזור לך להישאר מאורגן ופרודוקטיבי. בנוי עם Flutter, הוא מספק חוויה חלקה לניהול המשימות, הקטגוריות והלוח הזמנים היומי שלך.';

  @override
  String get visitWebsite => 'בקר באתר שלנו';

  @override
  String get contactSupport => 'צור קשר עם התמיכה';

  @override
  String get rocisTasksPro => 'ROCIs Tasks Pro';

  @override
  String get youAreProUser => 'אתה משתמש Pro!';

  @override
  String get unlockPremiumFeatures => 'גלה תכונות פרמיום';

  @override
  String get manageSubscription => 'נהל מנוי';

  @override
  String get manageSubscriptionSubtitle => 'בטל או שנה את התכנית שלך';

  @override
  String get upgradeToPro => 'שדרג ל-Pro';

  @override
  String get unlockFullPotential => 'שחרר את הפוטנציאל המלא שלך';

  @override
  String get unlimitedCategories => 'קטגוריות ללא הגבלה';

  @override
  String get unlimitedCategoriesDesc =>
      'צור כמה קטגוריות שתרצה כדי להישאר מאורגן.';

  @override
  String get premiumWidgets => 'ווידג\'טים פרמיום';

  @override
  String get premiumWidgetsDesc =>
      'גישה לווידג\'טי מסך הבית של חודש ולוח שנה מלא.';

  @override
  String get subtasksAndChecklists => 'משימות משנה ורשימות תיוג';

  @override
  String get subtasksAndChecklistsDesc =>
      'פרק משימות מורכבות לצעדים קטנים וניתנים לניהול.';

  @override
  String get recurringTasks => 'משימות חוזרות';

  @override
  String get recurringTasksDesc => 'אוטומט את השגרה שלך עם כללי חזרה גמישים.';

  @override
  String get viewPricingPlans => 'צפה בתוכניות תמחור';

  @override
  String get proSubscriptionActive => 'מנוי Pro פעיל';

  @override
  String get purchasesRestored => 'הרכישות שוחזרו בהצלחה!';

  @override
  String get noActiveSubscription => 'לא נמצא מנוי פעיל עבור חשבון זה.';

  @override
  String get failedToRestore => 'שחזור הרכישות נכשל.';

  @override
  String get restorePurchases => 'שחזר רכישות';

  @override
  String get subtasks => 'משימות משנה';

  @override
  String get noSubtasksAdded => 'לא נוספו משימות משנה';

  @override
  String get enterSubtask => 'הזן משימת משנה...';

  @override
  String get recurrence => 'חזרה';

  @override
  String get repeat => 'חזור';

  @override
  String get repeatNone => 'ללא';

  @override
  String get repeatDaily => 'יומי';

  @override
  String get repeatWeekly => 'שבועי';

  @override
  String get repeatMonthly => 'חודשי';

  @override
  String get titleInvalidContent => 'הכותרת מכילה תוכן לא תקין';

  @override
  String get descriptionInvalidContent => 'התיאור מכיל תוכן לא תקין';

  @override
  String get failedToSaveTask => 'שמירת המשימה נכשלה. אנא נסה שוב.';

  @override
  String get welcomeToApp => 'ברוך הבא ל-ROCIs Tasks';

  @override
  String get signInToSync => 'התחבר כדי לסנכרן את המשימות שלך בין מכשירים';

  @override
  String get signInWithGoogle => 'התחבר עם Google';

  @override
  String get signInFailed => 'ההתחברות נכשלה';

  @override
  String get onboardingWelcomeTitle => 'ברוך הבא ל-ROCIs Tasks';

  @override
  String get onboardingWelcomeDesc => 'ארגן את חייך ביעילות ובסגנון.';

  @override
  String get onboardingSyncTitle => 'סנכרון ומצב לא מקוון';

  @override
  String get onboardingSyncDesc =>
      'המשימות שלך עוקבות אחריך לכל מקום. גש אליהן גם ללא חיבור לאינטרנט.';

  @override
  String get onboardingGesturesTitle => 'מחוות חכמות';

  @override
  String get onboardingGesturesDesc =>
      'החלק שמאלה למחיקה, ימינה להשלמה. לחץ לחיצה ארוכה לאפשרויות נוספות.';

  @override
  String get getStarted => 'בוא נתחיל';

  @override
  String get next => 'הבא';

  @override
  String get searchTasksHint => 'חפש משימות...';

  @override
  String get emptyTrash => 'רוקן אשפה';
}
