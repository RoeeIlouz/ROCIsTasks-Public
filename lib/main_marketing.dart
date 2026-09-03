import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:rocis_tasks/main.dart';
import 'package:rocis_tasks/core/services/app_initializer.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppInitializer.initialize();
  } catch (e) {
    debugPrint('Marketing init error: $e');
  }

  // Check URL query params if on web
  final isLight = kIsWeb && Uri.base.queryParameters['theme'] == 'light';
  final isAmoled = kIsWeb && Uri.base.queryParameters['amoled'] == 'true';
  final lang = (kIsWeb ? Uri.base.queryParameters['lang'] : null) ?? 'en';

  // Seed SharedPreferences
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', isLight ? 1 : 2); // 1 = light, 2 = dark
    await prefs.setBool('use_amoled_theme', isAmoled);
    await prefs.setBool('use_material_theme', false);
    await prefs.setString('language_code', lang);
    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('web_is_premium', true);
    await prefs.setBool('disable_cloud_sync', true);
    await prefs.remove('google_access_token');
  } catch (e) {
    debugPrint('Error setting SharedPreferences: $e');
  }

  // Authenticate QA Pro user
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInWithEmailAndPassword(
        email: 'qa@rocisapps.com',
        password: 'Qa123456123456',
      );
    }
  } catch (e) {
    debugPrint('QA sign-in error in main_marketing: $e');
  }

  // Seed Hive
  try {
    final settingsBox = Hive.box('settings');
    await settingsBox.put('onboarding_complete', true);
    await settingsBox.put('theme_mode', isLight ? 1 : 2);

    final catBox = Hive.box<Category>('categoriesBox');
    await catBox.clear();

    final categories = _getLocalizedCategories(lang);
    for (final cat in categories.values) {
      await catBox.put(cat.id, cat);
    }

    final tasksBox = Hive.box<Task>('tasksBox');
    await tasksBox.clear();

    final tasks = _getLocalizedTasks(lang, categories);
    for (final t in tasks) {
      await tasksBox.put(t.id, t);
    }
  } catch (e) {
    debugPrint('Error seeding Hive marketing data: $e');
  }

  runApp(const AppRoot());
}

Map<String, Category> _getLocalizedCategories(String lang) {
  final Map<String, Map<String, String>> names = {
    'en': {
      'work': 'Work & Projects',
      'health': 'Health & Fitness',
      'personal': 'Personal & Groceries',
      'strategy': 'Strategy & Goals',
      'dev': 'Development',
    },
    'he': {
      'work': 'עבודה ופרויקטים',
      'health': 'בריאות וכושר',
      'personal': 'אישי וקניות',
      'strategy': 'אסטרטגיה ויעדים',
      'dev': 'פיתוח תוכנה',
    },
    'es': {
      'work': 'Trabajo y Proyectos',
      'health': 'Salud y Fitness',
      'personal': 'Personal y Compras',
      'strategy': 'Estrategia y Metas',
      'dev': 'Desarrollo',
    },
    'de': {
      'work': 'Arbeit & Projekte',
      'health': 'Gesundheit & Fitness',
      'personal': 'Privat & Einkäufe',
      'strategy': 'Strategie & Ziele',
      'dev': 'Entwicklung',
    },
    'fr': {
      'work': 'Travail & Projets',
      'health': 'Santé & Forme',
      'personal': 'Personnel & Courses',
      'strategy': 'Stratégie & Objectifs',
      'dev': 'Développement',
    },
    'ar': {
      'work': 'العمل والمشاريع',
      'health': 'الصحة واللياقة',
      'personal': 'شخصي ومشتريات',
      'strategy': 'الاستراتيجية والأهداف',
      'dev': 'تطوير البرمجيات',
    },
    'sv': {
      'work': 'Arbete & Projekt',
      'health': 'Hälsa & Träning',
      'personal': 'Privat & Handla',
      'strategy': 'Strategi & Mål',
      'dev': 'Utveckling',
    },
    'hi': {
      'work': 'कार्य और परियोजनाएं',
      'health': 'स्वास्थ्य और फिटनेस',
      'personal': 'व्यक्तिगत और खरीदारी',
      'strategy': 'रणनीति और लक्ष्य',
      'dev': 'सॉफ्टवेयर विकास',
    },
  };

  final dict = names[lang] ?? names['en']!;

  return {
    'work': Category(
      id: 'cat_work',
      name: dict['work']!,
      colorValue: 0xFFEF3842, // Crimson
      iconCode: Icons.work_outline_rounded.codePoint,
    ),
    'health': Category(
      id: 'cat_health',
      name: dict['health']!,
      colorValue: 0xFF10B981, // Emerald
      iconCode: Icons.directions_run_rounded.codePoint,
    ),
    'personal': Category(
      id: 'cat_personal',
      name: dict['personal']!,
      colorValue: 0xFFF59E0B, // Amber
      iconCode: Icons.shopping_cart_outlined.codePoint,
    ),
    'strategy': Category(
      id: 'cat_strategy',
      name: dict['strategy']!,
      colorValue: 0xFF8B5CF6, // Purple
      iconCode: Icons.track_changes_rounded.codePoint,
    ),
    'dev': Category(
      id: 'cat_dev',
      name: dict['dev']!,
      colorValue: 0xFF3B82F6, // Blue
      iconCode: Icons.code_rounded.codePoint,
    ),
  };
}

