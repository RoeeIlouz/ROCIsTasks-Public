import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/kanban/kanban_column.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

enum KanbanGrouping {
  status,
  priority,
  category,
}

class KanbanBoardView extends StatefulWidget {
  const KanbanBoardView({super.key});

  @override
  State<KanbanBoardView> createState() => _KanbanBoardViewState();
}

class _KanbanBoardViewState extends State<KanbanBoardView> {
  KanbanGrouping _grouping = KanbanGrouping.status;

  bool _isTodayOrOverdue(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return date.isBefore(todayEnd);
  }

  void _openAddTask(BuildContext context, {
    TaskPriority? priority,
    String? categoryId,
    DateTime? dueDate,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTaskScreen(
          initialPriority: priority,
          initialCategoryId: categoryId,
          initialDueDate: dueDate,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final taskProvider = Provider.of<TaskProvider>(context);
    final allTasks = taskProvider.tasks;
    final categories = taskProvider.categories;

    return Column(
      children: [
        // Grouping Selector Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Text(
                '${l10n.groupBy}:',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              _buildGroupingChip(
                KanbanGrouping.status,
                Icons.dashboard_outlined,
                l10n.groupByStatus,
                theme,
              ),
              const SizedBox(width: 6),
              _buildGroupingChip(
                KanbanGrouping.priority,
                Icons.flag_outlined,
                l10n.groupByPriority,
                theme,
              ),
              const SizedBox(width: 6),
              _buildGroupingChip(
                KanbanGrouping.category,
                Icons.label_outlined,
                l10n.groupByCategory,
                theme,
              ),
            ],
          ),
        ),

        // Columns Scroll View
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
            children: _buildColumns(context, allTasks, categories, taskProvider, l10n, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupingChip(
    KanbanGrouping grouping,
    IconData icon,
    String label,
    ThemeData theme,
  ) {
    final isSelected = _grouping == grouping;

    return InkWell(
      onTap: () {
        if (_grouping != grouping) {
          HapticFeedback.selectionClick();
          setState(() {
            _grouping = grouping;
          });
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildColumns(
    BuildContext context,
    List<Task> tasks,
    List<Category> categories,
    TaskProvider taskProvider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    switch (_grouping) {
      case KanbanGrouping.status:
        return _buildStatusColumns(context, tasks, taskProvider, l10n, theme);
      case KanbanGrouping.priority:
        return _buildPriorityColumns(context, tasks, taskProvider, l10n, theme);
      case KanbanGrouping.category:
        return _buildCategoryColumns(context, tasks, categories, taskProvider, l10n, theme);
    }
  }

  List<Widget> _buildStatusColumns(
    BuildContext context,
    List<Task> tasks,
    TaskProvider taskProvider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    // 1. To Do (Pending, dueDate is null or future)
    final todoTasks = tasks.where((t) {
      if (t.isCompleted) return false;
      if (t.isPinned ?? false) return false;
      if (_isTodayOrOverdue(t.dueDate)) return false;
      return true;
    }).toList();

    // 2. In Focus (Pending, dueDate is today or overdue or pinned)
    final inFocusTasks = tasks.where((t) {
      if (t.isCompleted) return false;
      return (t.isPinned ?? false) || _isTodayOrOverdue(t.dueDate);
    }).toList();

    // 3. Done
    final doneTasks = tasks.where((t) => t.isCompleted).toList();

    return [
      KanbanColumn(
        id: 'todo',
        title: l10n.columnToDo,
        icon: Icons.assignment_outlined,
        accentColor: theme.colorScheme.primary,
        tasks: todoTasks,
        onAddTask: () => _openAddTask(context),
        onTaskDropped: (task) async {
          if (task.isCompleted) {
            await taskProvider.toggleTaskCompletion(task);
          }
          if (_isTodayOrOverdue(task.dueDate)) {
            await taskProvider.updateTask(task, clearDueDate: true);
          }
        },
      ),
      KanbanColumn(
        id: 'infocus',
        title: l10n.columnInFocus,
        icon: Icons.bolt_rounded,
        accentColor: const Color(0xFFF59E0B),
        tasks: inFocusTasks,
        onAddTask: () => _openAddTask(context, dueDate: DateTime.now()),
        onTaskDropped: (task) async {
          if (task.isCompleted) {
            await taskProvider.toggleTaskCompletion(task);
          }
          final now = DateTime.now();
          final todayNoon = DateTime(now.year, now.month, now.day, 12, 0);
          await taskProvider.updateTask(task, dueDate: todayNoon);
        },
      ),
      KanbanColumn(
        id: 'done',
        title: l10n.columnDone,
        icon: Icons.check_circle_outline_rounded,
        accentColor: const Color(0xFF10B981),
        tasks: doneTasks,
        onTaskDropped: (task) async {
          if (!task.isCompleted) {
            await taskProvider.toggleTaskCompletion(task);
          }
        },
      ),
    ];
  }

  List<Widget> _buildPriorityColumns(
    BuildContext context,
    List<Task> tasks,
    TaskProvider taskProvider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final highTasks = activeTasks.where((t) => t.priority == TaskPriority.high).toList();
    final medTasks = activeTasks.where((t) => t.priority == TaskPriority.medium).toList();
    final lowTasks = activeTasks.where((t) => t.priority == TaskPriority.low).toList();

    return [
      KanbanColumn(
        id: 'high',
        title: l10n.highPriority,
        icon: Icons.priority_high_rounded,
        accentColor: const Color(0xFFEF4444),
        tasks: highTasks,
        onAddTask: () => _openAddTask(context, priority: TaskPriority.high),
        onTaskDropped: (task) async {
          task.priority = TaskPriority.high;
          await taskProvider.updateTask(task);
        },
      ),
      KanbanColumn(
        id: 'medium',
        title: l10n.mediumPriority,
        icon: Icons.drag_handle_rounded,
        accentColor: const Color(0xFFF59E0B),
        tasks: medTasks,
        onAddTask: () => _openAddTask(context, priority: TaskPriority.medium),
        onTaskDropped: (task) async {
          task.priority = TaskPriority.medium;
          await taskProvider.updateTask(task);
        },
      ),
      KanbanColumn(
        id: 'low',
        title: l10n.lowPriority,
        icon: Icons.arrow_downward_rounded,
        accentColor: const Color(0xFF10B981),
        tasks: lowTasks,
        onAddTask: () => _openAddTask(context, priority: TaskPriority.low),
        onTaskDropped: (task) async {
          task.priority = TaskPriority.low;
          await taskProvider.updateTask(task);
        },
      ),
    ];
  }

  List<Widget> _buildCategoryColumns(
    BuildContext context,
    List<Task> tasks,
    List<Category> categories,
    TaskProvider taskProvider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final columns = <Widget>[];

    for (final cat in categories) {
      final catTasks = activeTasks.where((t) {
        if (t.categoryIds.contains(cat.id)) return true;
        if (t.categoryId == cat.id) return true;
        return false;
      }).toList();

      columns.add(
        KanbanColumn(
          key: ValueKey(cat.id),
          id: cat.id,
          title: cat.name,
          icon: Icons.folder_outlined,
          accentColor: Color(cat.colorValue),
          tasks: catTasks,
          onAddTask: () => _openAddTask(context, categoryId: cat.id),
          onTaskDropped: (task) async {
            task.categoryId = cat.id;
            task.categoryIds = [cat.id];
            await taskProvider.updateTask(task);
          },
        ),
      );
    }

    // Uncategorized column
    final uncategorizedTasks = activeTasks.where((t) {
      final hasCategory = (t.categoryId != null && t.categoryId!.isNotEmpty) ||
          t.categoryIds.isNotEmpty;
      return !hasCategory;
    }).toList();

    columns.add(
      KanbanColumn(
        id: 'uncategorized',
        title: l10n.uncategorized,
        icon: Icons.label_off_outlined,
        accentColor: theme.colorScheme.onSurfaceVariant,
        tasks: uncategorizedTasks,
        onAddTask: () => _openAddTask(context),
        onTaskDropped: (task) async {
          task.categoryId = null;
          task.categoryIds = [];
          await taskProvider.updateTask(task);
        },
      ),
    );

    return columns;
  }
}
