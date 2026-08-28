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
  String _selectedPriorityFilter = 'All';
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectTask(Task? task) {
    setState(() {
      _selectedTask = task;
      _isCreatingTask = false;
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
        _customFields = task.customFields?.map((cf) => cf.copyWith()).toList() ?? [];
        _syncWithGoogleTasks = task.syncWithGoogleTasks;
        _skipReminders = task.skipReminders;
      }
    });
  }

  void _initCreateTask() {
    setState(() {
      _selectedTask = null;
      _isCreatingTask = true;
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
          .where((cf) => cf.label.trim().isNotEmpty || cf.value.trim().isNotEmpty)
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
        initialTime: _dueDate != null ? TimeOfDay.fromDateTime(_dueDate!) : TimeOfDay.now(),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // 1. Sidebar Panel (Left)
          _buildSidebar(context, user, calendarProvider, authService, l10n),
          
          // Divider
          VerticalDivider(width: 1, color: isDark ? Colors.white12 : Colors.black12),
          
          // 2. Middle Content Workspace
          Expanded(
            child: _buildMainWorkspace(context, taskProvider, calendarProvider, l10n),
          ),
          
          if (_selectedTask != null || _isCreatingTask) ...[
            // Divider
            VerticalDivider(width: 1, color: isDark ? Colors.white12 : Colors.black12),
            
            // 3. Right Task Inspector
            Container(
              width: 380,
              color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.5) : Colors.grey[50],
              child: _buildInspector(context, taskProvider, l10n),
            ),
          ],
        ],
      ),
    );
  }

  // --- Sidebar Panel Builder ---
  Widget _buildSidebar(
    BuildContext context, 
    dynamic user, 
    CalendarProvider calendarProvider, 
    AuthService authService,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    return Container(
      width: 260,
      color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey[100],
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Logo / Branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 28, color: theme.colorScheme.primary),
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
          _buildSidebarTab(
            icon: Icons.task_alt_rounded,
            label: l10n.tasks,
            isActive: _activeTab == 'tasks',
            onTap: () {
              setState(() { _activeTab = 'tasks'; _selectTask(null); });
              Provider.of<TaskProvider>(context, listen: false).syncGoogleTasksToLocal();
            },
          ),
          _buildSidebarTab(
            icon: Icons.view_kanban_outlined,
            label: l10n.boardView,
            isActive: _activeTab == 'board',
            onTap: () => setState(() { _activeTab = 'board'; _selectTask(null); }),
          ),
          _buildSidebarTab(
            icon: Icons.calendar_month_rounded,
            label: l10n.calendar,
            isActive: _activeTab == 'calendar',
            onTap: () => setState(() { _activeTab = 'calendar'; _selectTask(null); }),
          ),
          _buildSidebarTab(
            icon: Icons.dashboard_customize_outlined,
            label: l10n.categories,
            isActive: _activeTab == 'categories',
            onTap: () => setState(() { _activeTab = 'categories'; _selectTask(null); }),
          ),
          _buildSidebarTab(
            icon: Icons.settings_rounded,
            label: l10n.settings,
            isActive: _activeTab == 'settings',
            onTap: () => setState(() { _activeTab = 'settings'; _selectTask(null); }),
          ),
          
          const Spacer(),
          
          // Google Calendar Connection Status banner
          if (calendarProvider.isGoogleCalendarTokenExpired)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 18),
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
                    child: const Text('Reconnect', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),

          // Google Tasks Connection Status banner
          if (authService.isGoogleTasksTokenExpired)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 18),
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
                    child: Text(l10n.reconnect, style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),

          // Google Play Shortcut
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final url = Uri.parse('https://play.google.com/store/apps/details?id=com.rocisapps.tasks&pcampaignid=web_share');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
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

          // User Profile Card
          if (user != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      (user.displayName != null && user.displayName!.isNotEmpty)
                          ? user.displayName![0].toUpperCase()
                          : (user.email != null && user.email!.isNotEmpty
                              ? user.email![0].toUpperCase()
                              : 'U'),
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user.displayName != null && user.displayName!.isNotEmpty)
                              ? user.displayName!
                              : 'User',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email ?? '',
                          style: TextStyle(fontSize: 11, color: theme.disabledColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                    onPressed: () => authService.signOut(),
                    tooltip: l10n.signOut,
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.orangeAccent.withValues(alpha: 0.1),
                    child: const Icon(Icons.person_outline_rounded, size: 20, color: Colors.orangeAccent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.guestAccount,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.guestMode,
                          style: TextStyle(fontSize: 11, color: theme.disabledColor),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? theme.colorScheme.primary : theme.disabledColor,
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  fontSize: 14,
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
    final activeTasks = provider.tasks.where((t) => !t.isCompleted).toList();
    
    // Sort logic to match filters
    final query = _searchController.text.toLowerCase();
    
    // Apply search filter
    var filteredTasks = activeTasks.where((t) {
      final matchesQuery = query.isEmpty || t.title.toLowerCase().contains(query) || t.description.toLowerCase().contains(query);
      final matchesPriority = _selectedPriorityFilter == 'All' || 
          (t.priority == TaskPriority.high && _selectedPriorityFilter == 'High') ||
          (t.priority == TaskPriority.medium && _selectedPriorityFilter == 'Medium') ||
          (t.priority == TaskPriority.low && _selectedPriorityFilter == 'Low');
      final matchesCategory = _selectedCategoryFilter == null || t.categoryIds.contains(_selectedCategoryFilter) || t.categoryId == _selectedCategoryFilter;
      
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
                      style: TextStyle(color: theme.disabledColor, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _initCreateTask,
                icon: const Icon(Icons.add, size: 18),
                label: Text('New Task', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          
          // Stats Row
          Row(
            children: [
              _buildStatCard(context, 'Total Active', '${activeTasks.length}', Icons.assignment_turned_in_rounded),
              _buildStatCard(context, 'Today & Overdue', '${todayAndOverdue.length}', Icons.today_rounded, color: Colors.orangeAccent),
              _buildStatCard(context, 'Upcoming', '${inboxAndUpcoming.length}', Icons.upcoming_rounded, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 28),
          
          // Inline Search & Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedPriorityFilter,
                underline: const SizedBox(),
                items: ['All', 'High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text('$p Priority'))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() { _selectedPriorityFilter = val; });
                  }
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String?>(
                value: _selectedCategoryFilter,
                hint: const Text('All Categories'),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ...provider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (val) {
                  setState(() { _selectedCategoryFilter = val; });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          
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

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, {Color? color}) {
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
                  color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color ?? theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label, 
                      style: TextStyle(fontSize: 12, color: theme.disabledColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value, 
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
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
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${tasks.length}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
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
                        color: theme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.01) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text('No tasks in this section', style: TextStyle(color: theme.disabledColor, fontSize: 13)),
                      ),
                    )
                  : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final categoryIds = task.categoryIds.isNotEmpty ? task.categoryIds : (task.categoryId != null ? [task.categoryId!] : []);
                    final categories = categoryIds.map((id) => provider.getCategoryById(id)).where((c) => c != null).cast<Category>().toList();
                    final isSelected = _selectedTask?.id == task.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => _selectTask(task),
                        child: Container(
                          decoration: BoxDecoration(
                            border: isSelected 
                                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
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
  Widget _buildInspector(BuildContext context, TaskProvider provider, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_selectedTask == null && !_isCreatingTask) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 56, color: theme.disabledColor.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                'Select a Task',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: theme.disabledColor),
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
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _inspectorFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Inspector Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Task Details' : 'New Task',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _selectTask(null),
                ),
              ],
            ),
            const Divider(height: 24),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title Input
                    TextFormField(
                      controller: _titleController,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: l10n.title,
                        prefixIcon: const Icon(Icons.title, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // Description Input
                    TextFormField(
                      controller: _descController,
                      style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: l10n.description,
                        prefixIcon: const Icon(Icons.description_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 20),
                    
                    // Due Date Picker Trigger
                    InkWell(
                      onTap: () => _selectDueDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              _dueDate == null
                                  ? 'Set Due Date'
                                  : DateFormat.yMMMd().add_jm().format(_dueDate!),
                              style: TextStyle(fontSize: 13, color: _dueDate == null ? theme.disabledColor : theme.colorScheme.onSurface),
                            ),
                            const Spacer(),
                            if (_dueDate != null)
                              GestureDetector(
                                onTap: () => setState(() { _dueDate = null; }),
                                child: Icon(Icons.cancel_rounded, size: 16, color: theme.disabledColor),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Priority Selector
                    DropdownButtonFormField<TaskPriority>(
                      key: ValueKey('priority_${_selectedTask?.id ?? 'new'}'),
                      initialValue: _priority,
                      decoration: InputDecoration(
                        labelText: l10n.priorityLabel,
                        prefixIcon: const Icon(Icons.flag_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: TaskPriority.values.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            p == TaskPriority.high ? 'High' : p == TaskPriority.medium ? 'Medium' : 'Low',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() { _priority = val; });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Category Selector
                    Text(l10n.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: provider.categories.map((cat) {
                        final isSelected = _categoryIds.contains(cat.id);
                        return FilterChip(
                          labelStyle: const TextStyle(fontSize: 11),
                          selected: isSelected,
                          label: Text(cat.name),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _categoryIds = [cat.id]; // For web let's allow single category at a time
                              } else {
                                _categoryIds.remove(cat.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Google Tasks Sync Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.syncWithGoogleTasks, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(l10n.syncWithGoogleTasksSubtitle, style: const TextStyle(fontSize: 11)),
                      value: _syncWithGoogleTasks,
                      onChanged: (value) {
                        setState(() { _syncWithGoogleTasks = value; });
                      },
                    ),
                    
                    // Skip Reminders Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.doNotRemind, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: _skipReminders,
                      onChanged: (value) {
                        setState(() { _skipReminders = value; });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Custom Lines Section
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
            
            // Delete & Save Actions
            Row(
              children: [
                if (isEditing) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      provider.deleteTask(_selectedTask!.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Task deleted')),
                      );
                      _selectTask(null);
                    },
                    tooltip: 'Delete Task',
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () => _saveInspectorTask(provider),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isEditing ? 'Save Changes' : 'Create Task', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
