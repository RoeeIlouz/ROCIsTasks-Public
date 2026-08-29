import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

class NlpResult {
  final String title;
  final DateTime? dueDate;
  final bool hasTime;
  final TaskPriority? priority;
  final String? categoryId;
  final String? categoryName;

  NlpResult({
    required this.title,
    this.dueDate,
    this.hasTime = false,
    this.priority,
    this.categoryId,
    this.categoryName,
  });

  bool get hasAnySuggestion =>
      dueDate != null ||
      priority != null ||
      categoryId != null ||
      categoryName != null;
}

class NlpService {
  static final List<String> _daysOfWeek = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static NlpResult parse(String text, {List<Category>? categories}) {
    if (text.trim().isEmpty) return NlpResult(title: text);

    DateTime now = DateTime.now();
    DateTime? dueDate;
    bool hasTime = false;
    TaskPriority? priority;
    String? categoryId;
    String? categoryName;
    String cleanTitle = text;

    // 1. Priority parsing: !high, !urgent, !medium, !low, !1, !2, !3, p1, p2, p3
    final priorityBangRegex = RegExp(
      r'!(high|urgent|important|medium|med|normal|low|1|2|3)\b',
      caseSensitive: false,
    );
    final bangMatch = priorityBangRegex.firstMatch(cleanTitle);
    if (bangMatch != null) {
      final tag = bangMatch.group(1)!.toLowerCase();
      if (tag == 'high' ||
          tag == 'urgent' ||
          tag == 'important' ||
          tag == '1') {
        priority = TaskPriority.high;
      } else if (tag == 'medium' ||
          tag == 'med' ||
          tag == 'normal' ||
          tag == '2') {
        priority = TaskPriority.medium;
      } else if (tag == 'low' || tag == '3') {
        priority = TaskPriority.low;
      }
      cleanTitle = _removeMatch(cleanTitle, priorityBangRegex);
    } else {
      final pCodeRegex = RegExp(r'\b(p1|p2|p3)\b', caseSensitive: false);
      final pMatch = pCodeRegex.firstMatch(cleanTitle);
      if (pMatch != null) {
        final code = pMatch.group(1)!.toLowerCase();
        if (code == 'p1') priority = TaskPriority.high;
        if (code == 'p2') priority = TaskPriority.medium;
        if (code == 'p3') priority = TaskPriority.low;
        cleanTitle = _removeMatch(cleanTitle, pCodeRegex);
      }
    }

    // 2. Category hashtag parsing: #work, #personal, #shopping, #פרויקט
    final hashtagRegex = RegExp(
      r'#([a-zA-Z0-9_\u0590-\u05fe\u0600-\u06ff]+)',
      caseSensitive: false,
    );
    final hashMatch = hashtagRegex.firstMatch(cleanTitle);
    if (hashMatch != null) {
      final rawTagName = hashMatch.group(1)!;
      categoryName = rawTagName;

      if (categories != null && categories.isNotEmpty) {
        final lowerTag = rawTagName.toLowerCase();
        final matchedCat = categories.cast<Category?>().firstWhere(
          (c) =>
              c != null &&
              (c.name.toLowerCase() == lowerTag ||
                  c.name.toLowerCase().replaceAll(' ', '') == lowerTag),
          orElse: () => null,
        );
        if (matchedCat != null) {
          categoryId = matchedCat.id;
          categoryName = matchedCat.name;
        }
      }
      cleanTitle = _removeMatch(cleanTitle, hashtagRegex);
    }

    // 3. Check for relative day keywords ("in N days", "in N hours", "tonight")
    final inDaysRegex = RegExp(r'\bin\s+(\d+)\s+days?\b', caseSensitive: false);
    final inDaysMatch = inDaysRegex.firstMatch(cleanTitle);
    if (inDaysMatch != null) {
      final days = int.parse(inDaysMatch.group(1)!);
      final targetDate = now.add(Duration(days: days));
      dueDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
      cleanTitle = _removeMatch(cleanTitle, inDaysRegex);
    }

    final inHoursRegex = RegExp(
      r'\bin\s+(\d+)\s+(?:hours?|hrs?)\b',
      caseSensitive: false,
    );
    final inHoursMatch = inHoursRegex.firstMatch(cleanTitle);
    if (inHoursMatch != null && dueDate == null) {
      final hours = int.parse(inHoursMatch.group(1)!);
      dueDate = now.add(Duration(hours: hours));
      hasTime = true;
      cleanTitle = _removeMatch(cleanTitle, inHoursRegex);
    }

    final tonightRegex = RegExp(r'\btonight\b', caseSensitive: false);
    if (tonightRegex.hasMatch(cleanTitle) && dueDate == null) {
      dueDate = DateTime(now.year, now.month, now.day, 20, 0);
      hasTime = true;
      cleanTitle = _removeMatch(cleanTitle, tonightRegex);
    }

    final thisWeekendRegex = RegExp(
      r'\bthis\s+weekend\b',
      caseSensitive: false,
    );
    if (thisWeekendRegex.hasMatch(cleanTitle) && dueDate == null) {
      int daysUntilSaturday = (DateTime.saturday - now.weekday) % 7;
      if (daysUntilSaturday == 0 && now.hour >= 12) {
        daysUntilSaturday = 1;
      }
      final targetDate = now.add(Duration(days: daysUntilSaturday));
      dueDate = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        10,
        0,
      );
      hasTime = true;
      cleanTitle = _removeMatch(cleanTitle, thisWeekendRegex);
    }

