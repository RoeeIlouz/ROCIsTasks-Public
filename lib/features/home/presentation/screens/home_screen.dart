import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rocis_tasks/features/home/presentation/screens/web_home_screen.dart';
import 'package:rocis_tasks/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:rocis_tasks/features/categories/presentation/screens/categories_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_sort_filter_sheet.dart';
import 'package:rocis_tasks/features/home/presentation/screens/settings_screen.dart';
import 'package:rocis_tasks/features/home/presentation/screens/app_guide_screen.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/security_settings_screen.dart';
import 'package:home_widget/home_widget.dart' as hw;
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'dart:async';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/widgets/easter_egg_spinner.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  StreamSubscription? _notificationActionSubscription;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Widget channel for receiving deep links from Android
  static const _widgetChannel = MethodChannel('com.rocisapps.tasks/widget');

  // Track last handled URI to prevent duplicate handling
  String? _lastHandledUri;
  DateTime? _lastHandledTime;



  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    // Handle Click Intents from Home Widgets (HomeWidget plugin)
    hw.HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetLaunch);
    hw.HomeWidget.widgetClicked.listen(_handleWidgetLaunch);

    // Handle widget deep links via method channel (for fill-in intents)
    _widgetChannel.setMethodCallHandler(_handleWidgetMethodCall);

    // Handle Notification Actions
    _notificationActionSubscription = NotificationService().onAction.listen((
      action,
    ) {
      if (action == 'add_task') {
        _navigateToAddTask();
      }
    });
  }

  Future<dynamic> _handleWidgetMethodCall(MethodCall call) async {
    // Widget method call handled
    if (call.method == 'onWidgetClick') {
      final uriString = call.arguments as String?;
      if (uriString != null) {
        final uri = Uri.tryParse(uriString);
        if (uri != null) {
          _handleWidgetLaunch(uri);
        }
      }
    }
    return null;
  }

  void _navigateToAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTaskScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri == null) return;

    // Prevent duplicate handling of the same URI within 1 second
    final now = DateTime.now();
    final uriString = uri.toString();
    if (_lastHandledUri == uriString &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!).inMilliseconds < 1000) {
      // Ignoring duplicate widget launch
      return;
    }
    _lastHandledUri = uriString;
    _lastHandledTime = now;

    // Widget launch with uri handled

    if (uri.host == 'add_task') {
      _navigateToAddTask();
      return;
    }

    // Handle calendar/day/$date path format from FullCalendarWidget
    // Just navigate to calendar page without setting a specific date
    if (uri.host == 'calendar') {
      // Navigating to calendar page
      _onItemTapped(1);
      return;
    }

    // Handle legacy selected_date query parameter format
    final dateStr = uri.queryParameters['selected_date'];
    if (dateStr != null) {
      try {
        final date = DateTime.parse(dateStr);
        _onItemTapped(1);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final calendarProvider = Provider.of<CalendarProvider>(
            context,
            listen: false,
          );
          calendarProvider.setSelectedDate(date);
        });
      } catch (e) {
        // Error parsing date from widget
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _notificationActionSubscription?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      Provider.of<TaskProvider>(context, listen: false).syncGoogleTasksToLocal();
    }
  }

  void _onItemTapped(int index) {
    if (_isSearching) {
      setState(() {
        _isSearching = false;
        _searchController.clear();
      });
      Provider.of<TaskProvider>(context, listen: false).setSearchQuery('');
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('HomeScreen: build called');
    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint(
          'HomeScreen LayoutBuilder: maxWidth = ${constraints.maxWidth}',
        );
        if (constraints.maxWidth >= 950) {
          debugPrint('HomeScreen: rendering WebHomeScreen');
          return const WebHomeScreen();
        }
        debugPrint('HomeScreen: rendering MobileHomeScreen');
        return _buildMobileHomeScreen(context);
      },
    );
  }

  Widget _buildMobileHomeScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final useGlass =
        themeService.useGlassmorphism && subscriptionService.isPremium;

    if (taskProvider.taskToEdit != null) {
      final task = taskProvider.taskToEdit!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        taskProvider.clearTaskToEdit();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddTaskScreen(task: task)),
        );
      });
    }

    // Show security prompt when private task/category is created without security
    if (taskProvider.showSecurityPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        taskProvider.clearSecurityPrompt();
        _showSecurityPromptDialog(context, l10n);
      });
    }

    final isSelectionMode = taskProvider.isSelectionMode && _currentIndex == 0;

    return Scaffold(
      extendBody: true,
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: theme.colorScheme.primaryContainer,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: taskProvider.clearSelection,
              ),
              title: Text(
                '${taskProvider.selectedCount} ${l10n.tasks}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.push_pin_outlined),
                  tooltip: l10n.pinTask,
                  onPressed: taskProvider.toggleSelectedTasksPin,
                ),
                IconButton(
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  tooltip: l10n.category,
                  onPressed: () {
                    _showBulkCategoryPicker(context, taskProvider);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.delete,
                  onPressed: () =>
                      _showBulkDeleteConfirmation(context, taskProvider, l10n),
                ),
                const SizedBox(width: 8),
              ],
            )
          : AppBar(
              title: _isSearching && _currentIndex == 0
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: GoogleFonts.outfit(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: l10n.searchTasksHint,
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.outfit(
                          color: theme.disabledColor.withValues(alpha: 0.5),
                        ),
                      ),
                      onChanged: (value) {
                        Provider.of<TaskProvider>(
                          context,
                          listen: false,
                        ).setSearchQuery(value);
                      },
                    )
                  : Text(
                      _currentIndex == 0
                          ? l10n.myTasks
                          : _currentIndex == 1
                          ? l10n.calendar
                          : l10n.settings,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
              actions: [
                if (_currentIndex == 0) ...[
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() {
                        if (_isSearching) {
                          _searchController.clear();
                          Provider.of<TaskProvider>(
                            context,
                            listen: false,
                          ).setSearchQuery('');
                        }
                        _isSearching = !_isSearching;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    tooltip: l10n.categories,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoriesScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_alt_outlined),
                    tooltip: l10n.sortAndFilter,
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const TaskSortFilterSheet(),
                      );
                    },
                  ),
                  if (taskProvider.showMyTasksGuideShortcut)
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded),
                      tooltip: l10n.appGuide,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AppGuideScreen(),
                          ),
                        );
                      },
                    ),
                ],
                const SizedBox(width: 8),
              ],
            ),
      body: Column(
        children: [
          Consumer<ConnectivityService>(
            builder: (context, connectivity, child) {
              if (connectivity.isOnline) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.errorContainer,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.offlineMode, // Ensure string exists or use literal
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              children: [
                const TaskListView(),
                LazyInitializationWidget(
                  isVisible: _currentIndex == 1,
                  child: const CalendarScreen(),
                ),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? EasterEggSpinner(
              child: GlassContainer(
                borderRadius: BorderRadius.circular(16),
                elevation: 4.0,
                color: useGlass
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.primary,
                opacity: 0.15,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _navigateToAddTask,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: useGlass
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.newTask,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: useGlass
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  0,
                  Icons.task_alt_outlined,
                  Icons.task_alt,
                  l10n.tasks,
                  theme,
                ),
                _buildNavItem(
                  1,
                  Icons.calendar_month_outlined,
                  Icons.calendar_month,
                  l10n.calendar,
                  theme,
                ),
                _buildNavItem(
                  2,
                  Icons.settings_outlined,
                  Icons.settings,
                  l10n.settings,
                  theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
    ThemeData theme,
  ) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSecurityPromptDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline, size: 48),
        title: Text(l10n.enableSecurity),
        content: Text(l10n.enableSecurityDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.notNow),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecuritySettingsScreen(),
                ),
              );
            },
            child: Text(l10n.setUp),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteConfirmation(
    BuildContext context,
    TaskProvider provider,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTaskTitle),
        content: Text(
          '${l10n.deleteTaskConfirmation} (${provider.selectedCount} ${l10n.tasks})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              provider.deleteSelectedTasks();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showBulkCategoryPicker(BuildContext context, TaskProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.filterByCategory,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: provider.categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.no_accounts_outlined),
                      title: Text(AppLocalizations.of(context)!.noCategory),
                      onTap: () {
                        provider.moveSelectedTasksToCategory(null);
                        Navigator.pop(context);
                      },
                    );
                  }
                  final category = provider.categories[index - 1];
                  return ListTile(
                    leading: Icon(
                      IconUtils.getIconData(category.iconCode),
                      color: Color(category.colorValue),
                    ),
                    title: Text(category.name),
                    onTap: () {
                      provider.moveSelectedTasksToCategory(category.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LazyInitializationWidget extends StatefulWidget {
  final Widget child;
  final bool isVisible;

  const LazyInitializationWidget({
    super.key,
    required this.child,
    required this.isVisible,
  });

  @override
  State<LazyInitializationWidget> createState() => _LazyInitializationWidgetState();
}

class _LazyInitializationWidgetState extends State<LazyInitializationWidget> {
  bool _initialized = false;

  @override
  void didUpdateWidget(covariant LazyInitializationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !_initialized) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isVisible) {
      _initialized = true;
    }
    return _initialized ? widget.child : const SizedBox.shrink();
  }
}