List<Task> _getLocalizedTasks(String lang, Map<String, Category> categories) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  final workCat = categories['work']!;
  final healthCat = categories['health']!;
  final personalCat = categories['personal']!;
  final strategyCat = categories['strategy']!;
  final devCat = categories['dev']!;

  // Localized string sets
  final isHe = lang == 'he';
  final isEs = lang == 'es';
  final isDe = lang == 'de';
  final isFr = lang == 'fr';
  final isAr = lang == 'ar';
  final isSv = lang == 'sv';
  final isHi = lang == 'hi';

  return [
    Task(
      id: 'task_1',
      title: isHe
          ? 'סקירת ספרינט ושחרור גרסה'
          : isEs
          ? 'Revisión de sprint y versión candidata'
          : isDe
          ? 'Sprint-Review & Release-Kandidat'
          : isFr
          ? 'Revue de sprint & version finale'
          : isAr
          ? 'مراجعة السبرنت وإصدار النسخة'
          : isSv
          ? 'Sprintgranskning & releasekandidat'
          : isHi
          ? 'स्प्रिंट समीक्षा और रिलीज़ उम्मीदवार'
          : 'Sprint review & release candidate',
      description: isHe
          ? 'השלמת בדיקות אוטומטיות, יצירת חבילת התקנה ובדיקת שינויים לפני פריסה.'
          : isEs
          ? 'Finalizar pruebas automáticas, compilar paquete de lanzamiento y revisar PRs.'
          : isDe
          ? 'Automatisierte Tests abschließen, Release-Bundle erstellen und PRs prüfen.'
          : isFr
          ? 'Finaliser les tests automatisés, créer le bundle de release et valider les PR.'
          : isAr
          ? 'إنهاء الاختبارات الآلية، بناء حزمة الإصدار ومراجعة التغييرات قبل النشر.'
          : isSv
          ? 'Slutför automatiska tester, bygg releasepaket och granska ändringar.'
          : isHi
          ? 'स्वचालित परीक्षण पूरे करें, रिलीज़ बंडल बनाएं और समीक्षा करें।'
          : 'Finalize automated tests, build release bundle, and review PRs before deployment.',
      priority: TaskPriority.high,
      categoryId: workCat.id,
      categoryIds: [workCat.id],
      isPinned: true,
      dueDate: tomorrow.add(const Duration(hours: 10)),
      subTasks: [
        SubTask(
          id: 's1',
          title: isHe
              ? 'אימות מעבר כל הבדיקות 100%'
              : isEs
              ? 'Verificar 100% pruebas aprobadas'
              : isDe
              ? '100% Testsuite-Erfolg prüfen'
              : isFr
              ? 'Vérifier 100% de succès des tests'
              : isAr
              ? 'التحقق من نجاح جميع الاختبارات 100%'
              : isSv
              ? 'Verifiera 100% godkända tester'
              : isHi
              ? '100% परीक्षण पास सत्यापित करें'
              : 'Verify test suite 100% pass',
          isCompleted: true,
        ),
        SubTask(
          id: 's2',
          title: isHe
              ? 'בניית קובץ AAB ל-Google Play'
              : isEs
              ? 'Compilar AAB para Google Play'
              : isDe
              ? 'Play Store Release-AAB erstellen'
              : isFr
              ? 'Générer le fichier AAB pour Google Play'
              : isAr
              ? 'بناء حزمة AAB لمتجر Google Play'
              : isSv
              ? 'Bygg Google Play AAB-paket'
              : isHi
              ? 'Google Play के लिए AAB बंडल बनाएं'
              : 'Build Play Store release AAB',
          isCompleted: true,
        ),
        SubTask(
          id: 's3',
          title: isHe
              ? 'עדכון מספר גרסה ב-app_config'
              : isEs
              ? 'Actualizar versión en app_config'
              : isDe
              ? 'Versionsnummer in app_config erhöhen'
              : isFr
              ? 'Mettre à jour la version dans app_config'
              : isAr
              ? 'تحديث رقم الإصدار في app_config'
              : isSv
              ? 'Uppdatera versionsnummer i app_config'
              : isHi
              ? 'app_config में वर्शन अपडेट करें'
              : 'Bump version code in app_config',
          isCompleted: true,
        ),
        SubTask(
          id: 's4',
          title: isHe
              ? 'סקירת צילומי מסך וחומרי שיווק'
              : isEs
              ? 'Revisar capturas de pantalla'
              : isDe
              ? 'Marketing-Screenshots prüfen'
              : isFr
              ? 'Vérifier les captures d\'écran marketing'
              : isAr
              ? 'مراجعة لقطات الشاشة التسويقية'
              : isSv
              ? 'Granska marknadsföringsbilder'
              : isHi
              ? 'मार्केटिंग स्क्रीनशॉट की समीक्षा करें'
              : 'Review marketing assets & screenshots',
          isCompleted: false,
        ),
        SubTask(
          id: 's5',
          title: isHe
              ? 'פרסום הערות שחרור ב-GitHub'
              : isEs
              ? 'Publicar notas de versión en GitHub'
              : isDe
              ? 'Release Notes auf GitHub veröffentlichen'
              : isFr
              ? 'Publier les notes de version sur GitHub'
              : isAr
              ? 'نشر ملاحظات الإصدار على GitHub'
              : isSv
              ? 'Publicera versionsanteckningar på GitHub'
              : isHi
              ? 'GitHub पर रिलीज़ नोट्स प्रकाशित करें'
              : 'Publish release notes to GitHub',
          isCompleted: false,
        ),
      ],
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    Task(
      id: 'task_2',
      title: isHe
          ? 'ריצת בוקר 5 ק״מ ואימון'
          : isEs
          ? 'Carrera matutina de 5 km y entrenamiento'
          : isDe
          ? 'Morgendlicher 5-km-Lauf & Workout'
          : isFr
          ? 'Course matinale de 5 km & entraînement'
          : isAr
          ? 'ركض صباحي 5 كم وتمارين رياضية'
          : isSv
          ? 'Morgonjogg 5 km & träning'
          : isHi
          ? 'सुबह 5 किमी की दौड़ और कसरत'
          : 'Morning 5km jog & workout',
      description: isHe
          ? 'קצב של 4:55 לק״מ בפארק השכונתי.'
          : isEs
          ? 'Ritmo de 4:55/km en el parque del vecindario.'
          : isDe
          ? 'Tempo von 4:55/km im Stadtpark gelaufen.'
          : isFr
          ? 'Allure de 4:55/km dans le parc du quartier.'
          : isAr
          ? 'وتيرة 4:55 لكل كم في الحديقة المجاورة.'
          : isSv
          ? 'Tempo 4:55/km runt kvarterets park.'
          : isHi
          ? 'पार्क के चारों ओर 4:55/किमी की गति से दौड़।'
          : 'Paced at 4:55/km around the neighborhood park.',
      priority: TaskPriority.medium,
      categoryId: healthCat.id,
      categoryIds: [healthCat.id],
      isCompleted: true,
      completedAt: today.add(const Duration(hours: 7)),
      dueDate: today.add(const Duration(hours: 7)),
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    Task(
      id: 'task_3',
      title: isHe
          ? 'סקירת בקשות משיכה ובדיקות וידג\'ט'
          : isEs
          ? 'Revisar pull requests y pruebas de widgets'
          : isDe
          ? 'Pull Requests & Widget-Tests prüfen'
          : isFr
          ? 'Revoir les pull requests & tests widgets'
          : isAr
          ? 'مراجعة طلبات السحب واختبارات الويدجت'
          : isSv
          ? 'Granska pull requests & widget-tester'
          : isHi
          ? 'पुल अनुरोधों और विजेट परीक्षणों की समीक्षा करें'
          : 'Review pull requests & widget tests',
      description: isHe
          ? 'בדיקת ספקי וידג\'ט ב-Android Kotlin וסנכרון שפות.'
          : isEs
          ? 'Verificar proveedores HomeWidget de Android Kotlin y sincronización de idiomas.'
          : isDe
          ? 'Android Kotlin HomeWidget-Provider und Sprachs琍nchronisation prüfen.'
          : isFr
          ? 'Vérifier les fournisseurs HomeWidget Android Kotlin et synchronisation de langue.'
          : isAr
          ? 'فحص موفري Android Kotlin HomeWidget ومزامنة اللغات.'
          : isSv
          ? 'Kontrollera Android Kotlin HomeWidget-providers och språksynkronisering.'
          : isHi
          ? 'Android Kotlin HomeWidget प्रदाताओं और भाषा सिंक की जाँच करें।'
          : 'Check Android Kotlin HomeWidget providers and language synchronization.',
      priority: TaskPriority.medium,
      categoryId: devCat.id,
      categoryIds: [devCat.id],
      dueDate: today.add(const Duration(hours: 15)),
      subTasks: [
        SubTask(
          id: 's6',
          title: isHe
              ? 'אימות Kotlin RemoteViews'
              : isEs
              ? 'Verificar Kotlin RemoteViews'
              : isDe
              ? 'Kotlin RemoteViews prüfen'
              : isFr
              ? 'Vérifier Kotlin RemoteViews'
              : isAr
              ? 'التحقق من Kotlin RemoteViews'
              : isSv
              ? 'Verifiera Kotlin RemoteViews'
              : isHi
              ? 'Kotlin RemoteViews सत्यापित करें'
              : 'Verify Kotlin RemoteViews',
          isCompleted: true,
        ),
        SubTask(
          id: 's7',
          title: isHe
              ? 'בדיקת מחרוזות ברירת מחדל בשפה'
              : isEs
              ? 'Comprobar cadenas de idioma de respaldo'
              : isDe
              ? 'Locale Fallback-Strings prüfen'
              : isFr
              ? 'Vérifier les chaînes de repli de locale'
              : isAr
              ? 'فحص نصوص اللغة الاحتياطية'
              : isSv
              ? 'Kontrollera reservspråksträngar'
              : isHi
              ? 'लोकेल फ़ॉलबैक स्ट्रिंग्स की जाँच करें'
              : 'Check locale fallback strings',
          isCompleted: false,
        ),
      ],
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    Task(
      id: 'task_4',
      title: isHe
          ? 'קניות מצרכים לארוחת ערב'
          : isEs
          ? 'Comprar comida e ingredientes para la cena'
          : isDe
          ? 'Lebensmittel & Abendessen einkaufen'
          : isFr
          ? 'Faire les courses pour le dîner'
          : isAr
          ? 'شراء البقالة ومكونات العشاء'
          : isSv
          ? 'Handla mat & ingredienser till middag'
          : isHi
          ? 'किराने का सामान और रात के खाने की सामग्री खरीदें'
          : 'Buy groceries & dinner ingredients',
      description: isHe
          ? 'קניות שבועיות אורגניות בסופרמרקט.'
          : isEs
          ? 'Compra semanal de alimentos frescos orgánicos.'
          : isDe
          ? 'Wöchentlicher Bio-Einkauf im Supermarkt.'
          : isFr
          ? 'Courses hebdomadaires au marché bio.'
          : isAr
          ? 'تسوق أسبوعي للمنتجات العضوية الطازجة.'
          : isSv
          ? 'Veckans ekologiska matvaruhandling.'
          : isHi
          ? 'सप्ताहिक ताज़ा किराना खरीदारी।'
          : 'Weekly organic grocery run at Trader Joe\'s.',
      priority: TaskPriority.low,
      categoryId: personalCat.id,
      categoryIds: [personalCat.id],
      dueDate: today.add(const Duration(hours: 19)),
      subTasks: [
        SubTask(
          id: 's8',
          title: isHe
              ? 'אבוקדו, מחמצת וחלב שיבולת שועל'
              : isEs
              ? 'Aguacates, masa madre, leche de avena'
              : isDe
              ? 'Avocados, Sauerteigbrot, Hafermilch'
              : isFr
              ? 'Avocats, pain au levain, lait d\'avoine'
              : isAr
              ? 'أفوكادو، خبز العجين المخمر، حليب الشوفان'
              : isSv
              ? 'Avokado, surdegsbröd, havremjölk'
              : isHi
              ? 'एवोकैडो, खट्टी रोटी, ओट का दूध'
              : 'Avocados, sourdough, oat milk',
          isCompleted: true,
        ),
        SubTask(
          id: 's9',
          title: isHe
              ? 'יוגורט יווני ודבש'
              : isEs
              ? 'Yogur griego y miel'
              : isDe
              ? 'Griechischer Joghurt & Honig'
              : isFr
              ? 'Yaourt grec et miel'
              : isAr
              ? 'زبادي يوناني وعسل'
              : isSv
              ? 'Grekisk yoghurt & honung'
              : isHi
              ? 'ग्रीक दही और शहद'
              : 'Greek yogurt & honey',
          isCompleted: true,
        ),
        SubTask(
          id: 's10',
          title: isHe
              ? 'פילה סלמון ואספרגוס'
              : isEs
              ? 'Filetes de salmón y espárragos'
              : isDe
              ? 'Lachsfilets & Spargel'
              : isFr
              ? 'Pavés de saumon & asperges'
              : isAr
              ? 'شرائح السلمون والهليون'
              : isSv
              ? 'Laxfiléer & sparris'
              : isHi
              ? 'सामन पट्टिका और शतावरी'
              : 'Salmon fillets & asparagus',
          isCompleted: true,
        ),
      ],
      createdAt: now.subtract(const Duration(hours: 12)),
    ),
    Task(
      id: 'task_5',
      title: isHe
          ? 'גיבוש אסטרטגיית מפת דרכים לרבעון 4'
          : isEs
          ? 'Finalizar estrategia de hoja de ruta T4'
          : isDe
          ? 'Q4-Roadmap-Strategie finalisieren'
          : isFr
          ? 'Finaliser la feuille de route du T4'
          : isAr
          ? 'وضع اللمسات الأخيرة لخطة الربع الرابع'
          : isSv
          ? 'Slutför strategi för Q4-översikt'
          : isHi
          ? 'Q4 रोडमैप रणनीति को अंतिम रूप दें'
          : 'Finalize Q4 Roadmap Strategy',
      description: isHe
          ? 'הצגת ניתוח משובי משתמשים ותעדוף תכונות אופליין לצוות.'
          : isEs
          ? 'Presentar análisis de opiniones y prioridades offline al equipo.'
          : isDe
          ? 'Nutzerfeedback-Analyse und Offline-Prioritäten vorstellen.'
          : isFr
          ? 'Présenter l\'analyse des retours et priorités offline.'
          : isAr
          ? 'تقديم تحليل آراء المستخدمين وأولويات العمل بدون إنترنت.'
          : isSv
          ? 'Presentera användarfeedback och offlineläge.'
          : isHi
          ? 'उपयोगकर्ता प्रतिक्रिया विश्लेषण और टीम को प्रस्तुति।'
          : 'Present user feedback analysis and offline-first feature priorities to team.',
      priority: TaskPriority.high,
      categoryId: strategyCat.id,
      categoryIds: [strategyCat.id],
      dueDate: today.add(const Duration(days: 3, hours: 14)),
      createdAt: now.subtract(const Duration(days: 3)),
    ),
    Task(
      id: 'task_6',
      title: isHe
          ? 'שיחת בדיקה רפואית שנתית'
          : isEs
          ? 'Llamada de chequeo médico anual'
          : isDe
          ? 'Jährlicher Gesundheits-Checkup Anruf'
          : isFr
          ? 'Appel pour le bilan de santé annuel'
          : isAr
          ? 'مكالمة الفحص الطبي السنوي'
          : isSv
          ? 'Årligt hälsokontrollsamtal'
          : isHi
          ? 'वार्षिक स्वास्थ्य जांच कॉल'
          : 'Annual Health Checkup Call',
      description: isHe
          ? 'פגישת ייעוץ במרפאה.'
          : isEs
          ? 'Consulta con la clínica médica.'
          : isDe
          ? 'Beratungstermin mit der Praxisklinik.'
          : isFr
          ? 'Consultation avec le cabinet médical.'
          : isAr
          ? 'استشارة في عيادة الطبيب.'
          : isSv
          ? 'Konsultation med läkarmottagningen.'
          : isHi
          ? 'डॉक्टर क्लिनिक के साथ परामर्श।'
          : 'Consultation with Dr. Martin Clinic.',
      priority: TaskPriority.medium,
      categoryId: healthCat.id,
      categoryIds: [healthCat.id],
      dueDate: today.add(const Duration(days: 4, hours: 11)),
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    Task(
      id: 'task_7',
      title: isHe
          ? 'בקרת איכות לחוויית משתמש ועיצוב שקוף'
          : isEs
          ? 'Control de calidad UX móvil y diseño glassmorphic'
          : isDe
          ? 'Mobile UX & Glassmorphic Design QA'
          : isFr
          ? 'QA Design Mobile & Glassmorphisme'
          : isAr
          ? 'مراجعة جودة تصميم واجهة المستخدم الشفافة'
          : isSv
          ? 'Mobil UX & glasdesign-granskning'
          : isHi
          ? 'मोबाइल UX और ग्लास डिजाइन QA'
          : 'Mobile UX & Glassmorphic Design QA',
      description: isHe
          ? 'אימות שקיפות גבולות 10-18% ויחסי ניגודיות נגישות.'
          : isEs
          ? 'Verificar bordes con tinte 10-18% y accesibilidad.'
          : isDe
          ? '10-18% Farbton-Ränder und Barrierefreiheit prüfen.'
          : isFr
          ? 'Vérifier la teinte des bordures à 10-18% et accessibilité.'
          : isAr
          ? 'التحقق من حواف الشفافية 10-18% ونسب التباين.'
          : isSv
          ? 'Verifiera 10-18% kantfärg och tillgänglighet.'
          : isHi
          ? '10-18% टिंट बॉर्डर और सुगमता अनुपात।'
          : 'Verify 10-18% tint borders and accessibility contrast ratios.',
      priority: TaskPriority.low,
      categoryId: workCat.id,
      categoryIds: [workCat.id],
      isCompleted: true,
      completedAt: today.add(const Duration(hours: 12)),
      dueDate: today.add(const Duration(hours: 12)),
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    Task(
      id: 'task_8',
      title: isHe
          ? 'קריאת ערב: פרק 5 הרגלים'
          : isEs
          ? 'Lectura nocturna: Capítulo 5 Hábitos'
          : isDe
          ? 'Abendlektüre: Kapitel 5 Gewohnheiten'
          : isFr
          ? 'Lecture du soir: Chapitre 5 Habitudes'
          : isAr
          ? 'قراءة المساء: الفصل الخامس من العادات'
          : isSv
          ? 'Kvällsläsning: Kapitel 5 Vanor'
          : isHi
          ? 'शाम का अध्ययन: अध्याय 5 आदतें'
          : 'Evening reading: Chapter 5 Habits',
      description: isHe
          ? 'קריאה מעמיקה בהרגלים אטומיים לפני השינה.'
          : isEs
          ? 'Profundizar en Hábitos Atómicos antes de dormir.'
          : isDe
          ? 'Atomic Habits vor dem Schlafengehen vertiefen.'
          : isFr
          ? 'Lecture approfondie d\'Atomic Habits avant de dormir.'
          : isAr
          ? 'قراءة متعمقة في كتاب العادات الذرية قبل النوم.'
          : isSv
          ? 'Fördjupning i Atomvanor innan läggdags.'
          : isHi
          ? 'सोने से पहले एटॉमिक हैबिट्स का गहरा अध्ययन।'
          : 'Atomic Habits deep dive before bedtime.',
      priority: TaskPriority.low,
      categoryId: personalCat.id,
      categoryIds: [personalCat.id],
      dueDate: today.add(const Duration(hours: 22)),
      createdAt: now.subtract(const Duration(hours: 6)),
    ),
  ];
}
