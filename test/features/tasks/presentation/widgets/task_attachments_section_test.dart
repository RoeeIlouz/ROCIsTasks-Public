import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_attachments_section.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/l10n/app_localizations_en.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:flutter/foundation.dart';

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

class MockThemeService extends Mock implements ThemeService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockThemeService mockThemeService;
  late MockSubscriptionService mockSubscriptionService;

  setUp(() {
    mockThemeService = MockThemeService();
    mockSubscriptionService = MockSubscriptionService();

    when(() => mockThemeService.useGlassmorphism).thenReturn(true);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
  });

  Widget buildTestWidget({
    required List<String> attachmentPaths,
    required VoidCallback onAddAttachment,
    required ValueChanged<int> onRemoveAttachment,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: mockSubscriptionService,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          SynchronousAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: TaskAttachmentsSection(
              attachmentPaths: attachmentPaths,
              onAddAttachment: onAddAttachment,
              onRemoveAttachment: onRemoveAttachment,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders Attachments header and add button', (tester) async {
    bool addCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        attachmentPaths: [],
        onAddAttachment: () => addCalled = true,
        onRemoveAttachment: (_) {},
      ),
    );

    expect(find.text('Attachments'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    expect(addCalled, isTrue);
  });

  testWidgets('renders attachment chips with extension badges and filename', (tester) async {
    final paths = ['/documents/project_brief.pdf', '/images/photo.png'];
    int? removedIndex;

    await tester.pumpWidget(
      buildTestWidget(
        attachmentPaths: paths,
        onAddAttachment: () {},
        onRemoveAttachment: (index) => removedIndex = index,
      ),
    );

    expect(find.text('project_brief.pdf'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);

    // Verify remove button interaction
    final closeIcons = find.byIcon(Icons.close);
    expect(closeIcons, findsNWidgets(2));

    await tester.tap(closeIcons.first);
    await tester.pumpAndSettle();

    expect(removedIndex, equals(0));
  });
}
