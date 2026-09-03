import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/login_screen.dart';
import 'package:rocis_tasks/features/home/presentation/screens/home_screen.dart';
import 'package:rocis_tasks/features/onboarding/data/services/onboarding_service.dart';
import 'package:rocis_tasks/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:rocis_tasks/shared/ui/widgets/global_error_boundary.dart';

import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/features/categories/presentation/screens/categories_screen.dart';
import 'package:rocis_tasks/features/home/presentation/screens/settings_screen.dart';
import 'package:rocis_tasks/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/kanban/kanban_board_view.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final AuthService authService;
  final OnboardingService onboardingService;

  AppRouter(this.authService, this.onboardingService);

  late final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    refreshListenable: Listenable.merge([authService, onboardingService]),
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/add-task',
        builder: (context, state) => const AddTaskScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(body: SettingsScreen()),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const Scaffold(body: CalendarScreen()),
      ),
      GoRoute(
        path: '/kanban',
        builder: (context, state) => const Scaffold(body: KanbanBoardView()),
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = authService.currentUser != null;
      final isOnboardingComplete = onboardingService.hasSeenOnboarding;
      final isLoggingIn = state.uri.path == '/login';
      final isOnboarding = state.uri.path == '/onboarding';

      if (!isOnboardingComplete) {
        return isOnboarding ? null : '/onboarding';
      }

      if (isOnboarding) {
        return '/';
      }

      // If already logged in and trying to access /login, redirect to home '/'
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
  );
}
