import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';

class MockThemeService extends Mock implements ThemeService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  late MockThemeService mockThemeService;
  late MockSubscriptionService mockSubscriptionService;

  setUp(() {
    mockThemeService = MockThemeService();
    mockSubscriptionService = MockSubscriptionService();

    when(() => mockThemeService.useGlassmorphism).thenReturn(false);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
  });

  Widget buildTestWidget({
    BoxBorder? border,
    Color? color,
    Color? tintColor,
    bool isSelected = false,
    Color? selectedBorderColor,
  }) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
          ChangeNotifierProvider<SubscriptionService>.value(
            value: mockSubscriptionService,
          ),
        ],
        child: Scaffold(
          body: Center(
            child: GlassContainer(
              border: border,
              color: color,
              tintColor: tintColor,
              isSelected: isSelected,
              selectedBorderColor: selectedBorderColor,
              child: const Text('Content'),
            ),
          ),
        ),
      ),
    );
  }

  group('GlassContainer Non-Glassmorphic Mode', () {
    testWidgets(
      'renders clean surface container background when color is null and not selected',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Content'), findsOneWidget);
        final container = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(GlassContainer),
                matching: find.byType(Container),
              ),
            )
            .firstWhere((c) => c.decoration != null);

        final decoration = container.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        // In Material 3, surfaceContainerLow is used when color is null
        expect(decoration?.color, isNotNull);
      },
    );

    testWidgets('strictly preserves caller-provided border in non-glass mode', (
      tester,
    ) async {
      const customBorder = Border.fromBorderSide(
        BorderSide(color: Colors.red, width: 2.0),
      );

      await tester.pumpWidget(buildTestWidget(border: customBorder));

      final container = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(GlassContainer),
              matching: find.byType(Container),
            ),
          )
          .firstWhere((c) => c.decoration != null);

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, equals(customBorder));
    });

    testWidgets(
      'applies softened selection highlight when isSelected is true',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(isSelected: true));

        final container = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(GlassContainer),
                matching: find.byType(Container),
              ),
            )
            .firstWhere((c) => c.decoration != null);

        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, isNotNull);
        // Selected border width should be 1.5
        final border = decoration?.border as Border?;
        expect(border?.top.width, equals(1.5));
      },
    );

    testWidgets(
      'tintColor does not override neutral surface container in non-glass mode when unselected',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(tintColor: const Color(0xFFFF5722)),
        );

        final container = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(GlassContainer),
                matching: find.byType(Container),
              ),
            )
            .firstWhere((c) => c.decoration != null);

        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, isNot(equals(const Color(0xFFFF5722))));
      },
    );
  });

  group('GlassContainer Glassmorphic Mode', () {
    testWidgets(
      'renders BackdropFilter when glassmorphism is active and user is premium',
      (tester) async {
        when(() => mockThemeService.useGlassmorphism).thenReturn(true);
        when(() => mockSubscriptionService.isPremium).thenReturn(true);

        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
      },
    );

    testWidgets(
      'tints glass background with custom tintColor when glassmorphism is active',
      (tester) async {
        when(() => mockThemeService.useGlassmorphism).thenReturn(true);
        when(() => mockSubscriptionService.isPremium).thenReturn(true);

        const tint = Color(0xFFFF5722);
        await tester.pumpWidget(buildTestWidget(tintColor: tint));

        final container = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(GlassContainer),
                matching: find.byType(Container),
              ),
            )
            .firstWhere((c) => c.decoration != null);

        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, isNotNull);
        expect(decoration?.color?.a, closeTo(0.15, 0.01));
      },
    );
  });
}
