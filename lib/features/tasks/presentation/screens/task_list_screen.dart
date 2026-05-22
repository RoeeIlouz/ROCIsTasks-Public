import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_tile.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Selector<TaskProvider, List>(
      selector: (_, provider) => provider.tasks,
      builder: (context, tasks, _) {
        // Check for error and show snackbar
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        if (taskProvider.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && taskProvider.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(taskProvider.errorMessage!),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              taskProvider.clearError();
            }
          });
        }

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
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddTaskScreen(),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.createFirstTask),
                  ),
                ],
              ),
            ),
          );
        }

        return AnimationLimiter(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Consumer<TaskProvider>(
                builder: (context, provider, _) {
                  final category = provider.getCategoryById(task.categoryId);
                  final isSelectionMode = provider.isSelectionMode;
                  final isSelected = provider.selectedTaskIds.contains(task.id);

                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TaskTile(
                            task: task,
                            category: category,
                            isSelected: isSelected,
                            isSelectionMode: isSelectionMode,
                            onToggle: () => provider.toggleTaskCompletion(task),
                            onDelete: () => provider.deleteTask(task.id),
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              provider.toggleTaskSelection(task.id);
                            },
                            onTap: () {
                              if (isSelectionMode) {
                                provider.toggleTaskSelection(task.id);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TaskDetailScreen(
                                      task: task,
                                      category: category,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
