import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class ErrorHandlingService {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  Future<void> logError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
  }) async {
    debugPrint('Error: $exception\nReason: $reason\nStack: $stack');
    await _crashlytics.recordError(exception, stack, reason: reason);
  }

  void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
