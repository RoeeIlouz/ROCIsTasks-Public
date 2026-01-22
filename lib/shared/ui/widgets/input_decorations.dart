import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SharedInputDecorations {
  static InputDecoration getFieldDecoration({
    required String label,
    required ThemeData theme,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 22) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      filled: true,
      fillColor: theme.brightness == Brightness.light
          ? Colors.grey.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}
