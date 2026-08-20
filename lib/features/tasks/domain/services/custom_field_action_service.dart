import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class CustomFieldActionService {
  /// Executes the primary tap action for a given custom field.
  static Future<bool> performAction(
    BuildContext context,
    TaskCustomField field,
  ) async {
    final trimmedValue = field.value.trim();
    if (trimmedValue.isEmpty) return false;

    final l10n = AppLocalizations.of(context);

    switch (field.type) {
      case CustomFieldType.contact:
        return _launchContact(context, trimmedValue, l10n);
      case CustomFieldType.location:
        return _launchLocation(context, trimmedValue, l10n);
      case CustomFieldType.url:
        return _launchUrl(context, trimmedValue, l10n);
      case CustomFieldType.text:
        copyToClipboard(context, trimmedValue);
        return true;
    }
  }

  static Future<bool> _launchContact(
    BuildContext context,
    String value,
    AppLocalizations? l10n,
  ) async {
    if (value.contains('@')) {
      final emailUri = Uri(
        scheme: 'mailto',
        path: value,
      );
      try {
        final launched = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {}
    } else {
      final cleanNumber = value.replaceAll(RegExp(r'[^\d+]'), '');
      final telUri = Uri(
        scheme: 'tel',
        path: cleanNumber.isNotEmpty ? cleanNumber : value,
      );
      try {
        final launched = await launchUrl(
          telUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {}
    }

    if (context.mounted) {
      copyToClipboard(
        context,
        value,
        message: l10n?.copiedToClipboard,
      );
    }
    return false;
  }

  static Future<bool> _launchLocation(
    BuildContext context,
    String value,
    AppLocalizations? l10n,
  ) async {
    final mapUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(value)}',
    );
    try {
      final launched = await launchUrl(
        mapUrl,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (_) {}

    if (context.mounted) {
      copyToClipboard(
        context,
        value,
        message: l10n?.copiedToClipboard,
      );
    }
    return false;
  }

  static Future<bool> _launchUrl(
    BuildContext context,
    String value,
    AppLocalizations? l10n,
  ) async {
    String formattedUrl = value;
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    final parsedUri = Uri.tryParse(formattedUrl);
    if (parsedUri != null) {
      try {
        final launched = await launchUrl(
          parsedUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {}
    }

    if (context.mounted) {
      copyToClipboard(
        context,
        value,
        message: l10n?.copiedToClipboard,
      );
    }
    return false;
  }

  /// Copies text to clipboard and displays user feedback.
  static void copyToClipboard(
    BuildContext context,
    String value, {
    String? message,
  }) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      final displayMessage = message ?? l10n?.copiedToClipboard ?? 'Copied to clipboard';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Resolves the default icon for a custom field type.
  static IconData getIcon(CustomFieldType type, [String? value]) {
    switch (type) {
      case CustomFieldType.contact:
        if (value != null && value.contains('@')) {
          return Icons.alternate_email_rounded;
        }
        return Icons.phone_outlined;
      case CustomFieldType.location:
        return Icons.location_on_outlined;
      case CustomFieldType.url:
        return Icons.link_rounded;
      case CustomFieldType.text:
        return Icons.notes_rounded;
    }
  }

  /// Resolves the action button icon for a custom field.
  static IconData getActionIcon(CustomFieldType type, [String? value]) {
    switch (type) {
      case CustomFieldType.contact:
        if (value != null && value.contains('@')) {
          return Icons.mail_outline_rounded;
        }
        return Icons.phone_in_talk_rounded;
      case CustomFieldType.location:
        return Icons.directions_outlined;
      case CustomFieldType.url:
        return Icons.open_in_new_rounded;
      case CustomFieldType.text:
        return Icons.copy_rounded;
    }
  }

  /// Returns a human-friendly localized default label for the type.
  static String getDefaultLabel(
    CustomFieldType type,
    AppLocalizations l10n,
  ) {
    switch (type) {
      case CustomFieldType.contact:
        return l10n.contact;
      case CustomFieldType.location:
        return l10n.location;
      case CustomFieldType.url:
        return l10n.link;
      case CustomFieldType.text:
        return l10n.note;
    }
  }
}
