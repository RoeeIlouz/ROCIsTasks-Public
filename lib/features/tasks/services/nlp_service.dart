

class NlpResult {
  final String title;
  final DateTime? dueDate;
  final bool hasTime;

  NlpResult({
    required this.title,
    this.dueDate,
    this.hasTime = false,
  });
}

class NlpService {
  static final List<String> _daysOfWeek = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];

  static NlpResult parse(String text) {
    if (text.isEmpty) return NlpResult(title: text);

    String lowercaseText = text.toLowerCase();
    DateTime now = DateTime.now();
    DateTime? dueDate;
    bool hasTime = false;
    String cleanTitle = text;

    // 1. Check for relative days
    if (lowercaseText.contains('today')) {
      dueDate = DateTime(now.year, now.month, now.day);
      cleanTitle = _removeMatch(cleanTitle, RegExp(r'\btoday\b', caseSensitive: false));
    } else if (lowercaseText.contains('tomorrow')) {
      dueDate = now.add(const Duration(days: 1));
      dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
      cleanTitle = _removeMatch(cleanTitle, RegExp(r'\btomorrow\b', caseSensitive: false));
    }

    // 2. Check for days of week
    for (int i = 0; i < _daysOfWeek.length; i++) {
      String day = _daysOfWeek[i];
      if (lowercaseText.contains(day)) {
        int targetDay = i + 1; // 1 = Monday, 7 = Sunday
        int daysUntil = targetDay - now.weekday;
        if (daysUntil <= 0) daysUntil += 7;
        
        DateTime targetDate = now.add(Duration(days: daysUntil));
        dueDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
        cleanTitle = _removeMatch(cleanTitle, RegExp('\\b$day\\b', caseSensitive: false));
        break;
      }
    }

    // 3. Check for time patterns (e.g., "at 5pm", "at 18:00")
    final timeRegex = RegExp(r'at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false);
    final match = timeRegex.firstMatch(lowercaseText);
    
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      String? amPm = match.group(3)?.toLowerCase();

      if (amPm == 'pm' && hour < 12) hour += 12;
      if (amPm == 'am' && hour == 12) hour = 0;

      dueDate ??= DateTime(now.year, now.month, now.day);
      dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day, hour, minute);
      hasTime = true;
      cleanTitle = _removeMatch(cleanTitle, timeRegex);
    }

    // Trim trailing/leading whitespace and "on" prepositions if left behind
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\s+on\s*$', caseSensitive: false), '');
    cleanTitle = cleanTitle.trim();

    return NlpResult(
      title: cleanTitle,
      dueDate: dueDate,
      hasTime: hasTime,
    );
  }

  static String _removeMatch(String text, RegExp regex) {
    return text.replaceFirst(regex, '').trim();
  }
}
