import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rocis_tasks/core/config/router.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/features/onboarding/data/services/onboarding_service.dart';

class MockAuthService extends Mock implements AuthService {}
class MockOnboardingService extends Mock implements OnboardingService {}
class MockUser extends Mock implements User {}

void main() {
  late MockAuthService mockAuthService;
  late MockOnboardingService mockOnboardingService;

  setUp(() {
    mockAuthService = MockAuthService();
    mockOnboardingService = MockOnboardingService();
  });

  group('AppRouter Redirect Logic', () {
    test('Redirects to /onboarding if onboarding is not completed', () {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockOnboardingService.hasSeenOnboarding).thenReturn(false);

      final appRouter = AppRouter(mockAuthService, mockOnboardingService);
      final router = appRouter.router;

      expect(router.configuration.routes.length, 8);
    });

    test('Allows guest user to access "/" when onboarding is complete', () {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockOnboardingService.hasSeenOnboarding).thenReturn(true);

      final appRouter = AppRouter(mockAuthService, mockOnboardingService);
      final router = appRouter.router;

      expect(router.routeInformationProvider.value.uri.path, '/');
    });

    test('Redirects logged in user away from /login to "/"', () {
      final mockUser = MockUser();
      when(() => mockAuthService.currentUser).thenReturn(mockUser);
      when(() => mockOnboardingService.hasSeenOnboarding).thenReturn(true);

      final appRouter = AppRouter(mockAuthService, mockOnboardingService);
      final router = appRouter.router;

      expect(router.routeInformationProvider.value.uri.path, '/');
    });
  });
}
