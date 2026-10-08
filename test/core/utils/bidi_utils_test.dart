import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/utils/bidi_utils.dart';

void main() {
  group('BidiUtils.firstStrong', () {
    test('Hebrew with trailing English words stays RTL', () {
      expect(BidiUtils.firstStrong('לקנות MacBook Pro'), TextDirection.rtl);
    });

    test('English with trailing Hebrew word stays LTR', () {
      expect(BidiUtils.firstStrong('Buy חלב'), TextDirection.ltr);
    });

    test('skips digits, punctuation and emoji', () {
      expect(BidiUtils.firstStrong('🛒 3 לחם'), TextDirection.rtl);
      expect(BidiUtils.firstStrong('12:30 - meeting'), TextDirection.ltr);
    });

    test('Arabic is RTL', () {
      expect(BidiUtils.firstStrong('مرحبا world'), TextDirection.rtl);
    });

    test('no strong characters returns null', () {
      expect(BidiUtils.firstStrong(''), isNull);
      expect(BidiUtils.firstStrong('123 🙂 !'), isNull);
    });
  });
}
