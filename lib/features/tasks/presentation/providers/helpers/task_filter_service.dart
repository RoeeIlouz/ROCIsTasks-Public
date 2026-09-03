import 'package:intl/intl.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';

enum TaskSortOption { dueDate, priority, title, dateCreated, dueDateTime }

enum DateTimeFilterOption { all, today, thisWeek, overdue, noDate }

class TaskFilterService {
  TaskSortOption currentSortOption = TaskSortOption.dueDate;
  DateTimeFilterOption currentDateFilter = DateTimeFilterOption.all;
  List<String> selectedCategoryIds = [];
  bool showCompleted = true;
  String searchQuery = '';

  void setSearchQuery(String query) {
    searchQuery = query.toLowerCase();
  }

  void toggleCategoryFilter(String categoryId) {
    if (selectedCategoryIds.contains(categoryId)) {
      selectedCategoryIds.remove(categoryId);
    } else {
      selectedCategoryIds.add(categoryId);
    }
  }

  void clearCategoryFilters() {
    selectedCategoryIds = [];
  }

  List<Task> filterAndSortTasks({
    required List<Task> allTasks,
    required Category? Function(String? id) getCategoryById,
    required bool Function(Task task) isPrivateTask,
    required bool shouldMaskPrivateContent,
  }) {
    var tasks = allTasks.where((t) => !(t.isDeleted ?? false)).toList();

    if (searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();

      String? categoryFilter;
      String? titleFilter;
      String? priorityFilter;
      String? dateFilter;
      String? subtaskFilter;
      String? statusFilter;
      bool todayFilter = false;
      String freeText = lowerQuery;

      final categoryMatch = RegExp(r'@(\S+)').firstMatch(freeText);
      if (categoryMatch != null) {
        categoryFilter = categoryMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'@\S+'), '').trim();
      }

