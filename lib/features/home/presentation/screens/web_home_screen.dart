import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_tile.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_skeleton.dart';
import 'package:rocis_tasks/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:rocis_tasks/features/home/presentation/screens/settings_screen.dart';
import 'package:rocis_tasks/features/categories/presentation/screens/categories_screen.dart';
import 'package:flutter/services.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/tasks/domain/services/custom_field_action_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_custom_fields_section.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/login_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/kanban/kanban_board_view.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/shared/ui/widgets/sync_status_badge.dart';
import 'package:rocis_tasks/features/home/presentation/widgets/command_palette_dialog.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';

class WebHomeScreen extends StatefulWidget {
  const WebHomeScreen({super.key});

  @override
  State<WebHomeScreen> createState() => _WebHomeScreenState();
}

class _WebHomeScreenState extends State<WebHomeScreen> {
  String _activeTab = 'tasks'; // 'tasks', 'calendar', 'settings', 'categories'
  Task? _selectedTask;
  bool _isCreatingTask = false;

  // Inspector Form State
  final _inspectorFormKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  List<String> _categoryIds = [];
  List<SubTask> _subTasks = [];
  List<TaskCustomField> _customFields = [];
  bool _syncWithGoogleTasks = false;
  bool _skipReminders = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _rootFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();
  final TextEditingController _quickAddController = TextEditingController();
  final FocusNode _quickAddFocusNode = FocusNode();
  final TextEditingController _newSubtaskController = TextEditingController();
  String _selectedPriorityFilter = 'All';
  String? _selectedCategoryFilter;
  bool _compactDensity = false;
  Timer? _autoSaveDebounce;
  String _saveStatus = 'saved'; // 'saved', 'saving', 'idle'

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadUrlDraft();
    });
  }

  void _checkAndLoadUrlDraft() {
    try {
      final uri = Uri.base;
      final params = uri.queryParameters;
      final draftTitle = params['draftTitle'];
      if (draftTitle != null && draftTitle.trim().isNotEmpty) {
        final draftDue = params['draftDue'];
        final draftSubtasks = params['draftSubtasks'];

        DateTime? parsedDueDate;
        if (draftDue != null && draftDue.isNotEmpty) {
          parsedDueDate = DateTime.tryParse(draftDue);
        }

        List<SubTask> subtasks = [];
        if (draftSubtasks != null && draftSubtasks.isNotEmpty) {
          final titles = draftSubtasks
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);
          subtasks = titles
              .map(
                (title) => SubTask(
                  id: '${DateTime.now().millisecondsSinceEpoch}_${title.hashCode}',
                  title: title,
                  isCompleted: false,
                ),
              )
              .toList();
        }

        setState(() {
          _selectedTask = null;
          _isCreatingTask = true;
          _titleController.text = draftTitle.trim();
          _descController.text = 'Imported from ROCIs Planner demo';
          _dueDate = parsedDueDate;
          _priority = TaskPriority.high;
          _subTasks = subtasks;
        });
      }
    } catch (e) {
      debugPrint('Error parsing URL draft task: $e');
    }
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _searchController.dispose();
    _rootFocusNode.dispose();
    _searchFocusNode.dispose();
    _titleFocusNode.dispose();
    _quickAddController.dispose();
    _quickAddFocusNode.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  void _selectTask(Task? task) {
    setState(() {
      _selectedTask = task;
      _isCreatingTask = false;
      _saveStatus = 'saved';
      if (task != null) {
        _titleController.text = task.title;
        _descController.text = task.description;
        _dueDate = task.dueDate;
        _priority = task.priority;
        _categoryIds = List<String>.from(task.categoryIds);
        if (_categoryIds.isEmpty && task.categoryId != null) {
          _categoryIds.add(task.categoryId!);
        }
        _subTasks = task.subTasks?.map((st) => st.copyWith()).toList() ?? [];
        _customFields =
            task.customFields?.map((cf) => cf.copyWith()).toList() ?? [];
        _syncWithGoogleTasks = task.syncWithGoogleTasks;
        _skipReminders = task.skipReminders;
      }
    });
  }

  void _initCreateTask() {
    setState(() {
      _selectedTask = null;
      _isCreatingTask = true;
      _saveStatus = 'idle';
      _titleController.clear();
      _descController.clear();
      _dueDate = null;
      _priority = TaskPriority.medium;
      _categoryIds = [];
      _subTasks = [];
      _customFields = [];
      _syncWithGoogleTasks = false;
      _skipReminders = false;
    });
  }

  void _triggerAutoSave() {
    if (_selectedTask == null) return;
    setState(() {
      _saveStatus = 'saving';
    });
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || _selectedTask == null) return;
      final title = _titleController.text.trim();
      if (title.isEmpty) return;
      final desc = _descController.text.trim();
      final catId = _categoryIds.isNotEmpty ? _categoryIds.first : null;
      final validCustomFields = _customFields
          .where(
            (cf) => cf.label.trim().isNotEmpty || cf.value.trim().isNotEmpty,
          )
          .toList();

      final provider = Provider.of<TaskProvider>(context, listen: false);
      provider.updateTask(
        _selectedTask!,
        title: title,
        description: desc,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        priority: _priority,
        categoryId: catId,
        categoryIds: _categoryIds,
        subTasks: _subTasks,
        syncWithGoogleTasks: _syncWithGoogleTasks,
        skipReminders: _skipReminders,
        customFields: validCustomFields,
      );

      if (mounted) {
        setState(() {
          _saveStatus = 'saved';
        });
      }
    });
  }

  void _submitQuickAdd(TaskProvider provider) {
    final title = _quickAddController.text.trim();
    if (title.isEmpty) return;
    provider.addTask(
      title,
      '',
      DateTime.now(),
      TaskPriority.medium,
      _selectedCategoryFilter,
      categoryIds: _selectedCategoryFilter != null
          ? [_selectedCategoryFilter!]
          : [],
    );
    _quickAddController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$title" to Today'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openCommandPalette() {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final themeService = Provider.of<ThemeService>(context, listen: false);

    CommandPaletteDialog.show(
      context: context,
      tasks: taskProvider.tasks.where((t) => !t.isCompleted).toList(),
      categories: taskProvider.categories,
      onSelectTask: _selectTask,
      onCreateTask: _initCreateTask,
      onSwitchTab: (tab) {
        setState(() {
          _activeTab = tab;
          _selectTask(null);
        });
        if (tab == 'tasks') {
          taskProvider.syncGoogleTasksToLocal();
        }
      },
      onSyncTasks: taskProvider.syncGoogleTasksToLocal,
      onToggleTheme: themeService.toggleTheme,
      onSelectCategory: (catId) {
        setState(() {
          _selectedCategoryFilter = catId;
        });
      },
    );
  }

  void _addCustomField(CustomFieldType type) {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _customFields.add(
        TaskCustomField(
          type: type,
          label: CustomFieldActionService.getDefaultLabel(type, l10n),
          value: '',
        ),
      );
    });
    HapticFeedback.lightImpact();
  }

  void _removeCustomFieldAt(int index) {
    setState(() {
      _customFields.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  void _updateCustomFieldAt(int index, String label, String value) {
    if (index >= 0 && index < _customFields.length) {
      _customFields[index].label = label;
      _customFields[index].value = value;
    }
  }

  void _saveInspectorTask(TaskProvider provider) {
    if (_inspectorFormKey.currentState!.validate()) {
      final title = _titleController.text.trim();
      final desc = _descController.text.trim();
      final catId = _categoryIds.isNotEmpty ? _categoryIds.first : null;
      final validCustomFields = _customFields
          .where(
            (cf) => cf.label.trim().isNotEmpty || cf.value.trim().isNotEmpty,
          )
          .toList();

      if (_selectedTask != null) {
        // Edit Mode
        provider.updateTask(
          _selectedTask!,
          title: title,
          description: desc,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null,
          priority: _priority,
          categoryId: catId,
          categoryIds: _categoryIds,
          subTasks: _subTasks,
          syncWithGoogleTasks: _syncWithGoogleTasks,
          skipReminders: _skipReminders,
          customFields: validCustomFields,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated successfully')),
        );
        _selectTask(null);
      } else if (_isCreatingTask) {
        // Create Mode
        provider.addTask(
          title,
          desc,
          _dueDate,
          _priority,
          catId,
          categoryIds: _categoryIds,
          subTasks: _subTasks,
          syncWithGoogleTasks: _syncWithGoogleTasks,
          skipReminders: _skipReminders,
          customFields: validCustomFields,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully')),
        );
        _selectTask(null);
      }
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: this.context,
        initialTime: _dueDate != null
            ? TimeOfDay.fromDateTime(_dueDate!)
            : TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('WebHomeScreen: build called');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final calendarProvider = Provider.of<CalendarProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final user = authService.currentUser;

    final shortcutBindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          _openCommandPalette,
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          _openCommandPalette,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          _initCreateTask,
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          _initCreateTask,
      const SingleActivator(LogicalKeyboardKey.keyC): () {
        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus == null ||
            currentFocus.context?.widget is! EditableText) {
          _initCreateTask();
        }
      },
      const SingleActivator(LogicalKeyboardKey.slash): () {
        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus == null ||
            currentFocus.context?.widget is! EditableText) {
          _openCommandPalette();
        }
      },
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
          if (_searchController.text.isNotEmpty) {
            setState(() {
              _searchController.clear();
              taskProvider.setSearchQuery('');
            });
          }
        } else if (_quickAddFocusNode.hasFocus) {
          _quickAddFocusNode.unfocus();
        } else if (_selectedTask != null || _isCreatingTask) {
          _selectTask(null);
        }
      },
      const SingleActivator(LogicalKeyboardKey.digit1): () {
        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus == null ||
            currentFocus.context?.widget is! EditableText) {
          setState(() {
            _activeTab = 'tasks';
            _selectTask(null);
          });
          taskProvider.syncGoogleTasksToLocal();
        }
      },
      const SingleActivator(LogicalKeyboardKey.digit2): () {
        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus == null ||
            currentFocus.context?.widget is! EditableText) {
          setState(() {
            _activeTab = 'board';
            _selectTask(null);
          });
        }
      },
      const SingleActivator(LogicalKeyboardKey.digit3): () {
        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus == null ||
            currentFocus.context?.widget is! EditableText) {
          setState(() {
            _activeTab = 'calendar';
            _selectTask(null);
          });
        }
      },
      const SingleActivator(LogicalKeyboardKey.digit4): () {
        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus == null ||
            currentFocus.context?.widget is! EditableText) {
          setState(() {
            _activeTab = 'categories';
            _selectTask(null);
          });
        }
      },
      const SingleActivator(LogicalKeyboardKey.digit5): () {
        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus == null ||
            currentFocus.context?.widget is! EditableText) {
          setState(() {
            _activeTab = 'settings';
            _selectTask(null);
          });
        }
      },
    };

    return CallbackShortcuts(
      bindings: shortcutBindings,
      child: Focus(
        focusNode: _rootFocusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 800;
              final isUltraCompact = constraints.maxWidth < 600;
              final showInspector = _selectedTask != null || _isCreatingTask;
              final double inspectorWidth = constraints.maxWidth < 950
                  ? (constraints.maxWidth * 0.45).clamp(280.0, 380.0)
                  : 380.0;

              if (isUltraCompact && showInspector) {
                return Container(
                  color: isDark
                      ? theme.colorScheme.surface.withValues(alpha: 0.5)
                      : Colors.grey[50],
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: () => _selectTask(null),
                              tooltip: 'Back to tasks',
                            ),
                            Text(
                              _isCreatingTask ? l10n.newTask : l10n.editTask,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _buildInspector(context, taskProvider, l10n),
                      ),
                    ],
                  ),
                );
              }

              return Row(
                children: [
                  // 1. Sidebar Panel (Left)
                  _buildSidebar(
                    context,
                    user,
                    calendarProvider,
                    authService,
                    taskProvider,
                    l10n,
                    isCompact: isCompact,
                  ),

                  // Divider
                  VerticalDivider(
                    width: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),

                  // 2. Middle Content Workspace
                  Expanded(
                    child: _buildMainWorkspace(
                      context,
                      taskProvider,
                      calendarProvider,
                      l10n,
                    ),
                  ),

                  if (showInspector) ...[
                    // Divider
                    VerticalDivider(
                      width: 1,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),

                    // 3. Right Task Inspector
                    Container(
                      width: inspectorWidth,
                      color: isDark
                          ? theme.colorScheme.surface.withValues(alpha: 0.5)
                          : Colors.grey[50],
                      child: _buildInspector(context, taskProvider, l10n),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Sidebar Panel Builder ---
  Widget _buildSidebar(
    BuildContext context,
    dynamic user,
    CalendarProvider calendarProvider,
    AuthService authService,
    TaskProvider taskProvider,
    AppLocalizations l10n, {
    bool isCompact = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: isCompact ? 72 : 260,
      color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey[100],
      padding: EdgeInsets.symmetric(
        vertical: 24,
        horizontal: isCompact ? 8 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Logo / Branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: isCompact
                ? Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 28,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ROCIs Tasks',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 32),

          // Navigation Tabs List
          Builder(
            builder: (context) {
              final activeTasksCount = taskProvider.tasks
                  .where((t) => !t.isCompleted)
                  .length;
              return Column(
                children: [
                  _buildSidebarTab(
                    icon: Icons.task_alt_rounded,
                    label: l10n.tasks,
                    shortcut: '1',
                    badgeCount: activeTasksCount,
                    isActive: _activeTab == 'tasks',
                    isCompact: isCompact,
                    onTap: () {
                      setState(() {
                        _activeTab = 'tasks';
                        _selectTask(null);
                      });
                      Provider.of<TaskProvider>(
                        context,
                        listen: false,
                      ).syncGoogleTasksToLocal();
                    },
                  ),
                  _buildSidebarTab(
                    icon: Icons.view_kanban_outlined,
                    label: l10n.boardView,
                    shortcut: '2',
                    isActive: _activeTab == 'board',
                    isCompact: isCompact,
                    onTap: () => setState(() {
                      _activeTab = 'board';
                      _selectTask(null);
                    }),
                  ),
                  _buildSidebarTab(
                    icon: Icons.calendar_month_rounded,
                    label: l10n.calendar,
                    shortcut: '3',
                    isActive: _activeTab == 'calendar',
                    isCompact: isCompact,
                    onTap: () => setState(() {
                      _activeTab = 'calendar';
                      _selectTask(null);
                    }),
                  ),
                  _buildSidebarTab(
                    icon: Icons.dashboard_customize_outlined,
                    label: l10n.categories,
                    shortcut: '4',
                    isActive: _activeTab == 'categories',
                    isCompact: isCompact,
                    onTap: () => setState(() {
                      _activeTab = 'categories';
                      _selectTask(null);
                    }),
                  ),
                  _buildSidebarTab(
                    icon: Icons.settings_rounded,
                    label: l10n.settings,
                    shortcut: '5',
                    isActive: _activeTab == 'settings',
                    isCompact: isCompact,
                    onTap: () => setState(() {
                      _activeTab = 'settings';
                      _selectTask(null);
                    }),
                  ),
                ],
              );
            },
          ),

          const Spacer(),

          // Google Calendar Connection Status banner
          if (calendarProvider.isGoogleCalendarTokenExpired)
            isCompact
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Tooltip(
                      message: 'Calendar Disconnected - Tap to Reconnect',
                      child: IconButton(
                        icon: Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                          size: 22,
                        ),
                        onPressed: () async {
                          calendarProvider.resetTokenExpiredState();
                          final success = await authService.linkGoogleTasks();
                          if (success) {
                            calendarProvider.loadEvents();
                            taskProvider.syncGoogleTasksToLocal();
                          }
                        },
                      ),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Calendar Disconnected',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            calendarProvider.resetTokenExpiredState();
                            final success = await authService.linkGoogleTasks();
                            if (success) {
                              calendarProvider.loadEvents();
                              taskProvider.syncGoogleTasksToLocal();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            elevation: 0,
                          ),
                          child: const Text(
                            'Reconnect',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

          // Google Tasks Connection Status banner
          if (authService.isGoogleTasksTokenExpired)
            isCompact
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Tooltip(
                      message:
                          '${l10n.googleTasksDisconnected} - ${l10n.reconnect}',
                      child: IconButton(
                        icon: Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                          size: 22,
                        ),
                        onPressed: () async {
                          final success = await authService.linkGoogleTasks();
                          if (success) {
                            calendarProvider.resetTokenExpiredState();
                            calendarProvider.loadEvents();
                            taskProvider.syncGoogleTasksToLocal();
                          }
                        },
                      ),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.googleTasksDisconnected,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final success = await authService.linkGoogleTasks();
                            if (success) {
                              calendarProvider.resetTokenExpiredState();
                              calendarProvider.loadEvents();
                              taskProvider.syncGoogleTasksToLocal();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            elevation: 0,
                          ),
                          child: Text(
                            l10n.reconnect,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

          // Google Play Shortcut
          if (!isCompact)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final url = Uri.parse(
                      'https://play.google.com/store/apps/details?id=com.rocisapps.tasks&pcampaignid=web_share',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.play_arrow_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Get Android App',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                'On Google Play',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.disabledColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: theme.disabledColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Sync Status Indicator
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SyncStatusBadge(compact: isCompact),
          ),

          // User Profile Card
          if (user != null)
            isCompact
                ? Tooltip(
                    message: user.email ?? 'User Profile',
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        (user.displayName != null &&
                                user.displayName!.isNotEmpty)
                            ? user.displayName![0].toUpperCase()
                            : (user.email != null && user.email!.isNotEmpty
                                  ? user.email![0].toUpperCase()
                                  : 'U'),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            (user.displayName != null &&
                                    user.displayName!.isNotEmpty)
                                ? user.displayName![0].toUpperCase()
                                : (user.email != null && user.email!.isNotEmpty
                                      ? user.email![0].toUpperCase()
                                      : 'U'),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (user.displayName != null &&
                                        user.displayName!.isNotEmpty)
                                    ? user.displayName!
                                    : 'User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.email ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.disabledColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => authService.signOut(),
                          tooltip: l10n.signOut,
                        ),
                      ],
                    ),
                  )
          else
            isCompact
                ? Tooltip(
                    message: l10n.signIn,
                    child: IconButton(
                      icon: const Icon(
                        Icons.login_rounded,
                        color: Colors.orangeAccent,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.orangeAccent.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.guestAccount,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                l10n.guestMode,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.disabledColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(l10n.signIn),
                        ),
                      ],
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildSidebarTab({
    required IconData icon,
    required String label,
    String? shortcut,
    int? badgeCount,
    required bool isActive,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Tooltip(
          message: badgeCount != null && badgeCount > 0
              ? '$label ($badgeCount)'
              : label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                    size: 22,
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: -3,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badgeCount != null && badgeCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.disabledColor,
                    ),
                  ),
                ),
              if (shortcut != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    shortcut,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.disabledColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Middle Panel Builder ---
  Widget _buildMainWorkspace(
    BuildContext context,
    TaskProvider taskProvider,
    CalendarProvider calendarProvider,
    AppLocalizations l10n,
  ) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    switch (_activeTab) {
      case 'board':
        return const KanbanBoardView();
      case 'calendar':
        return const CalendarScreen();
      case 'settings':
        return const SettingsScreen();
      case 'categories':
        return const CategoriesScreen();
      case 'tasks':
      default:
        return _buildTasksDashboard(context, taskProvider, user, l10n);
    }
  }

  Widget _buildTasksDashboard(
    BuildContext context,
    TaskProvider provider,
    dynamic user,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeTasks = provider.tasks.where((t) => !t.isCompleted).toList();

    // Sort logic to match filters
    final query = _searchController.text.toLowerCase();

    // Apply search filter
    var filteredTasks = activeTasks.where((t) {
      final matchesQuery =
          query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query);
      final matchesPriority =
          _selectedPriorityFilter == 'All' ||
          (t.priority == TaskPriority.high &&
              _selectedPriorityFilter == 'High') ||
          (t.priority == TaskPriority.medium &&
              _selectedPriorityFilter == 'Medium') ||
          (t.priority == TaskPriority.low && _selectedPriorityFilter == 'Low');
      final matchesCategory =
          _selectedCategoryFilter == null ||
          t.categoryIds.contains(_selectedCategoryFilter) ||
          t.categoryId == _selectedCategoryFilter;

      return matchesQuery && matchesPriority && matchesCategory;
    }).toList();

    // Grouping
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final todayAndOverdue = filteredTasks.where((t) {
      if (t.dueDate == null) return false;
      final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return due.isBefore(todayDate) || due.isAtSameMomentAs(todayDate);
    }).toList();

    final inboxAndUpcoming = filteredTasks.where((t) {
      if (t.dueDate == null) return true;
      final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return due.isAfter(todayDate);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & New Task Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user?.displayName ?? 'Productive User'} 👋',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organize your priorities and keep your sync healthy.',
                      style: TextStyle(
                        color: theme.disabledColor,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const SyncStatusBadge(compact: false),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _initCreateTask,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'New Task',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Stats Row
          Row(
            children: [
              _buildStatCard(
                context,
                'Total Active',
                '${activeTasks.length}',
                Icons.assignment_turned_in_rounded,
              ),
              _buildStatCard(
                context,
                'Today & Overdue',
                '${todayAndOverdue.length}',
                Icons.today_rounded,
                color: Colors.orangeAccent,
              ),
              _buildStatCard(
                context,
                'Upcoming',
                '${inboxAndUpcoming.length}',
                Icons.upcoming_rounded,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Inline Search, Density & Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    hintText: 'Search tasks or jump to... (⌘K)',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: theme.disabledColor,
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: InkWell(
                        onTap: _openCommandPalette,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.terminal_rounded,
                                size: 12,
                                color: theme.disabledColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '⌘K',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.disabledColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedPriorityFilter,
                underline: const SizedBox(),
                items: ['All', 'High', 'Medium', 'Low']
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text('$p Priority'),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedPriorityFilter = val;
                    });
                  }
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String?>(
                value: _selectedCategoryFilter,
                hint: const Text('All Categories'),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ...provider.categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryFilter = val;
                  });
                },
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: _compactDensity
                    ? 'Switch to Comfortable View'
                    : 'Switch to Compact View',
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _compactDensity = !_compactDensity;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Icon(
                      _compactDensity
                          ? Icons.density_small_rounded
                          : Icons.density_medium_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Inline Quick Add Bar (Linear / Things 3 style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quickAddController,
                    focusNode: _quickAddFocusNode,
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Quick add task to Today... (Press Enter)',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: theme.disabledColor,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (text) => _submitQuickAdd(provider),
                  ),
                ),
                InkWell(
                  onTap: () => _submitQuickAdd(provider),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '↵ Enter',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.disabledColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Task Columns
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Column 1: Today & Overdue
                Expanded(
                  child: _buildTaskColumn(
                    title: 'Today & Overdue',
                    tasks: todayAndOverdue,
                    provider: provider,
                    l10n: l10n,
                  ),
                ),
                const SizedBox(width: 20),
                // Column 2: Inbox & Upcoming
                Expanded(
                  child: _buildTaskColumn(
                    title: 'Inbox & Upcoming',
                    tasks: inboxAndUpcoming,
                    provider: provider,
                    l10n: l10n,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Card(
        elevation: 0,
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
        margin: const EdgeInsets.only(right: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (color ?? theme.colorScheme.primary).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color ?? theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.disabledColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskColumn({
    required String title,
    required List<Task> tasks,
    required TaskProvider provider,
    required AppLocalizations l10n,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${tasks.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: provider.isLoading
              ? const TaskListSkeleton()
              : tasks.isEmpty
              ? Container(
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.01)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'No tasks in this section',
                      style: TextStyle(
                        color: theme.disabledColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final categoryIds = task.categoryIds.isNotEmpty
                        ? task.categoryIds
                        : (task.categoryId != null ? [task.categoryId!] : []);
                    final categories = categoryIds
                        .map((id) => provider.getCategoryById(id))
                        .where((c) => c != null)
                        .cast<Category>()
                        .toList();
                    final isSelected = _selectedTask?.id == task.id;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: _compactDensity ? 4.0 : 8.0,
                      ),
                      child: InkWell(
                        onTap: () => _selectTask(task),
                        child: Container(
                          decoration: BoxDecoration(
                            border: isSelected
                                ? Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 1.5,
                                  )
                                : Border.all(color: Colors.transparent),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TaskTile(
                            task: task,
                            categories: categories,
                            enableSwipeToDelete: false,
                            onToggle: () => provider.toggleTaskCompletion(task),
                            onDelete: () => provider.deleteTask(task.id),
                            onTap: () => _selectTask(task),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Right Task Inspector Builder ---
  Widget _buildInspector(
    BuildContext context,
    TaskProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_selectedTask == null && !_isCreatingTask) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 56,
                color: theme.disabledColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a Task',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.disabledColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click any task to view and update details, or click "+ New Task" to create one inline.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: theme.disabledColor),
              ),
            ],
          ),
        ),
      );
    }

    final isEditing = _selectedTask != null;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _inspectorFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Inspector Header (Linear style)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      isEditing ? 'Task Details' : 'New Task',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isEditing) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: _saveStatus == 'saving'
                              ? Colors.amber.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_saveStatus == 'saving')
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.amber,
                                ),
                              )
                            else
                              const Icon(
                                Icons.check_rounded,
                                size: 11,
                                color: Colors.green,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              _saveStatus == 'saving' ? 'Saving' : 'Saved',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _saveStatus == 'saving'
                                    ? Colors.amber
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    if (isEditing)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        color: Colors.redAccent,
                        tooltip: 'Delete Task',
                        onPressed: () {
                          provider.deleteTask(_selectedTask!.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task deleted')),
                          );
                          _selectTask(null);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Close (ESC)',
                      onPressed: () => _selectTask(null),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title Input (Borderless, prominent Outfit font)
                    TextFormField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Task title...',
                        hintStyle: TextStyle(
                          color: theme.disabledColor.withValues(alpha: 0.5),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Title is required'
                          : null,
                      onChanged: (_) => _triggerAutoSave(),
                    ),
                    const SizedBox(height: 12),

                    // Description Input (Clean notes area)
                    TextFormField(
                      controller: _descController,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.85,
                        ),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add description or notes...',
                        hintStyle: TextStyle(
                          color: theme.disabledColor.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: 4,
                      onChanged: (_) => _triggerAutoSave(),
                    ),
                    const SizedBox(height: 18),

                    // Property Rows Container (Linear Style)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Status Row (if editing)
                          if (isEditing) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: theme.disabledColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Status',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.disabledColor,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () {
                                    provider.toggleTaskCompletion(
                                      _selectedTask!,
                                    );
                                    setState(() {
                                      _selectedTask = _selectedTask!.copyWith(
                                        isCompleted:
                                            !_selectedTask!.isCompleted,
                                      );
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (_selectedTask?.isCompleted ?? false)
                                          ? const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.15)
                                          : theme.disabledColor.withValues(
                                              alpha: 0.12,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          (_selectedTask?.isCompleted ?? false)
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded,
                                          size: 13,
                                          color:
                                              (_selectedTask?.isCompleted ??
                                                  false)
                                              ? const Color(0xFF10B981)
                                              : theme.disabledColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (_selectedTask?.isCompleted ?? false)
                                              ? 'Completed'
                                              : 'In Progress',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                (_selectedTask?.isCompleted ??
                                                    false)
                                                ? const Color(0xFF10B981)
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                          ],

                          // Due Date Property Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: theme.disabledColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Due Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.disabledColor,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () async {
                                  await _selectDueDate(context);
                                  _triggerAutoSave();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _dueDate != null
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.12,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _dueDate == null
                                            ? 'Set Date'
                                            : DateFormat.yMMMd()
                                                  .add_jm()
                                                  .format(_dueDate!),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _dueDate != null
                                              ? theme.colorScheme.primary
                                              : theme.disabledColor,
                                        ),
                                      ),
                                      if (_dueDate != null) ...[
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _dueDate = null;
                                            });
                                            _triggerAutoSave();
                                          },
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 13,
                                            color: theme.disabledColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),

                          // Priority Property Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.flag_rounded,
                                    size: 16,
                                    color: theme.disabledColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Priority',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.disabledColor,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: TaskPriority.values.map((p) {
                                  final isSelected = _priority == p;
                                  final pColor = p == TaskPriority.high
                                      ? Colors.redAccent
                                      : (p == TaskPriority.medium
                                            ? Colors.orangeAccent
                                            : Colors.green);
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _priority = p;
                                        });
                                        _triggerAutoSave();
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? pColor.withValues(alpha: 0.15)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? pColor.withValues(alpha: 0.4)
                                                : Colors.transparent,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: pColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              p.name[0].toUpperCase() +
                                                  p.name.substring(1),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? pColor
                                                    : theme.disabledColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          const Divider(height: 16),

                          // Google Tasks Sync Switch
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            dense: true,
                            title: Text(
                              l10n.syncWithGoogleTasks,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            value: _syncWithGoogleTasks,
                            onChanged: (value) {
                              setState(() {
                                _syncWithGoogleTasks = value;
                              });
                              _triggerAutoSave();
                            },
                          ),

                          // Skip Reminders Switch
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            dense: true,
                            title: Text(
                              l10n.doNotRemind,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            value: _skipReminders,
                            onChanged: (value) {
                              setState(() {
                                _skipReminders = value;
                              });
                              _triggerAutoSave();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Category Selector Section
                    Text(
                      l10n.category,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.disabledColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: provider.categories.map((cat) {
                        final isSelected = _categoryIds.contains(cat.id);
                        return FilterChip(
                          visualDensity: VisualDensity.compact,
                          labelStyle: const TextStyle(fontSize: 11),
                          selected: isSelected,
                          avatar: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color(cat.colorValue),
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(cat.name),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _categoryIds = [cat.id];
                              } else {
                                _categoryIds.remove(cat.id);
                              }
                            });
                            _triggerAutoSave();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Subtasks Section (Interactive checklist)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtasks (${_subTasks.where((s) => s.isCompleted).length}/${_subTasks.length})',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(_subTasks.length, (index) {
                      final st = _subTasks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: st.isCompleted,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _subTasks[index] = st.copyWith(
                                      isCompleted: val ?? false,
                                    );
                                  });
                                  _triggerAutoSave();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                st.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  decoration: st.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: st.isCompleted
                                      ? theme.disabledColor
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 14),
                              color: theme.disabledColor,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _subTasks.removeAt(index);
                                });
                                _triggerAutoSave();
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                    // Inline Add Subtask Input
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _newSubtaskController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Add a subtask... (Press Enter)',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: theme.disabledColor,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              onSubmitted: (text) {
                                if (text.trim().isNotEmpty) {
                                  setState(() {
                                    _subTasks.add(
                                      SubTask(
                                        id: DateTime.now()
                                            .millisecondsSinceEpoch
                                            .toString(),
                                        title: text.trim(),
                                        isCompleted: false,
                                      ),
                                    );
                                    _newSubtaskController.clear();
                                  });
                                  _triggerAutoSave();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Custom Fields Section
                    TaskCustomFieldsSection(
                      customFields: _customFields,
                      onAddField: _addCustomField,
                      onRemoveField: _removeCustomFieldAt,
                      onUpdateField: _updateCustomFieldAt,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bottom Actions
            if (_isCreatingTask)
              FilledButton(
                onPressed: () => _saveInspectorTask(provider),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.newTask,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              )
            else
              OutlinedButton(
                onPressed: () => _selectTask(null),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.save),
              ),
          ],
        ),
      ),
    );
  }
}
