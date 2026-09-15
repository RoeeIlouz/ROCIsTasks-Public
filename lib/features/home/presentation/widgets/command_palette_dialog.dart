import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class CommandPaletteItem {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final String? shortcut;
  final String section;
  final VoidCallback onSelect;

  const CommandPaletteItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.shortcut,
    required this.section,
    required this.onSelect,
  });
}

class CommandPaletteDialog extends StatefulWidget {
  final List<Task> tasks;
  final List<Category> categories;
  final ValueChanged<Task> onSelectTask;
  final VoidCallback onCreateTask;
  final ValueChanged<String> onSwitchTab;
  final VoidCallback onSyncTasks;
  final VoidCallback onToggleTheme;
  final ValueChanged<String>? onSelectCategory;

  const CommandPaletteDialog({
    super.key,
    required this.tasks,
    required this.categories,
    required this.onSelectTask,
    required this.onCreateTask,
    required this.onSwitchTab,
    required this.onSyncTasks,
    required this.onToggleTheme,
    this.onSelectCategory,
  });

  static Future<void> show({
    required BuildContext context,
    required List<Task> tasks,
    required List<Category> categories,
    required ValueChanged<Task> onSelectTask,
    required VoidCallback onCreateTask,
    required ValueChanged<String> onSwitchTab,
    required VoidCallback onSyncTasks,
    required VoidCallback onToggleTheme,
    ValueChanged<String>? onSelectCategory,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => CommandPaletteDialog(
        tasks: tasks,
        categories: categories,
        onSelectTask: onSelectTask,
        onCreateTask: onCreateTask,
        onSwitchTab: onSwitchTab,
        onSyncTasks: onSyncTasks,
        onToggleTheme: onToggleTheme,
        onSelectCategory: onSelectCategory,
      ),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  List<CommandPaletteItem> _buildItems(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final items = <CommandPaletteItem>[];

    // 1. Actions
    final actions = <CommandPaletteItem>[
      CommandPaletteItem(
        id: 'action_new_task',
        title: l10n.newTask,
        subtitle: 'Create a new task with full properties',
        icon: Icons.add_circle_outline_rounded,
        iconColor: theme.colorScheme.primary,
        shortcut: 'C',
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          widget.onCreateTask();
        },
      ),
      CommandPaletteItem(
        id: 'action_tab_tasks',
        title: '${l10n.tasks} (List View)',
        subtitle: 'Switch to main tasks workspace',
        icon: Icons.task_alt_rounded,
        iconColor: theme.colorScheme.primary,
        shortcut: '1',
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          widget.onSwitchTab('tasks');
        },
      ),
      CommandPaletteItem(
        id: 'action_tab_board',
        title: l10n.boardView,
        subtitle: 'Switch to Kanban board view',
        icon: Icons.view_kanban_outlined,
        iconColor: Colors.blueAccent,
        shortcut: '2',
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          widget.onSwitchTab('board');
        },
      ),
      CommandPaletteItem(
        id: 'action_tab_calendar',
        title: l10n.calendar,
        subtitle: 'Switch to calendar and agenda view',
        icon: Icons.calendar_month_rounded,
        iconColor: Colors.orangeAccent,
        shortcut: '3',
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          widget.onSwitchTab('calendar');
        },
      ),
      CommandPaletteItem(
        id: 'action_tab_categories',
        title: l10n.categories,
        subtitle: 'Manage task tags and categories',
        icon: Icons.dashboard_customize_outlined,
        iconColor: Colors.purpleAccent,
        shortcut: '4',
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          widget.onSwitchTab('categories');
        },
      ),
      CommandPaletteItem(
        id: 'action_tab_settings',
        title: l10n.settings,
        subtitle: 'Open preferences and configuration',
        icon: Icons.settings_rounded,
        iconColor: Colors.blueGrey,
        shortcut: '5',
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          widget.onSwitchTab('settings');
        },
      ),
      CommandPaletteItem(
        id: 'action_sync',
        title: 'Sync with Google Tasks',
        subtitle: 'Trigger bidirectional cloud synchronization',
        icon: Icons.sync_rounded,
        iconColor: theme.colorScheme.primary,
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          widget.onSyncTasks();
        },
      ),
      CommandPaletteItem(
        id: 'action_toggle_theme',
        title: 'Toggle Theme (Dark / Light)',
        subtitle: 'Switch application color mode',
        icon: Icons.brightness_6_rounded,
        iconColor: Colors.amber,
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          widget.onToggleTheme();
        },
      ),
    ];

    if (query.isEmpty) {
      items.addAll(actions);
    } else {
      items.addAll(
        actions.where(
          (a) =>
              a.title.toLowerCase().contains(query) ||
              (a.subtitle?.toLowerCase().contains(query) ?? false),
        ),
      );
    }

    // 2. Active Tasks matching query
    final matchingTasks = widget.tasks
        .where((t) {
          if (query.isEmpty) return false;
          return t.title.toLowerCase().contains(query) ||
              t.description.toLowerCase().contains(query);
        })
        .take(8);

    for (final task in matchingTasks) {
      String? dueSubtitle;
      if (task.dueDate != null) {
        dueSubtitle = 'Due: ${DateFormat.yMMMd().format(task.dueDate!)}';
      }
      items.add(
        CommandPaletteItem(
          id: 'task_${task.id}',
          title: task.title,
          subtitle:
              dueSubtitle ??
              (task.description.isNotEmpty ? task.description : null),
          icon: task.isCompleted
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          iconColor: task.priority == TaskPriority.high
              ? Colors.redAccent
              : (task.priority == TaskPriority.medium
                    ? Colors.orangeAccent
                    : theme.disabledColor),
          shortcut: task.isCompleted ? 'Done' : 'Task',
          section: 'Tasks',
          onSelect: () {
            Navigator.of(context).pop();
            widget.onSelectTask(task);
          },
        ),
      );
    }

    // 3. Categories matching query
    if (widget.onSelectCategory != null) {
      final matchingCats = widget.categories
          .where((c) {
            if (query.isEmpty) return false;
            return c.name.toLowerCase().contains(query);
          })
          .take(5);

      for (final cat in matchingCats) {
        items.add(
          CommandPaletteItem(
            id: 'cat_${cat.id}',
            title: 'Category: ${cat.name}',
            subtitle: 'Filter workspace tasks by this category',
            icon: Icons.label_outline_rounded,
            iconColor: Color(cat.colorValue),
            section: 'Categories',
            onSelect: () {
              Navigator.of(context).pop();
              widget.onSelectCategory!(cat.id);
            },
          ),
        );
      }
    }

    return items;
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final l10n = AppLocalizations.of(context)!;
    final items = _buildItems(context, l10n);
    if (items.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % items.length;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + items.length) % items.length;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < items.length) {
        items[_selectedIndex].onSelect();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 56.0;
    final targetOffset = _selectedIndex * itemHeight;
    final currentOffset = _scrollController.offset;
    final maxVisible = currentOffset + 300.0;

    if (targetOffset < currentOffset) {
      _scrollController.jumpTo(targetOffset);
    } else if (targetOffset + itemHeight > maxVisible) {
      _scrollController.jumpTo(targetOffset + itemHeight - 300.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final items = _buildItems(context, l10n);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Center(
          child: Container(
            width: 620,
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141416) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Search Input
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _inputFocusNode,
                          autofocus: true,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Type a command or search tasks...',
                            hintStyle: TextStyle(
                              color: theme.disabledColor,
                              fontSize: 15,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: _searchController.clear,
                          tooltip: 'Clear',
                          visualDensity: VisualDensity.compact,
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'ESC',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.disabledColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Results list
                Flexible(
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: theme.disabledColor.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No matching commands or tasks found',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.disabledColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = index == _selectedIndex;

                            // Show section header if first item of that section
                            final isFirstOfSection =
                                index == 0 ||
                                items[index - 1].section != item.section;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isFirstOfSection)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      4,
                                    ),
                                    child: Text(
                                      item.section.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: theme.disabledColor,
                                      ),
                                    ),
                                  ),
                                InkWell(
                                  onTap: item.onSelect,
                                  onHover: (hovering) {
                                    if (hovering) {
                                      setState(() {
                                        _selectedIndex = index;
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.12)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isSelected
                                          ? Border.all(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            )
                                          : Border.all(
                                              color: Colors.transparent,
                                            ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color:
                                                (item.iconColor ??
                                                        theme
                                                            .colorScheme
                                                            .primary)
                                                    .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            item.icon,
                                            size: 16,
                                            color:
                                                item.iconColor ??
                                                theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                item.title,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (item.subtitle != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.subtitle!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme.disabledColor,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (item.shortcut != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.08,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.05,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              item.shortcut!,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: theme.disabledColor,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),

                const Divider(height: 1),

                // Footer Hints Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildKeyHint('↑↓', 'Navigate', theme),
                      const SizedBox(width: 14),
                      _buildKeyHint('↵', 'Select', theme),
                      const SizedBox(width: 14),
                      _buildKeyHint('ESC', 'Close', theme),
                      const Spacer(),
                      Text(
                        'ROCIs Command Palette',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.disabledColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyHint(String key, String label, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            key,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: theme.disabledColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: theme.disabledColor)),
      ],
    );
  }
}