      final titleMatch = RegExp(r'#(\S+)').firstMatch(freeText);
      if (titleMatch != null) {
        titleFilter = titleMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'#\S+'), '').trim();
      }

      final priorityMatch = RegExp(r'!(\S+)').firstMatch(freeText);
      if (priorityMatch != null) {
        priorityFilter = priorityMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'!\S+'), '').trim();
      }

      final dateMatch = RegExp(r'%(\S+)').firstMatch(freeText);
      if (dateMatch != null) {
        dateFilter = dateMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'%\S+'), '').trim();
      }

      final subtaskMatch = RegExp(r'&(\S+)').firstMatch(freeText);
      if (subtaskMatch != null) {
        subtaskFilter = subtaskMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'&\S+'), '').trim();
      }

      final statusMatch = RegExp(r'\*(\S+)').firstMatch(freeText);
      if (statusMatch != null) {
        statusFilter = statusMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'\*\S+'), '').trim();
      }

      if (freeText.contains('?')) {
        todayFilter = true;
        freeText = freeText.replaceFirst('?', '').trim();
      }

      tasks = tasks.where((t) {
        if (freeText.isNotEmpty) {
          final titleMatch = t.title.toLowerCase().contains(freeText);
          if (!titleMatch) {
            if (shouldMaskPrivateContent && isPrivateTask(t)) return false;
            if (!t.description.toLowerCase().contains(freeText)) return false;
          }
        }

        if (categoryFilter != null) {
          bool matched = false;
          if (t.categoryId != null) {
            final cat = getCategoryById(t.categoryId);
            if (cat != null &&
                cat.name.toLowerCase().contains(categoryFilter)) {
              matched = true;
            }
          }
          if (!matched && t.categoryIds.isNotEmpty) {
            for (final id in t.categoryIds) {
              final cat = getCategoryById(id);
              if (cat != null &&
                  cat.name.toLowerCase().contains(categoryFilter)) {
                matched = true;
                break;
              }
            }
          }
          if (!matched) return false;
        }

        if (titleFilter != null) {
          if (!t.title.toLowerCase().contains(titleFilter)) return false;
        }

        if (priorityFilter != null) {
          final priorityName = t.priority.name.toLowerCase();
          if (!priorityName.contains(priorityFilter)) return false;
        }

        if (dateFilter != null && t.dueDate != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(t.dueDate!);
          if (!dateStr.contains(dateFilter)) return false;
        } else if (dateFilter != null && t.dueDate == null) {
          return false;
        }

        if (subtaskFilter != null && subtaskFilter.isNotEmpty) {
          final filter = subtaskFilter;
          final hasMatchingSubtask =
              t.subTasks?.any(
                (st) => st.title.toLowerCase().contains(filter),
              ) ??
              false;
          if (!hasMatchingSubtask) return false;
        }

        if (statusFilter != null) {
          if (statusFilter == 'done' || statusFilter == 'completed') {
            if (!t.isCompleted) return false;
          } else if (statusFilter == 'pending' || statusFilter == 'active') {
            if (t.isCompleted) return false;
          }
        }

        if (todayFilter) {
          if (t.dueDate == null) return false;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (t.dueDate!.year != today.year ||
              t.dueDate!.month != today.month ||
              t.dueDate!.day != today.day) {
            return false;
          }
        }

        return true;
      }).toList();
    }

    if (selectedCategoryIds.isNotEmpty) {
      tasks = tasks
          .where(
            (t) =>
                selectedCategoryIds.contains(t.categoryId) ||
                t.categoryIds.any((id) => selectedCategoryIds.contains(id)),
          )
          .toList();
    }

    if (!showCompleted) {
      tasks = tasks.where((t) {
        if (shouldMaskPrivateContent && isPrivateTask(t)) return true;
        return !t.isCompleted;
      }).toList();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    switch (currentDateFilter) {
      case DateTimeFilterOption.today:
        tasks = tasks.where((t) {
          if (shouldMaskPrivateContent && isPrivateTask(t)) return true;
          if (t.dueDate == null) return false;
          final d = t.dueDate!;
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }).toList();
        break;
      case DateTimeFilterOption.thisWeek:
        tasks = tasks.where((t) {
          if (shouldMaskPrivateContent && isPrivateTask(t)) return true;
          if (t.dueDate == null) return false;
          return t.dueDate!.isAfter(
                today.subtract(const Duration(seconds: 1)),
              ) &&
              t.dueDate!.isBefore(weekEnd);
        }).toList();
        break;
      case DateTimeFilterOption.overdue:
        tasks = tasks.where((t) {
          if (shouldMaskPrivateContent && isPrivateTask(t)) return true;
          if (t.dueDate == null || t.isCompleted) return false;
          return t.dueDate!.isBefore(now);
        }).toList();
        break;
      case DateTimeFilterOption.noDate:
        tasks = tasks.where((t) {
          if (shouldMaskPrivateContent && isPrivateTask(t)) return true;
          return t.dueDate == null;
        }).toList();
        break;
      case DateTimeFilterOption.all:
        break;
    }

    tasks.sort((a, b) {
      final aPrivate = shouldMaskPrivateContent && isPrivateTask(a);
      final bPrivate = shouldMaskPrivateContent && isPrivateTask(b);
      if (aPrivate != bPrivate) return aPrivate ? 1 : -1;
      if (aPrivate && bPrivate) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      if ((a.isPinned ?? false) != (b.isPinned ?? false)) {
        return (a.isPinned ?? false) ? -1 : 1;
      }
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      switch (currentSortOption) {
        case TaskSortOption.dueDate:
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          final aDate = DateTime(
            a.dueDate!.year,
            a.dueDate!.month,
            a.dueDate!.day,
          );
          final bDate = DateTime(
            b.dueDate!.year,
            b.dueDate!.month,
            b.dueDate!.day,
          );
          final dayCmp = aDate.compareTo(bDate);
          if (dayCmp != 0) return dayCmp;
          final prioCmp = b.priority.index.compareTo(a.priority.index);
          if (prioCmp != 0) return prioCmp;
          return a.dueDate!.compareTo(b.dueDate!);
        case TaskSortOption.dueDateTime:
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          final dateCmp = a.dueDate!.compareTo(b.dueDate!);
          if (dateCmp != 0) return dateCmp;
          final prioCmp = b.priority.index.compareTo(a.priority.index);
          if (prioCmp != 0) return prioCmp;
          return a.createdAt.compareTo(b.createdAt);
        case TaskSortOption.priority:
          return b.priority.index.compareTo(a.priority.index);
        case TaskSortOption.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case TaskSortOption.dateCreated:
          return a.createdAt.compareTo(b.createdAt);
      }
    });

    return tasks;
  }
}
