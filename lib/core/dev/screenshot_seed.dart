import 'package:flutter/material.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';

/// Store-screenshot demo data in the app language. Only compiled in with
/// `--dart-define=SCREENSHOT_SEED=true` (a compile-time constant, so release
/// builds never touch user data). Replaces all local tasks and categories.
class ScreenshotSeed {
  ScreenshotSeed._();

  static const enabled = bool.fromEnvironment('SCREENSHOT_SEED');

  // Work, Personal, Health, Home, Study.
  static const _categories = {
    'en': ['Work', 'Personal', 'Health', 'Home', 'Study'],
    'he': ['עבודה', 'אישי', 'בריאות', 'בית', 'לימודים'],
    'es': ['Trabajo', 'Personal', 'Salud', 'Hogar', 'Estudio'],
    'de': ['Arbeit', 'Privat', 'Gesundheit', 'Zuhause', 'Studium'],
    'fr': ['Travail', 'Perso', 'Santé', 'Maison', 'Études'],
    'ar': ['العمل', 'شخصي', 'الصحة', 'المنزل', 'الدراسة'],
    'sv': ['Jobb', 'Privat', 'Hälsa', 'Hemma', 'Studier'],
    'hi': ['काम', 'निजी', 'सेहत', 'घर', 'पढ़ाई'],
  };

  static const _titles = {
    'en': [
      'Team standup',
      'Finish pitch deck',
      'Pick up dry cleaning',
      'Read 20 pages',
      'Gym session',
      'Book dentist',
      'Plan weekend trip',
      'Call mom',
      'Pay electricity bill',
      'Statistics exam prep',
      'Grocery run',
      'Submit expense report',
    ],
    'he': [
      'ישיבת צוות',
      'לסיים מצגת משקיעים',
      'לאסוף כביסה מהמכבסה',
      'לקרוא 20 עמודים',
      'אימון בחדר כושר',
      'לקבוע תור לרופא שיניים',
      'לתכנן טיול לסופ״ש',
      'להתקשר לאמא',
      'לשלם חשבון חשמל',
      'ללמוד למבחן בסטטיסטיקה',
      'קניות בסופר',
      'להגיש דוח הוצאות',
    ],
    'es': [
      'Reunión de equipo',
      'Terminar la presentación',
      'Recoger la tintorería',
      'Leer 20 páginas',
      'Ir al gimnasio',
      'Pedir cita al dentista',
      'Planear escapada de finde',
      'Llamar a mamá',
      'Pagar la luz',
      'Estudiar para estadística',
      'Hacer la compra',
      'Enviar informe de gastos',
    ],
    'de': [
      'Team-Standup',
      'Pitch-Deck fertigstellen',
      'Reinigung abholen',
      '20 Seiten lesen',
      'Fitnessstudio',
      'Zahnarzttermin machen',
      'Wochenendtrip planen',
      'Mama anrufen',
      'Stromrechnung bezahlen',
      'Statistik-Prüfung lernen',
      'Einkaufen',
      'Spesenabrechnung einreichen',
    ],
    'fr': [
      'Point d’équipe',
      'Finir le pitch deck',
      'Récupérer le pressing',
      'Lire 20 pages',
      'Séance de sport',
      'Prendre RDV dentiste',
      'Organiser le week-end',
      'Appeler maman',
      'Payer l’électricité',
      'Réviser les statistiques',
      'Faire les courses',
      'Envoyer la note de frais',
    ],
    'ar': [
      'اجتماع الفريق',
      'إنهاء العرض التقديمي',
      'استلام الملابس من المغسلة',
      'قراءة 20 صفحة',
      'تمرين في النادي',
      'حجز موعد طبيب الأسنان',
      'التخطيط لرحلة الويكند',
      'الاتصال بأمي',
      'دفع فاتورة الكهرباء',
      'المذاكرة لامتحان الإحصاء',
      'التسوق من البقالة',
      'تقديم تقرير المصاريف',
    ],
    'sv': [
      'Teammöte',
      'Bli klar med pitchen',
      'Hämta kemtvätten',
      'Läsa 20 sidor',
      'Gympass',
      'Boka tandläkare',
      'Planera helgresa',
      'Ringa mamma',
      'Betala elräkningen',
      'Plugga till statistiktentan',
      'Handla mat',
      'Lämna in utläggsrapport',
    ],
    'hi': [
      'टीम मीटिंग',
      'पिच डेक पूरा करें',
      'ड्राई क्लीनिंग लें',
      '20 पेज पढ़ें',
      'जिम जाना',
      'डेंटिस्ट की अपॉइंटमेंट',
      'वीकेंड ट्रिप प्लान करें',
      'मम्मी को फ़ोन',
      'बिजली का बिल भरें',
      'स्टैटिस्टिक्स परीक्षा की तैयारी',
      'किराने की खरीदारी',
      'खर्च रिपोर्ट जमा करें',
    ],
  };

  static const _colors = [
    0xFF3B82F6, 0xFFEC4899, 0xFF10B981, 0xFFF59E0B, 0xFF8B5CF6, //
  ];
  static final _icons = [
    Icons.work,
    Icons.local_cafe,
    Icons.fitness_center,
    Icons.home,
    Icons.school,
  ];

  static Future<void> apply(LocalTaskSource source, String language) async {
    final lang = _titles.containsKey(language) ? language : 'en';
    await source.clearAll();

    final categories = [
      for (var i = 0; i < 5; i++)
        Category(
          id: 'demo-cat-$i',
          name: _categories[lang]![i],
          colorValue: _colors[i],
          iconCode: _icons[i].codePoint,
        ),
    ];
    for (final c in categories) {
      await source.addCategory(c);
    }

    // Today's items start about 30 minutes from now, so Up Next has a countdown.
    final now = DateTime.now();
    final soon = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(Duration(minutes: 30 - now.minute % 5));
    DateTime day(int d, [int h = 0, int m = 0]) =>
        DateTime(now.year, now.month, now.day + d, h, m);

    // (due, priority, category)
    final plan = <(DateTime, TaskPriority, int)>[
      (soon, TaskPriority.high, 0),
      (soon.add(const Duration(hours: 2)), TaskPriority.high, 0),
      (soon.add(const Duration(hours: 3)), TaskPriority.medium, 1),
      (soon.add(const Duration(hours: 5)), TaskPriority.low, 1),
      (day(1, 7), TaskPriority.medium, 2),
      (day(1, 11), TaskPriority.medium, 2),
      (day(2, 10), TaskPriority.medium, 1),
      (day(3, 18), TaskPriority.medium, 1),
      (day(4), TaskPriority.high, 3),
      (day(5, 20), TaskPriority.high, 4),
      (day(6, 17), TaskPriority.medium, 3),
      (day(4), TaskPriority.medium, 0),
    ];
    for (var i = 0; i < plan.length; i++) {
      final (due, priority, cat) = plan[i];
      await source.addTask(
        Task(
          id: 'demo-task-$i',
          title: _titles[lang]![i],
          dueDate: due,
          priority: priority,
          categoryId: categories[cat].id,
          categoryIds: [categories[cat].id],
        ),
      );
    }
  }
}
