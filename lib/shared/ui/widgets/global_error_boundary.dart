import 'package:flutter/material.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:google_fonts/google_fonts.dart';

/// A widget that catches unhandled Flutter errors and displays a fallback UI
class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;

  const GlobalErrorBoundary({super.key, required this.child});

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  @override
  void initState() {
    super.initState();
    // Override the default ErrorWidget
    ErrorWidget.builder = (FlutterErrorDetails details) {
      AppLogger.critical(
        'Unhandled Flutter Error captured by GlobalErrorBoundary',
        error: details.exception,
        stack: details.stack,
      );
      return _buildErrorUI(details.exception);
    };
  }

  void _handleRetry() {
    setState(() {});
  }

  Widget _buildErrorUI(Object error) {
    return Material(
      child: Container(
        padding: const EdgeInsets.all(24),
        color: const Color(0xFFF8F9FA), // Clean neutral background
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.report_problem_rounded,
                color: Color(0xFFE53935),
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Oops! Something went wrong',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF212121),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'An unexpected error occurred. We\'ve been notified and are looking into it.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF757575),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _handleRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'Try Again',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      error.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

const bool kDebugMode = !bool.fromEnvironment('dart.vm.product');
