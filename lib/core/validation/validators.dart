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
}
