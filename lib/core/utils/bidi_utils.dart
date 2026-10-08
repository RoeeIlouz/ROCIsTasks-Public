import 'package:flutter/widgets.dart';

/// Paragraph direction for user-entered text (task titles, notes, items).
///
/// Uses the Unicode first-strong-character rule, the same one Android
/// TextViews and most chat apps apply: "לקנות MacBook Pro" stays RTL and
/// "Buy חלב" stays LTR, no matter how many words of the other script follow.
/// Text with no strong characters (empty, digits, emoji) keeps the ambient
/// direction so the field doesn't jump while the user starts typing.
class BidiUtils {
  BidiUtils._();

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  static TextDirection? firstStrong(String text) {
    for (final rune in text.runes) {
      if (_isRtl(rune)) return TextDirection.rtl;
      if (_letter.hasMatch(String.fromCharCode(rune))) {
        return TextDirection.ltr;
      }
    }
    return null;
  }

  // Hebrew, Arabic, Syriac, Thaana, NKo and their presentation forms.
  static bool _isRtl(int rune) =>
      (rune >= 0x0590 && rune <= 0x08FF) ||
      (rune >= 0xFB1D && rune <= 0xFDFF) ||
      (rune >= 0xFE70 && rune <= 0xFEFC) ||
      (rune >= 0x10800 && rune <= 0x10FFF) ||
      (rune >= 0x1E800 && rune <= 0x1EFFF);

  static TextDirection of(BuildContext context, String text) =>
      firstStrong(text) ?? Directionality.of(context);
}

/// Rebuilds [builder] with the paragraph direction of [controller]'s text, so
/// a TextField follows the script the user is typing in.
class BidiTextFieldBuilder extends StatelessWidget {
  final TextEditingController controller;
  final Widget Function(BuildContext context, TextDirection direction) builder;

  const BidiTextFieldBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) =>
          builder(context, BidiUtils.of(context, value.text)),
    );
  }
}
