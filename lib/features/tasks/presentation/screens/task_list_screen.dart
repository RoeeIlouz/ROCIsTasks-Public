import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_tile.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_skeleton.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context);
    final isGoogleTasksExpired = authService.isGoogleTasksTokenExpired;

    return Selector<TaskProvider, ({List tasks, bool isLoading})>(
      selector: (_, provider) => (tasks: provider.tasks, isLoading: provider.isLoading),
      builder: (context, data, _) {
        final tasks = data.tasks;
        final isLoading = data.isLoading;
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

        Widget mainContent;

        if (isLoading) {
          mainContent = const Expanded(
            child: TaskListSkeleton(),
          );
        } else if (tasks.isEmpty) {
          final theme = Theme.of(context);
          mainContent = Expanded(
            child: Center(
              child: GlassContainer(
                padding: const EdgeInsets.all(24),
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
            ),
          );
        } else if (kIsWeb) {
          mainContent = Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Consumer<TaskProvider>(
                  builder: (context, provider, _) {
                    final categoryIds = task.categoryIds.isNotEmpty 
                        ? task.categoryIds 
                        : (task.categoryId != null ? [task.categoryId!] : []);
                    final categories = categoryIds
                        .map((id) => provider.getCategoryById(id))
                        .where((c) => c != null)
                        .cast<Category>()
                        .toList();
                    final isSelectionMode = provider.isSelectionMode;
                    final isSelected = provider.selectedTaskIds.contains(task.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TaskTile(
                        task: task,
                        categories: categories,
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
                                  category: categories.isNotEmpty ? categories.first : null,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          );
        } else {
          mainContent = Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Consumer<TaskProvider>(
                    builder: (context, provider, _) {
                      final categoryIds = task.categoryIds.isNotEmpty 
                          ? task.categoryIds 
                          : (task.categoryId != null ? [task.categoryId!] : []);
                      final categories = categoryIds
                          .map((id) => provider.getCategoryById(id))
                          .where((c) => c != null)
                          .cast<Category>()
                          .toList();
                      final isSelectionMode = provider.isSelectionMode;
                      final isSelected = provider.selectedTaskIds.contains(task.id);

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 250),
                        child: SlideAnimation(
                          verticalOffset: 30.0,
                          child: FadeInAnimation(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TaskTile(
                                task: task,
                                categories: categories,
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
                                          category: categories.isNotEmpty ? categories.first : null,
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
            ),
          );
        }

        return Column(
          children: [
            if (isGoogleTasksExpired)
              _buildGoogleTasksWarning(context, l10n, authService),
            mainContent,
          ],
        );
      },
    );
  }

  Widget _buildGoogleTasksWarning(
    BuildContext context,
    AppLocalizations l10n,
    AuthService authService,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.googleTasksDisconnected,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.googleTasksDisconnectedSubtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                await authService.linkGoogleTasks();
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                l10n.reconnect,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
