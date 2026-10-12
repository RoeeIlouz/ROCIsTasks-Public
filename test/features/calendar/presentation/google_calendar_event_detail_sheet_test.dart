import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/calendar/presentation/widgets/google_calendar_event_detail_sheet.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockTaskProvider extends ChangeNotifier implements TaskProvider {
  String? addedTitle;
  String? addedDesc;
  DateTime? addedDueDate;

  @override
  Future<void> addTask(
    String title,
    String description,
    DateTime? dueDate,
    TaskPriority priority,
    String? category, {
    List<String>? categoryIds,
    List<SubTask>? subTasks,
    bool requireSubTasksBeforeReminders = false,
    bool syncWithGoogleTasks = false,
    List<String>? attachmentPaths,
    bool skipReminders = false,
    bool isGroceryList = false,
    String? recurrenceRule,
    List<TaskCustomField>? customFields,
  }) async {
    addedTitle = title;
    addedDesc = description;
    addedDueDate = dueDate;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  setUpAll(tz.initializeTimeZones);

  group('GoogleCalendarEventDetailSheet tests', () {
    test('cleanHtmlDescription strips HTML tags and decodes entities', () {
      const raw = '<p>Hello <b>World</b>!</p><br/>Join us at &amp; friends &quot;party&quot;&nbsp;today!';
      final cleaned = GoogleCalendarEventDetailSheet.cleanHtmlDescription(raw);
      expect(cleaned, contains('Hello World!'));
      expect(cleaned, contains('Join us at & friends "party" today!'));
      expect(cleaned.contains('<p>'), isFalse);
      expect(cleaned.contains('<br>'), isFalse);
    });

    testWidgets('renders event details with location, meeting, notes, and copy action',
        (tester) async {
      final mockTaskProvider = MockTaskProvider();
      final mockSubscriptionService = MockSubscriptionService();
      when(() => mockSubscriptionService.isPremium).thenReturn(true);

      final start = tz.TZDateTime(tz.local, 2026, 10, 12, 14, 0);
      final end = tz.TZDateTime(tz.local, 2026, 10, 12, 15, 0);

      final event = Event(
        'primary',
        eventId: 'test_event_1',
        title: 'Strategy Meeting',
        description: 'Discuss Q4 roadmap.<br>Link: https://meet.google.com/abc-defg-hij',
        location: 'Room 402, Building B',
        start: start,
        end: end,
        attendees: [
          Attendee(name: 'Alice', emailAddress: 'alice@example.com', isOrganiser: true),
          Attendee(name: 'Bob', emailAddress: 'bob@example.com'),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
            ChangeNotifierProvider<SubscriptionService>.value(value: mockSubscriptionService),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: GoogleCalendarEventDetailSheet(
                event: event,
                eventColor: const Color(0xFF4285F4),
                calendarName: 'Work',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title & calendar badge
      expect(find.text('Strategy Meeting'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);

      // Verify location
      expect(find.text('Room 402, Building B'), findsOneWidget);

      // Verify Google Meet detection
      expect(find.text('Google Meet'), findsOneWidget);

      // Verify description
      expect(find.textContaining('Discuss Q4 roadmap'), findsOneWidget);

      // Verify attendees
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      // Verify copy to tasks button
      final copyButton = find.byIcon(Icons.add_task_rounded);
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(mockTaskProvider.addedTitle, 'Strategy Meeting');
      expect(mockTaskProvider.addedDesc, contains('Discuss Q4 roadmap'));
      expect(mockTaskProvider.addedDesc, contains('📍 Room 402, Building B'));
    });
  });
}
