import 'package:flutter/material.dart';
import 'package:rocis_tasks/core/config/app_config.dart';

class Validators {
  static String? validateTaskTitle(String? value, BuildContext? context) {
    if (value == null || value.trim().isEmpty) {
      return 'Task title is required';
    }
    if (value.length > AppConfig.maxTitleLength) {
      return 'Task title must be less than ${AppConfig.maxTitleLength} characters';
    }
    return null;
  }

  static String? validateCategoryName(String? value, BuildContext? context) {
    if (value == null || value.trim().isEmpty) {
      return 'Category name is required';
    }
    if (value.length > 30) {
      return 'Category name must be less than 30 characters';
    }
    return null;
  }

  /// Sanitizes text by removing control characters and HTML-like tags
  static String sanitizeText(String text) {
    // Remove control characters except newline and tab
    String sanitized = text.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );
    // Basic HTML tag stripping for primitive XSS protection
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');
    return sanitized.trim();
  }
}
