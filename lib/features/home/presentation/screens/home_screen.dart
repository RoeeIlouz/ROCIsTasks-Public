import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rocis_tasks/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:rocis_tasks/features/calendar/presentation/widgets/calendar_filter_sheet.dart';
import 'package:rocis_tasks/features/calendar/presentation/widgets/calendar_coloring_sheet.dart';
import 'package:rocis_tasks/features/categories/presentation/screens/categories_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_sort_filter_sheet.dart';
import 'package:rocis_tasks/features/home/presentation/screens/settings_screen.dart';
import 'package:home_widget/home_widget.dart' as hw;
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'dart:async';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';

import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  StreamSubscription? _notificationActionSubscription;

  // Widget channel for receiving deep links from Android
  static const _widgetChannel = MethodChannel('com.example.rocis_tasks/widget');

  // Track last handled URI to prevent duplicate handling
  String? _lastHandledUri;
  DateTime? _lastHandledTime;

  final List<Widget> _screens = const [
    TaskListView(),
    CalendarScreen(),
    SettingsScreen(),
  ];

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
    debugPrint(
      'HomeScreen: Widget method call: ${call.method}, args: ${call.arguments}',
    );
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
      debugPrint('HomeScreen: Ignoring duplicate widget launch: $uri');
      return;
    }
    _lastHandledUri = uriString;
    _lastHandledTime = now;

    debugPrint('HomeScreen: Widget launch with uri: $uri');
    debugPrint(
      'HomeScreen: host=${uri.host}, path=${uri.path}, pathSegments=${uri.pathSegments}',
    );

    if (uri.host == 'add_task') {
      _navigateToAddTask();
      return;
    }

    // Handle calendar/day/$date path format from FullCalendarWidget
    // Just navigate to calendar page without setting a specific date
    if (uri.host == 'calendar') {
      debugPrint('HomeScreen: Navigating to calendar page');
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
        debugPrint('Error parsing date from widget: $e');
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _notificationActionSubscription?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final taskProvider = Provider.of<TaskProvider>(context);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
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
          ],
          if (_currentIndex == 1) ...[
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: l10n.calendarColors,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CalendarColoringSheet(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.filter_alt_outlined),
              tooltip: l10n.calendarFiltersTitle,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CalendarFilterSheet(),
                );
              },
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: _screens,
      ),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddTask,
              label: Text(
                l10n.newTask,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onItemTapped,
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.task_alt_outlined),
              selectedIcon: const Icon(Icons.task_alt),
              label: l10n.tasks,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: l10n.calendar,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l10n.settings,
            ),
          ],
        ),
      ),
    );
  }
}
