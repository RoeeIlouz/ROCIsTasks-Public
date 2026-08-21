import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_tile.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_skeleton.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  bool _isCompletedExpanded = false;

  Future<void> _createTemplateTask(
    BuildContext context,
    TaskProvider provider, {
    required String title,
    required String description,
    required TaskPriority priority,
    required List<String> subTaskTitles,
    bool isGroceryList = false,
    DateTime? dueDate,
  }) async {
    HapticFeedback.mediumImpact();
    final subTasks = subTaskTitles.map((t) => SubTask(title: t)).toList();
    await provider.addTask(
      title,
      description,
      dueDate,
      priority,
      null,
      subTasks: subTasks,
      isGroceryList: isGroceryList,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title created!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildStarterTemplates(
    BuildContext context,
    TaskProvider provider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.templateStarterTitle,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTemplateCard(
                context,
                title: l10n.templateGroceryTitle,
                desc: l10n.templateGroceryDesc,
                icon: Icons.shopping_basket_rounded,
                color: Colors.orangeAccent,
                onTap: () => _createTemplateTask(
                  context,
                  provider,
                  title: '🛒 ${l10n.templateGroceryTitle}',
                  description: l10n.templateGroceryDesc,
                  priority: TaskPriority.medium,
                  isGroceryList: true,
                  subTaskTitles: [
                    'Fresh Produce',
                    'Dairy & Milk',
                    'Bakery',
                    'Pantry Staples',
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildTemplateCard(
                context,
                title: l10n.templateWorkTitle,
                desc: l10n.templateWorkDesc,
                icon: Icons.rocket_launch_rounded,
                color: Colors.blueAccent,
                onTap: () => _createTemplateTask(
                  context,
                  provider,
                  title: '💻 ${l10n.templateWorkTitle}',
                  description: l10n.templateWorkDesc,
                  priority: TaskPriority.high,
                  dueDate: DateTime.now().add(const Duration(hours: 4)),
                  subTaskTitles: [
                    'Review Sprint Board',
                    'Prioritize Top 3 Tasks',
                    'Team Sync & Standup',
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildTemplateCard(
                context,
                title: l10n.templateRoutineTitle,
                desc: l10n.templateRoutineDesc,
                icon: Icons.wb_sunny_rounded,
                color: Colors.amber,
                onTap: () => _createTemplateTask(
                  context,
                  provider,
                  title: '🌅 ${l10n.templateRoutineTitle}',
                  description: l10n.templateRoutineDesc,
                  priority: TaskPriority.low,
                  subTaskTitles: [
                    'Drink 500ml Water',
                    '15min Morning Stretch',
                    'Plan Day Priorities',
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildTemplateCard(
                context,
                title: l10n.templateStudyTitle,
                desc: l10n.templateStudyDesc,
                icon: Icons.school_rounded,
                color: Colors.tealAccent.shade700,
                onTap: () => _createTemplateTask(
                  context,
                  provider,
                  title: '📚 ${l10n.templateStudyTitle}',
                  description: l10n.templateStudyDesc,
                  priority: TaskPriority.medium,
                  subTaskTitles: [
                    'Read Chapter Notes',
                    'Practice 5 Problems',
                    'Create Flashcard Summary',
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationBanner(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.allCaughtUpToday,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.allCaughtUpSubtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, dynamic task, TaskProvider provider, {bool animated = false, int index = 0}) {
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

    final tile = Padding(
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

    if (!animated) return tile;

    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 250),
      child: SlideAnimation(
        verticalOffset: 30.0,
        child: FadeInAnimation(
          child: tile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context);
    final isGoogleTasksExpired = authService.isGoogleTasksTokenExpired;
    final theme = Theme.of(context);

    return Selector<TaskProvider, ({List tasks, bool isLoading})>(
      selector: (_, provider) => (tasks: provider.tasks, isLoading: provider.isLoading),
      builder: (context, data, _) {
        final tasks = data.tasks;
        final isLoading = data.isLoading;
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
          mainContent = Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.checklist_rtl_rounded,
                              size: 56,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.noTasksYet,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keep your mind clear and your day organized.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AddTaskScreen(),
                                  fullscreenDialog: true,
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: Text(
                              l10n.createFirstTask,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStarterTemplates(context, taskProvider, l10n, theme),
                  ],
                ),
              ),
            ),
          );
        } else {
          final activeTasks = tasks.where((t) => !(t.isCompleted as bool)).toList();
          final completedTasks = tasks.where((t) => t.isCompleted as bool).toList();
          final isAllCaughtUp = activeTasks.isEmpty && completedTasks.isNotEmpty;

          mainContent = Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
              children: [
                if (isAllCaughtUp)
                  _buildCelebrationBanner(context, l10n, theme),

                if (kIsWeb)
                  ...activeTasks.map((t) => _buildTaskItem(context, t, taskProvider))
                else
                  AnimationLimiter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        activeTasks.length,
                        (index) => _buildTaskItem(
                          context,
                          activeTasks[index],
                          taskProvider,
                          animated: true,
                          index: index,
                        ),
                      ),
                    ),
                  ),

                if (completedTasks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: _isCompletedExpanded,
                          onExpansionChanged: (expanded) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isCompletedExpanded = expanded;
                            });
                          },
                          leading: Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          title: Text(
                            l10n.completedTasksHeader(completedTasks.length),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          children: completedTasks
                              .map((t) => _buildTaskItem(context, t, taskProvider))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
              ],
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
                final success = await authService.linkGoogleTasks();
                if (success && context.mounted) {
                  final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
                  calendarProvider.resetTokenExpiredState();
                  calendarProvider.loadEvents();
                  final taskProvider = Provider.of<TaskProvider>(context, listen: false);
                  taskProvider.syncGoogleTasksToLocal();
                }
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
