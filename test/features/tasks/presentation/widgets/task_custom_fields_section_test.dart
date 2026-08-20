import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_custom_fields_section.dart';
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
    required List<TaskCustomField> customFields,
    required Function(CustomFieldType type) onAddField,
    required Function(int index) onRemoveField,
    required Function(int index, String label, String value) onUpdateField,
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
            child: TaskCustomFieldsSection(
              customFields: customFields,
              onAddField: onAddField,
              onRemoveField: onRemoveField,
              onUpdateField: onUpdateField,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders Custom Lines header and quick-add chips', (tester) async {
    CustomFieldType? addedType;

    await tester.pumpWidget(
      buildTestWidget(
        customFields: [],
        onAddField: (type) => addedType = type,
        onRemoveField: (_) {},
        onUpdateField: (index, label, value) {},
      ),
    );

    expect(find.text('Custom Lines'), findsOneWidget);
    expect(find.text('+ Contact'), findsOneWidget);
    expect(find.text('+ Location'), findsOneWidget);
    expect(find.text('+ Link'), findsOneWidget);
    expect(find.text('+ Note'), findsOneWidget);
    expect(find.text('No custom lines added'), findsOneWidget);

    await tester.tap(find.text('+ Contact'));
    await tester.pumpAndSettle();

    expect(addedType, CustomFieldType.contact);
  });

  testWidgets('renders fields and handles remove interaction', (tester) async {
    final fields = [
      TaskCustomField(
        id: '1',
        type: CustomFieldType.contact,
        label: 'Phone',
        value: '+1234567890',
      ),
      TaskCustomField(
        id: '2',
        type: CustomFieldType.location,
        label: 'Meeting',
        value: 'Conference Room B',
      ),
    ];

    int? removedIndex;

    await tester.pumpWidget(
      buildTestWidget(
        customFields: fields,
        onAddField: (_) {},
        onRemoveField: (index) => removedIndex = index,
        onUpdateField: (index, label, value) {},
      ),
    );

    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('+1234567890'), findsOneWidget);
    expect(find.text('Meeting'), findsOneWidget);
    expect(find.text('Conference Room B'), findsOneWidget);

    final removeButtons = find.byIcon(Icons.close_rounded);
    expect(removeButtons, findsNWidgets(2));

    await tester.tap(removeButtons.first);
    await tester.pumpAndSettle();

    expect(removedIndex, equals(0));
  });
}
