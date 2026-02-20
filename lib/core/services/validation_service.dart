import 'package:rocis_tasks/core/config/app_config.dart';

/// Input validation service for the app
class ValidationService {
  /// Validate task title
  static String? validateTaskTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return 'Task title cannot be empty';
    }

    if (title.trim().length > AppConfig.maxTitleLength) {
      return 'Task title cannot exceed ${AppConfig.maxTitleLength} characters';
    }

    return null;
  }

  /// Validate task description
  static String? validateTaskDescription(String? description) {
    if (description != null &&
        description.length > AppConfig.maxDescriptionLength) {
      return 'Description cannot exceed ${AppConfig.maxDescriptionLength} characters';
    }

    return null;
  }

  /// Validate category name
  static String? validateCategoryName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Category name cannot be empty';
    }

    if (name.trim().length > 50) {
      return 'Category name cannot exceed 50 characters';
    }

    return null;
  }

  /// Validate due date
  static String? validateDueDate(DateTime? dueDate) {
    if (dueDate == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDateOnly.isBefore(today)) {
      return 'Due date cannot be in the past';
    }

    return null;
  }

  /// Validate subtask title
  static String? validateSubTaskTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return 'Subtask title cannot be empty';
    }

    if (title.trim().length > 100) {
      return 'Subtask title cannot exceed 100 characters';
    }

    return null;
  }

  /// Sanitize text input
  static String sanitizeText(String input) {
    // Trim, replace multiple spaces with single space,
    // and remove common non-printable control characters that could break UI
    return input
        .trim()
        .replaceAll(
          RegExp(r'[\x00-\x1F\x7F-\x9F]'),
          '',
        ) // Remove control characters
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Check if text contains potentially harmful content
  static bool containsHarmfulContent(String text) {
    // Basic check for script tags or other potentially harmful content
    final harmfulPatterns = [
      RegExp(r'<script.*?>.*?</script>', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false),
    ];

    return harmfulPatterns.any((pattern) => pattern.hasMatch(text));
  }
}
