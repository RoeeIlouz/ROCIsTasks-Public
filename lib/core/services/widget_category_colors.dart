import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';

/// Hex colors ("#AARRGGBB") of every category on [task], in order, for the
/// home screen widgets to draw a gradient. Empty when the task has no known
/// category.
List<String> widgetCategoryColors(
  Task task,
  Category? Function(String?) getCategoryById,
) {
  final ids = task.categoryIds.isNotEmpty
      ? task.categoryIds
      : [if (task.categoryId != null) task.categoryId!];
  return [
    for (final id in ids)
      if (getCategoryById(id) case final cat?)
        '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}',
  ];
}
