import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/error_service.dart';

void main() {
  group('ErrorService', () {
    test('should initialize without errors', () {
      expect(() => ErrorService.initialize(), returnsNormally);
    });

    testWidgets('should handle user error with snackbar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ErrorService.handleUserError(
                      context,
                      'Test error message',
                    );
                  },
                  child: const Text('Trigger Error'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to trigger error
      await tester.tap(find.text('Trigger Error'));
      await tester.pump();

      // Verify snackbar appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
    });
  });
}