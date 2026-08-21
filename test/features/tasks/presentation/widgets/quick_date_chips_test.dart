import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/theme/app_theme.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/l10n/app_localizations_en.dart';
import 'package:flutter/foundation.dart' hide Category;

class SynchronousAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const SynchronousAppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizationsEn());

  @override
  bool shouldReload(SynchronousAppLocalizationsDelegate old) => false;
}

class MockTaskProvider extends Mock implements TaskProvider {}
class MockThemeService extends Mock implements ThemeService {}
class MockSubscriptionService extends Mock implements SubscriptionService {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockTaskProvider mockTaskProvider;
  late MockThemeService mockThemeService;
  late MockSubscriptionService mockSubscriptionService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockThemeService = MockThemeService();
    mockSubscriptionService = MockSubscriptionService();
    mockAuthService = MockAuthService();

    when(() => mockTaskProvider.categories).thenReturn([]);
    when(() => mockThemeService.use24HourFormat).thenReturn(true);
    when(() => mockThemeService.isDarkMode).thenReturn(false);
    when(() => mockThemeService.useGlassmorphism).thenReturn(true);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
    when(() => mockAuthService.currentUser).thenReturn(null);
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<SubscriptionService>.value(value: mockSubscriptionService),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          SynchronousAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const Scaffold(
          body: AddTaskScreen(),
        ),
      ),
    );
  }

  testWidgets('renders Quick Date Chips (Today, Tomorrow, This Weekend, Next Week)', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('This Weekend'), findsOneWidget);
    expect(find.text('Next Week'), findsOneWidget);
  });

  testWidgets('tapping Tomorrow chip selects date and toggles check icon', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final tomorrowChip = find.text('Tomorrow');
    expect(tomorrowChip, findsOneWidget);

    await tester.ensureVisible(tomorrowChip);
    await tester.pumpAndSettle();

    await tester.tap(tomorrowChip);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
  });
}
