import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/home/presentation/widgets/command_palette_dialog.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

void main() {
  Widget buildTestWidget({
    required List<Task> tasks,
    required List<Category> categories,
    required ValueChanged<Task> onSelectTask,
    required VoidCallback onCreateTask,
    required ValueChanged<String> onSwitchTab,
    required VoidCallback onSyncTasks,
    required VoidCallback onToggleTheme,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CommandPaletteDialog(
          tasks: tasks,
          categories: categories,
          onSelectTask: onSelectTask,
          onCreateTask: onCreateTask,
          onSwitchTab: onSwitchTab,
          onSyncTasks: onSyncTasks,
          onToggleTheme: onToggleTheme,
        ),
      ),
    );
  }

  group('CommandPaletteDialog Tests', () {
    testWidgets('renders search field and action commands', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          tasks: [],
          categories: [],
          onSelectTask: (_) {},
          onCreateTask: () {},
          onSwitchTab: (_) {},
          onSyncTasks: () {},
          onToggleTheme: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Type a command or search tasks...'), findsOneWidget);
      expect(
        find.text('Create a new task with full properties'),
        findsOneWidget,
      );
    });

    testWidgets('filtering by query narrows results', (tester) async {
      final task1 = Task(
        id: '1',
        title: 'Design Wireframes',
        description: 'Mock up mobile screens',
        createdAt: DateTime.now(),
      );
      final task2 = Task(
        id: '2',
        title: 'Write Documentation',
        description: 'API specs',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestWidget(
          tasks: [task1, task2],
          categories: [],
          onSelectTask: (_) {},
          onCreateTask: () {},
          onSwitchTab: (_) {},
          onSyncTasks: () {},
          onToggleTheme: () {},
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Wireframes');
      await tester.pumpAndSettle();

      expect(find.text('Design Wireframes'), findsOneWidget);
      expect(find.text('Write Documentation'), findsNothing);
    });

    testWidgets('selecting an action triggers callback', (tester) async {
      bool createTriggered = false;

      await tester.pumpWidget(
        buildTestWidget(
          tasks: [],
          categories: [],
          onSelectTask: (_) {},
          onCreateTask: () {
            createTriggered = true;
          },
          onSwitchTab: (_) {},
          onSyncTasks: () {},
          onToggleTheme: () {},
        ),
      );
      await tester.pumpAndSettle();

      // Tap the New Task action (first item)
      final newTaskItem = find.text('Create a new task with full properties');
      expect(newTaskItem, findsOneWidget);
      await tester.tap(newTaskItem);
      await tester.pumpAndSettle();

      expect(createTriggered, isTrue);
    });
  });
}
