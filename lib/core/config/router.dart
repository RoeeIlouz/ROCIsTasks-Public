import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/login_screen.dart';
import 'package:rocis_tasks/features/home/presentation/screens/home_screen.dart';
import 'package:rocis_tasks/features/onboarding/data/services/onboarding_service.dart';
import 'package:rocis_tasks/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:rocis_tasks/shared/ui/widgets/global_error_boundary.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    ],
    redirect: (context, state) {
      final isLoggedIn = authService.currentUser != null;
      final isOnboardingComplete = onboardingService.hasSeenOnboarding;
      final isLoggingIn = state.uri.path == '/login';
      final isOnboarding = state.uri.path == '/onboarding';

      if (!isOnboardingComplete) {
        return isOnboarding ? null : '/onboarding';
      }

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn || isOnboarding) {
        return '/';
      }

      return null;
    },
  );
}
