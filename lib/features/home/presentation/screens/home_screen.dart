import 'package:flutter/material.dart';
import 'package:rocis_tasks/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:rocis_tasks/features/categories/presentation/screens/categories_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_sort_filter_sheet.dart';
import 'package:rocis_tasks/features/home/presentation/screens/settings_screen.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'dart:async';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  StreamSubscription? _notificationActionSubscription;

  final List<Widget> _screens = const [
    TaskListView(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    // Handle Click Intents
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetLaunch);
    HomeWidget.widgetClicked.listen(_handleWidgetLaunch);

    // Handle Notification Actions
    _notificationActionSubscription = NotificationService().onAction.listen((
      action,
    ) {
      if (action == 'add_task') {
        _navigateToAddTask();
      }
    });
  }

  void _navigateToAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTaskScreen()),
    );
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri == null) return;

    if (uri.host == 'add_task') {
      _navigateToAddTask();
      return;
    }

    final dateStr = uri.queryParameters['selected_date'];
    if (dateStr != null) {
      try {
        final date = DateTime.parse(dateStr);
        // Switch to Calendar tab (index 1)
        _onItemTapped(1);

        // Use post-frame callback to ensure CalendarScreen is rebuilt/available
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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        /*leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),*/
        title: Text(
          _currentIndex == 0
              ? l10n.myTasks
              : _currentIndex == 1
              ? l10n.calendar
              : l10n.settings,
        ),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.category),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoriesScreen(),
                  ),
                );
              },
            ),
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.sort),
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
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
      ),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTaskScreen(),
                  ),
                );
              },
              label: Text(l10n.newTask),
              icon: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onItemTapped,
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
    );
  }
}
