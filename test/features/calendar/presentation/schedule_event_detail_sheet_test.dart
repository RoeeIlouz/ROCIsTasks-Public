import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/calendar/presentation/widgets/schedule_event_detail_sheet.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

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

SyncedScheduleEvent _event({bool recurring = true}) => SyncedScheduleEvent(
  id: 'evt_1',
  title: 'Recitation',
  courseId: 'c1',
  courseName: 'Linear Algebra',
  courseCode: '10234',
  location: 'Building 3, Room 12',
  typeIndex: 2,
  // First occurrence: Monday 2026-10-26, 10:00-11:30.
  startTime: DateTime(2026, 10, 26, 10, 0),
  endTime: DateTime(2026, 10, 26, 11, 30),
  recurring: recurring,
  daysOfWeek: const [3, 1],
  color: const Color(0xFF7E57C2),
  notes: 'Bring homework 2',
);

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('ScheduleEventDetailSheet', () {
    test('recurring occurrence is moved to the tapped day', () {
      final sheet = ScheduleEventDetailSheet(
        event: _event(),
        day: DateTime(2026, 11, 4),
      );
      expect(sheet.occurrence.start, DateTime(2026, 11, 4, 10, 0));
      expect(sheet.occurrence.end, DateTime(2026, 11, 4, 11, 30));
    });

    test('one-off event keeps its own date', () {
      final sheet = ScheduleEventDetailSheet(
        event: _event(recurring: false),
        day: DateTime(2026, 11, 4),
      );
      expect(sheet.occurrence.start, DateTime(2026, 10, 26, 10, 0));
    });

    test('weekdayList uses Schedule convention (0=Sun) and sorts', () {
      expect(
        ScheduleEventDetailSheet.weekdayList(const [3, 0, 1], 'en'),
        'Sun, Mon, Wed',
      );
    });

    testWidgets('renders class details and copies to tasks', (tester) async {
      final taskProvider = MockTaskProvider();
      final subscriptionService = MockSubscriptionService();
      when(() => subscriptionService.isPremium).thenReturn(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TaskProvider>.value(value: taskProvider),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
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
              body: ScheduleEventDetailSheet(
                event: _event(),
                day: DateTime(2026, 11, 4),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Linear Algebra'), findsOneWidget);
      expect(find.text('Recitation'), findsOneWidget);
      expect(find.text('Lab'), findsOneWidget);
      expect(find.text('10234'), findsOneWidget);
      expect(find.text('Every week on Mon, Wed'), findsOneWidget);
      expect(find.text('Building 3, Room 12'), findsOneWidget);
      expect(find.text('Bring homework 2'), findsOneWidget);
      expect(find.text('Open in ROCIs Schedule'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_task_rounded));
      await tester.pumpAndSettle();

      expect(taskProvider.addedTitle, 'Linear Algebra - Recitation');
      expect(taskProvider.addedDesc, contains('Bring homework 2'));
      expect(taskProvider.addedDesc, contains('📍 Building 3, Room 12'));
      expect(taskProvider.addedDueDate, DateTime(2026, 11, 4, 10, 0));
    });
  });
}
