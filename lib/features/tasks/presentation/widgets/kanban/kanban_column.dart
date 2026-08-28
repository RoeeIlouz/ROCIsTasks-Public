import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/kanban/kanban_card.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class KanbanColumn extends StatefulWidget {
  final String id;
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Task> tasks;
  final Function(Task task) onTaskDropped;
  final VoidCallback? onAddTask;

  const KanbanColumn({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.tasks,
    required this.onTaskDropped,
    this.onAddTask,
  });

  @override
  State<KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<KanbanColumn> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isHovering = false;
        });
        widget.onTaskDropped(details.data);
      },
      onMove: (_) {
        if (!_isHovering) {
          setState(() {
            _isHovering = true;
          });
        }
      },
      onLeave: (_) {
        if (_isHovering) {
          setState(() {
            _isHovering = false;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 290,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovering
                ? widget.accentColor.withValues(alpha: isDark ? 0.12 : 0.08)
                : (isDark
                    ? theme.colorScheme.surface.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovering
                  ? widget.accentColor.withValues(alpha: 0.6)
                  : widget.accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
              width: _isHovering ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Column Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.accentColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    // Count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.tasks.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.6),

              // Column Task Cards
              Expanded(
                child: widget.tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 32,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.emptyColumn,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        itemCount: widget.tasks.length,
                        itemBuilder: (context, index) {
                          final task = widget.tasks[index];
                          final categoryIds = task.categoryIds.isNotEmpty
                              ? task.categoryIds
                              : (task.categoryId != null ? [task.categoryId!] : <String>[]);
                          final categories = categoryIds
                              .map(taskProvider.getCategoryById)
                              .whereType<Category>()
                              .toList();

                          return KanbanCard(
                            key: ValueKey(task.id),
                            task: task,
                            categories: categories,
                          );
                        },
                      ),
              ),

              // Bottom Add Task Button
              if (widget.onAddTask != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onAddTask!();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.newTask,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
