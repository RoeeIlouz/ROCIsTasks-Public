import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trashTitle),
        actions: [
          Consumer<TaskProvider>(
            builder: (context, provider, child) {
              if (provider.deletedTasks.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: l10n.emptyTrash,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.emptyTrash),
                      content: Text(l10n.actionUndone),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () {
                            provider.clearTrash();
                            Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                          ),
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          final deletedTasks = provider.deletedTasks;

          if (deletedTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  SizedBox(height: 16),
                  Text(l10n.trashEmpty),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deletedTasks.length,
            itemBuilder: (context, index) {
              final task = deletedTasks[index];
              return GlassContainer(
                margin: const EdgeInsets.only(bottom: 12),
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  title: Text(
                    task.title,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: task.dueDate != null
                      ? Text(
                          DateFormat.yMMMd().format(task.dueDate!),
                          style: TextStyle(
                            color: Theme.of(context).disabledColor,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.restore,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        onPressed: () {
                          provider.restoreTask(task);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.restoredTask(task.title)),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_forever_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () {
                          // Confirm Dialog
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.deletePermanently),
                              content: Text(l10n.actionUndone),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(l10n.cancel),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    provider.deleteTaskPermanently(task.id);
                                    Navigator.pop(ctx);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                  ),
                                  child: Text(l10n.delete),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
