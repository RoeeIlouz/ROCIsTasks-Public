import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/shared/ui/widgets/celebration_particle_burst.dart';
import 'package:rocis_tasks/shared/ui/widgets/bouncy_checkbox.dart';

void main() {
  group('CelebrationParticleBurst', () {
    testWidgets('renders and calls onCompleted after animation finishes', (
      tester,
    ) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CelebrationParticleBurst(
                  center: const Offset(100, 100),
                  particleCount: 10,
                  onCompleted: () {
                    completed = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Initially CustomPaint is present and not yet completed
      expect(find.byType(CelebrationParticleBurst), findsOneWidget);
      expect(completed, isFalse);

      // Advance animation past 650ms
      await tester.pump(const Duration(milliseconds: 300));
      expect(completed, isFalse);

      await tester.pump(const Duration(milliseconds: 400));
      expect(completed, isTrue);
    });

    testWidgets(
      'triggerAt inserts overlay entry and cleans up after animation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      CelebrationParticleBurst.triggerAt(
                        context,
                        const Offset(150, 150),
                      );
                    },
                    child: const Text('Burst'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap button to trigger burst
        await tester.tap(find.text('Burst'));
        await tester.pump();

        // Burst should be mounted in the overlay
        expect(find.byType(CelebrationParticleBurst), findsOneWidget);

        // Complete animation
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Overlay should be cleaned up
        expect(find.byType(CelebrationParticleBurst), findsNothing);
      },
    );
  });

  group('BouncyCheckbox', () {
    testWidgets('renders unchecked and checked states with check icon', (
      tester,
    ) async {
      bool checked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: BouncyCheckbox(
                    isChecked: checked,
                    onTap: () {
                      setState(() {
                        checked = !checked;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Initially unchecked: check icon scale is 0.0
      expect(find.byType(BouncyCheckbox), findsOneWidget);

      // Tap to toggle
      await tester.tap(find.byType(BouncyCheckbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(checked, isTrue);

      // Tap again to uncheck
      await tester.tap(find.byType(BouncyCheckbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(checked, isFalse);
    });
  });
}
