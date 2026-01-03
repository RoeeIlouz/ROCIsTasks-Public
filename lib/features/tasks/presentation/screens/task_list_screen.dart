import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_tile.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final taskProvider = Provider.of<TaskProvider>(context);
    final tasks = taskProvider.tasks;

    if (tasks.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.brightness == Brightness.light
                  ? Colors.grey.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 80,
                color: theme.disabledColor.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.noTasksYet,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final category = taskProvider.getCategoryById(task.categoryId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TaskTile(
            task: task,
            category: category,
            onToggle: () => taskProvider.toggleTaskCompletion(task),
            onDelete: () => taskProvider.deleteTask(task.id),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTaskScreen(task: task),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
