import 'package:flutter/material.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/shared/ui/widgets/snackbars.dart';

class ErrorHandlingService {
  Future<void> logError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
  }) async {
    AppLogger.error(
      reason ?? 'An error occurred',
      error: exception,
      stack: stack,
    );
  }

  void showError(BuildContext context, String message) {
    showErrorSnackBar(context, message);
  }
}
