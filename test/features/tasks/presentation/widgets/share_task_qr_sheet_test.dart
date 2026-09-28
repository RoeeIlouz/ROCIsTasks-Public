import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/share_task_qr_sheet.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';

class MockTaskProvider extends Mock implements TaskProvider {}

class MockThemeService extends Mock implements ThemeService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockTaskProvider mockTaskProvider;
  late MockThemeService mockThemeService;
  late MockSubscriptionService mockSubscriptionService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockThemeService = MockThemeService();
    mockSubscriptionService = MockSubscriptionService();
    mockAuthService = MockAuthService();

    when(() => mockThemeService.useGlassmorphism).thenReturn(false);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
    when(() => mockAuthService.currentUser).thenReturn(null);

    when(() => mockTaskProvider.getCategoryById(any())).thenReturn(
      Category(
        id: 'cat-1',
        name: 'Work',
        colorValue: 0xFF2196F3,
        iconCode: 58835,
      ),
    );
  });

  Widget buildTestWidget(Task task) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: mockSubscriptionService,
        ),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: ShareTaskQrSheet(task: task)),
      ),
    );
  }

  testWidgets('renders ShareTaskQrSheet with task title and QrImageView', (
    tester,
  ) async {
    final task = Task(
      title: 'Prepare demo release',
      description: 'Check widget and scanner',
      priority: TaskPriority.high,
    );

    await tester.pumpWidget(buildTestWidget(task));
    await tester.pumpAndSettle();

    expect(find.text('Prepare demo release'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byType(SegmentedButton<ShareMode>), findsOneWidget);
    expect(find.text('Offline Direct'), findsOneWidget);
    expect(find.text('Cloud Link (7 Days)'), findsOneWidget);
  });
}
