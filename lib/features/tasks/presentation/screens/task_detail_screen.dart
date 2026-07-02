import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_unlock_dialog.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final Category? category;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.category,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _authorized = false;
  bool _promptScheduled = false;

  @override
  void dispose() {
    PrivateModeService? privateModeService;
    try {
      privateModeService = Provider.of<PrivateModeService>(context, listen: false);
    } catch (_) {
      privateModeService = null;
    }
    privateModeService?.lock();
    super.dispose();
  }

  Future<void> _promptUnlock(
    TaskProvider provider, {
    required bool popOnCancel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => const TaskUnlockDialog(),
    );

    if (!mounted) return;

    if (ok == true) {
      setState(() {
        _authorized = true;
      });
      await provider.updateHomeWidgetWithNotification();
    } else if (popOnCancel) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        final updatedTask = provider.getTaskById(widget.task.id) ?? widget.task;
        final categoryIds = updatedTask.categoryIds.isNotEmpty 
            ? updatedTask.categoryIds 
            : (updatedTask.categoryId != null ? [updatedTask.categoryId!] : []);
        final updatedCategories = categoryIds
            .map((id) => provider.getCategoryById(id))
            .where((c) => c != null)
            .cast<Category>()
            .toList();
        if (updatedCategories.isEmpty && widget.category != null) {
          updatedCategories.add(widget.category!);
        }

        PrivateModeService? privateModeService;
        try {
          privateModeService = Provider.of<PrivateModeService>(context);
        } catch (_) {
          privateModeService = null;
        }

        SubscriptionService? subscriptionService;
        try {
          subscriptionService = Provider.of<SubscriptionService>(context);
        } catch (_) {
          subscriptionService = null;
        }

        final requiresUnlock =
            (subscriptionService?.isPremium ?? false) &&
            (updatedCategories.any((c) => c.isPrivate)) &&
            (privateModeService?.isEnabled ?? false) &&
            (privateModeService?.hasPin ?? false) &&
            (privateModeService?.isUnlocked != true);

        if (requiresUnlock && !_authorized) {
          if (!_promptScheduled) {
            _promptScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _promptUnlock(provider, popOnCancel: true);
            });
          }

          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.privateTask,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.privateTaskSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => _promptUnlock(provider, popOnCancel: false),
                      child: Text(l10n.unlock),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.editTask,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTaskScreen(task: updatedTask),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.deleteTaskTitle,
                color: theme.colorScheme.error,
                onPressed: () => _confirmDelete(context, provider, l10n),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        final themeService = Provider.of<ThemeService>(context, listen: false);
                        if (themeService.taskCompletionFeedback) {
                          if (!updatedTask.isCompleted) {
                            HapticFeedback.mediumImpact();
                          } else {
                            HapticFeedback.lightImpact();
                          }
                        }
                        provider.toggleTaskCompletion(updatedTask);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4),
                        child: Icon(
                          updatedTask.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 28,
                          color: updatedTask.isCompleted
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        updatedTask.title,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          decoration: updatedTask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: updatedTask.isCompleted
                              ? theme.disabledColor
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                GlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ...updatedCategories.map((c) => Chip(
                          avatar: Icon(
                            IconUtils.getIconData(c.iconCode),
                            color: Color(c.colorValue),
                            size: 18,
                          ),
                          label: Text(c.name),
                          backgroundColor: Color(c.colorValue).withValues(alpha: 0.1),
                          side: BorderSide.none,
                        )),
                        if (updatedTask.dueDate != null)
                          Chip(
                            avatar: Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: _getDueDateColor(updatedTask.dueDate!, theme),
                            ),
                            label: Text(
                              DateFormat('MMM d, y, HH:mm').format(updatedTask.dueDate!),
                              style: TextStyle(
                                color: _getDueDateColor(updatedTask.dueDate!, theme),
                              ),
                            ),
                            backgroundColor: _getDueDateColor(updatedTask.dueDate!, theme)
                                .withValues(alpha: 0.1),
                            side: BorderSide.none,
                          ),
                        Chip(
                          avatar: Icon(
                            Icons.flag_rounded,
                            size: 18,
                            color: _getPriorityColor(updatedTask.priority),
                          ),
                          label: Text(
                            _getPriorityLabel(updatedTask.priority, l10n),
                            style: TextStyle(
                              color: _getPriorityColor(updatedTask.priority),
                            ),
                          ),
                          backgroundColor: _getPriorityColor(updatedTask.priority)
                              .withValues(alpha: 0.1),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (updatedTask.description.isNotEmpty) ...[
                  Text(
                    l10n.description,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        updatedTask.description,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (updatedTask.subTasks != null && updatedTask.subTasks!.isNotEmpty) ...[
                  Text(
                    l10n.subtasks,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: List.generate(updatedTask.subTasks!.length, (index) {
                        final subtask = updatedTask.subTasks![index];
                        return Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                subtask.title,
                                style: TextStyle(
                                  decoration: subtask.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: subtask.isCompleted
                                      ? theme.disabledColor
                                      : null,
                                ),
                              ),
                              value: subtask.isCompleted,
                              onChanged: (value) {
                                HapticFeedback.lightImpact();
                                provider.toggleSubTask(updatedTask, subtask.id);
                              },
                            ),
                            if (index < updatedTask.subTasks!.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.dividerColor.withValues(alpha: 0.08),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (updatedTask.attachmentPaths.isNotEmpty) ...[
                  Text(
                    'Attachments',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: updatedTask.attachmentPaths.map((path) {
                          final filename = path.split('/').last;
                          final icon = _getFileIcon(filename);
                          return InputChip(
                            avatar: Icon(icon, size: 18),
                            label: Text(
                              filename,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            onPressed: () => _openAttachment(path),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audiotrack_rounded;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.videocam_rounded;
      default:
        return Icons.attach_file_rounded;
    }
  }

  Future<void> _openAttachment(String path) async {
    try {
      final uri = Uri.file(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${path.split('/').last}')),
        );
      }
    }
  }

  Color _getDueDateColor(DateTime date, ThemeData theme) {
    if (date.isBefore(DateTime.now())) {
      return theme.colorScheme.error;
    }
    return theme.colorScheme.primary;
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.blue;
    }
  }

  String _getPriorityLabel(TaskPriority priority, AppLocalizations l10n) {
    switch (priority) {
      case TaskPriority.high:
        return l10n.high;
      case TaskPriority.medium:
        return l10n.medium;
      case TaskPriority.low:
        return l10n.low;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskProvider provider,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTaskTitle),
        content: Text(l10n.deleteTaskConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      provider.deleteTask(widget.task.id);
      Navigator.pop(context);
    }
  }
}
