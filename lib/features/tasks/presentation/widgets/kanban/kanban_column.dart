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
  final Future<void> Function(String title)? onInlineAddTask;

  const KanbanColumn({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.tasks,
    required this.onTaskDropped,
    this.onAddTask,
    this.onInlineAddTask,
  });

  @override
  State<KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<KanbanColumn> {
  bool _isHovering = false;
  bool _isAddingInline = false;
  final TextEditingController _inlineController = TextEditingController();
  final FocusNode _inlineFocus = FocusNode();

  @override
  void dispose() {
    _inlineController.dispose();
    _inlineFocus.dispose();
    super.dispose();
  }

  Future<void> _submitInlineTask() async {
    final title = _inlineController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _isAddingInline = false;
      });
      return;
    }
    _inlineController.clear();
    setState(() {
      _isAddingInline = false;
    });
    HapticFeedback.lightImpact();
    if (widget.onInlineAddTask != null) {
      await widget.onInlineAddTask!(title);
    }
  }

  void _startInlineAdd() {
    HapticFeedback.lightImpact();
    setState(() {
      _isAddingInline = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inlineFocus.requestFocus();
      }
    });
  }

  Widget _buildInlineCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _inlineController,
            focusNode: _inlineFocus,
            autofocus: true,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: l10n.newTask,
              hintStyle: GoogleFonts.outfit(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
            ),
            onSubmitted: (_) => _submitInlineTask(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onAddTask != null)
                IconButton(
                  tooltip: l10n.moreOptions,
                  icon: Icon(
                    Icons.open_in_full_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: () {
                    setState(() {
                      _isAddingInline = false;
                      _inlineController.clear();
                    });
                    widget.onAddTask?.call();
                  },
                ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isAddingInline = false;
                    _inlineController.clear();
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.cancel,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: _submitInlineTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.add,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropPlaceholder(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_downward_rounded,
              size: 16,
              color: widget.accentColor,
            ),
            const SizedBox(width: 6),
            Icon(Icons.touch_app_outlined, size: 16, color: widget.accentColor),
          ],
        ),
      ),
    );
  }

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
                    if (widget.onInlineAddTask != null ||
                        widget.onAddTask != null) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          if (widget.onInlineAddTask != null) {
                            _startInlineAdd();
                          } else {
                            widget.onAddTask?.call();
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: widget.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.6),

              // Column Task Cards
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  children: [
                    if (widget.tasks.isEmpty &&
                        !_isAddingInline &&
                        !_isHovering)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 36,
                            horizontal: 16,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 32,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.emptyColumn,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final task in widget.tasks) ...[
                      Builder(
                        builder: (context) {
                          final categoryIds = task.categoryIds.isNotEmpty
                              ? task.categoryIds
                              : (task.categoryId != null
                                    ? [task.categoryId!]
                                    : <String>[]);
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
                    ],
                    if (_isAddingInline) _buildInlineCard(context, theme, l10n),
                    if (_isHovering) _buildDropPlaceholder(theme),
                  ],
                ),
              ),

              // Bottom Add Task Button
              if (widget.onInlineAddTask != null || widget.onAddTask != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: InkWell(
                    onTap: () {
                      if (widget.onInlineAddTask != null) {
                        _startInlineAdd();
                      } else {
                        widget.onAddTask?.call();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.15,
                          ),
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
