import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';

/// Agenda widgets must place events on the same days as the in-app calendar.
void main() {
  test('an all-day event stays on its own day', () {
    final days = WidgetDataService.eventDays(
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 6),
    );
    expect(days, [DateTime(2026, 10, 5)]);
  });

  test('a multi-day all-day event ends before its exclusive end', () {
    final days = WidgetDataService.eventDays(
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 8),
    );
    expect(days, [
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 6),
      DateTime(2026, 10, 7),
    ]);
  });

  test('a timed event crossing midnight shows on both days', () {
    final days = WidgetDataService.eventDays(
      DateTime(2026, 10, 5, 22),
      DateTime(2026, 10, 6, 1),
    );
    expect(days, [DateTime(2026, 10, 5), DateTime(2026, 10, 6)]);
  });

  test('a zero-length event at midnight keeps its day', () {
    final days = WidgetDataService.eventDays(
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 5),
    );
    expect(days, [DateTime(2026, 10, 5)]);
  });

  test('days advance by calendar day across a DST change', () {
    final days = WidgetDataService.eventDays(
      DateTime(2026, 10, 24),
      DateTime(2026, 10, 28),
    );
    expect(days.map((d) => d.day), [24, 25, 26, 27]);
  });
}
