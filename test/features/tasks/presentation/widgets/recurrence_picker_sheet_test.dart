import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/tasks/domain/services/task_recurrence_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/recurrence_picker_sheet.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/l10n/app_localizations_en.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';

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

    when(() => mockThemeService.useGlassmorphism).thenReturn(false);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
  });

  Widget buildTestWidget({String? currentRule, void Function(String?)? onResult}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<SubscriptionService>.value(value: mockSubscriptionService),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          SynchronousAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await RecurrencePickerSheet.show(
                  context,
                  currentRule: currentRule,
                );
                onResult?.call(result);
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ),
    );
  }

  group('RecurrencePickerSheet Widget Tests', () {
    testWidgets('renders all preset options', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Recurrence'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekdays (Mon–Fri)'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Custom...'), findsOneWidget);
    });

    testWidgets('selecting Daily preset returns daily rule', (tester) async {
      String? returnedRule;
      await tester.pumpWidget(
        buildTestWidget(onResult: (res) => returnedRule = res),
      );
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();

      expect(returnedRule, TaskRecurrenceService.rruleDaily);
    });

    testWidgets('custom mode allows selecting frequency and interval', (tester) async {
      String? returnedRule;
      await tester.pumpWidget(
        buildTestWidget(onResult: (res) => returnedRule = res),
      );
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom...'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Recurrence'), findsOneWidget);
      expect(find.text('Repeats every'), findsOneWidget);

      // Increment interval
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);

      // Tap weeks segment
      await tester.tap(find.text('weeks'));
      await tester.pumpAndSettle();

      // Apply custom
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(returnedRule, 'FREQ=WEEKLY;INTERVAL=2');
    });
  });
}
