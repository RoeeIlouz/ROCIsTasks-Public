import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/login_screen.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/theme/app_theme.dart';

import 'package:flutter/foundation.dart';
import 'package:rocis_tasks/l10n/app_localizations_en.dart';

class SynchronousAppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const SynchronousAppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(AppLocalizationsEn());

  @override
  bool shouldReload(SynchronousAppLocalizationsDelegate old) => false;
}

class MockAuthService extends Mock implements AuthService {}

class MockErrorHandlingService extends Mock implements ErrorHandlingService {}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    when(() => mockAuthService.initialized).thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        Provider<ErrorHandlingService>.value(
          value: MockErrorHandlingService(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          SynchronousAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', '')],
        home: const Scaffold(body: LoginScreen()),
      ),
    );
  }

  group('LoginScreen', () {
    testWidgets('renders login form elements', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Should have email and password fields
      expect(find.byType(TextFormField), findsNWidgets(2));
      // Should have login button
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('renders Google Sign-In button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Google Sign-In button should be present
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('validates empty email field', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Try to submit the form
      final loginButton = find.byType(ElevatedButton).first;
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Should show localized validation error
      expect(find.textContaining('email'), findsWidgets);
    });

    testWidgets('validates invalid email format', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter invalid email (no @)
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'notanemail');
      await tester.pumpAndSettle();

      // Submit form
      final loginButton = find.byType(ElevatedButton).first;
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Should show localized validation error
      expect(find.textContaining('email'), findsWidgets);
    });

    testWidgets('shows navigation to register screen', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Should have a text button or similar for register navigation
      expect(find.byType(TextButton), findsWidgets);
    });

    testWidgets('renders Continue as Guest button and calls continueAsGuest on tap', (tester) async {
      when(() => mockAuthService.continueAsGuest()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final guestButton = find.widgetWithText(TextButton, 'Continue as Guest');
      expect(guestButton, findsOneWidget);

      await tester.ensureVisible(guestButton);
      await tester.pumpAndSettle();
      await tester.tap(guestButton);
      await tester.pumpAndSettle();

      verify(() => mockAuthService.continueAsGuest()).called(1);
    });
  });
}