    final nextWeekRegex = RegExp(r'\bnext\s+week\b', caseSensitive: false);
    if (nextWeekRegex.hasMatch(cleanTitle) && dueDate == null) {
      int daysUntilNextMonday = (DateTime.monday - now.weekday + 7) % 7;
      if (daysUntilNextMonday == 0) daysUntilNextMonday = 7;
      final targetDate = now.add(Duration(days: daysUntilNextMonday));
      dueDate = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        9,
        0,
      );
      hasTime = true;
      cleanTitle = _removeMatch(cleanTitle, nextWeekRegex);
    }

    // 4. Check for today / tomorrow
    final tomorrowRegex = RegExp(r'\btomorrow\b', caseSensitive: false);
    final todayRegex = RegExp(r'\btoday\b', caseSensitive: false);
    if (tomorrowRegex.hasMatch(cleanTitle) && dueDate == null) {
      final tomorrow = now.add(const Duration(days: 1));
      dueDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      cleanTitle = _removeMatch(cleanTitle, tomorrowRegex);
    } else if (todayRegex.hasMatch(cleanTitle) && dueDate == null) {
      dueDate = DateTime(now.year, now.month, now.day);
      cleanTitle = _removeMatch(cleanTitle, todayRegex);
    }

    // 5. Check for "next <weekday>" or "<weekday>"
    for (int i = 0; i < _daysOfWeek.length; i++) {
      String day = _daysOfWeek[i];
      final nextDayRegex = RegExp('\\bnext\\s+$day\\b', caseSensitive: false);
      final plainDayRegex = RegExp('\\b$day\\b', caseSensitive: false);

      if (nextDayRegex.hasMatch(cleanTitle) && dueDate == null) {
        int targetDay = i + 1; // 1 = Monday, 7 = Sunday
        int daysUntil = targetDay - now.weekday;
        if (daysUntil <= 0) daysUntil += 7;
        daysUntil += 7; // Next occurrence in following week
        DateTime targetDate = now.add(Duration(days: daysUntil));
        dueDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
        cleanTitle = _removeMatch(cleanTitle, nextDayRegex);
        break;
      } else if (plainDayRegex.hasMatch(cleanTitle) && dueDate == null) {
        int targetDay = i + 1; // 1 = Monday, 7 = Sunday
        int daysUntil = targetDay - now.weekday;
        if (daysUntil <= 0) daysUntil += 7;
        DateTime targetDate = now.add(Duration(days: daysUntil));
        dueDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
        cleanTitle = _removeMatch(cleanTitle, plainDayRegex);
        break;
      }
    }

    // 6. Check for time patterns (e.g. "at 5pm", "at 18:00", "at 2:30pm")
    final timeRegex = RegExp(
      r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
      caseSensitive: false,
    );
    final timeMatch = timeRegex.firstMatch(cleanTitle);

    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      int minute = timeMatch.group(2) != null
          ? int.parse(timeMatch.group(2)!)
          : 0;
      String? amPm = timeMatch.group(3)?.toLowerCase();

      if (amPm == 'pm' && hour < 12) hour += 12;
      if (amPm == 'am' && hour == 12) hour = 0;

      final baseDate = dueDate ?? DateTime(now.year, now.month, now.day);
      dueDate = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
      hasTime = true;
      cleanTitle = _removeMatch(cleanTitle, timeRegex);
    }

    // 7. Clean up prepositions left at edges and multiple spaces
    cleanTitle = cleanTitle
        .replaceAll(
          RegExp(r'\s+(?:on|at|by|for|due|in)\s*$', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'^(?:on|at|by|for|due|in)\s+', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    return NlpResult(
      title: cleanTitle,
      dueDate: dueDate,
      hasTime: hasTime,
      priority: priority,
      categoryId: categoryId,
      categoryName: categoryName,
    );
  }

  static String _removeMatch(String text, RegExp regex) {
    return text
        .replaceFirst(regex, ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}
