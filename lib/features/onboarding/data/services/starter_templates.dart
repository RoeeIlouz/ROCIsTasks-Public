import 'package:flutter/material.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

enum StarterTemplate { none, student, grocery }

/// Seeds a new user's list from the onboarding template picker, so the app
/// opens with something real in it instead of an empty screen.
class StarterTemplates {
  static Future<void> apply(
    StarterTemplate template,
    TaskProvider provider,
    AppLocalizations l10n, {
    DateTime? now,
  }) async {
    try {
      switch (template) {
        case StarterTemplate.none:
          return;
        case StarterTemplate.student:
          await _student(provider, l10n, now ?? DateTime.now());
        case StarterTemplate.grocery:
          await provider.addTask(
            l10n.templateGrocery,
            '',
            null,
            TaskPriority.medium,
            null,
            isGroceryList: true,
            subTasks: [
              SubTask(title: l10n.templateGroceryItem1),
              SubTask(title: l10n.templateGroceryItem2),
              SubTask(title: l10n.templateGroceryItem3),
              SubTask(title: l10n.templateGroceryItem4),
            ],
          );
      }
    } catch (e, s) {
      AppLogger.error(
        'Starter template failed',
        error: e,
        stack: s,
        tag: 'Onboarding',
      );
    }
  }

  static Future<void> _student(
    TaskProvider provider,
    AppLocalizations l10n,
    DateTime now,
  ) async {
    final classes = await _category(
      provider,
      l10n.templateCatClasses,
      const Color(0xFF3B82F6),
      Icons.school_rounded,
    );
    final homework = await _category(
      provider,
      l10n.templateCatHomework,
      const Color(0xFFF59E0B),
      Icons.edit_note_rounded,
    );
    final exams = await _category(
      provider,
      l10n.templateCatExams,
      const Color(0xFFEF4444),
      Icons.quiz_rounded,
    );
    final today = DateTime(now.year, now.month, now.day);

    // Two of the three tasks have two categories, so the new user sees the
    // blended category colors right away.
    await provider.addTask(
      l10n.templateStudentTask1,
      '',
      today.add(const Duration(hours: 18)),
      TaskPriority.medium,
      classes, // legacy primary category, read by the widgets
      categoryIds: [?classes, ?homework],
    );
    await provider.addTask(
      l10n.templateStudentTask2,
      '',
      today.add(const Duration(days: 1, hours: 12)),
      TaskPriority.high,
      homework, // legacy primary category, read by the widgets
      categoryIds: [?homework],
    );
    await provider.addTask(
      l10n.templateStudentTask3,
      '',
      today.add(const Duration(days: 5, hours: 10)),
      TaskPriority.high,
      exams, // legacy primary category, read by the widgets
      categoryIds: [?exams, ?classes],
    );
  }

  /// Id of the category named [name], created if missing; null when the free
  /// category limit is reached.
  static Future<String?> _category(
    TaskProvider provider,
    String name,
    Color color,
    IconData icon,
  ) async {
    String? find() {
      for (final c in provider.categories) {
        if (c.name == name) return c.id;
      }
      return null;
    }

    final existing = find();
    if (existing != null) return existing;
    if (!provider.canAddCategory) return null;
    await provider.addCategory(name, color.toARGB32(), icon.codePoint);
    return find();
  }
}
