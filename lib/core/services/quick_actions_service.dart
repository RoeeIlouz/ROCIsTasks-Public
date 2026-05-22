import 'package:quick_actions/quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';

class QuickActionsService {
  static final QuickActionsService _instance = QuickActionsService._internal();
  factory QuickActionsService() => _instance;
  QuickActionsService._internal();

  final QuickActions _quickActions = const QuickActions();

  void initialize(BuildContext context) {
    _quickActions.initialize((String shortcutType) {
      _handleShortcut(context, shortcutType);
    });

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_new_task',
        localizedTitle: 'New Task',
        icon: 'ic_add',
      ),
      const ShortcutItem(
        type: 'action_empty_trash',
        localizedTitle: 'Empty Trash',
        icon: 'ic_delete',
      ),
      const ShortcutItem(
        type: 'action_sync',
        localizedTitle: 'Sync Now',
        icon: 'ic_sync',
      ),
    ]);
  }

  void _handleShortcut(BuildContext context, String type) {
    switch (type) {
      case 'action_new_task':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddTaskScreen(),
            fullscreenDialog: true,
          ),
        );
        break;
      case 'action_empty_trash':
        Provider.of<TaskProvider>(context, listen: false).clearTrash();
        break;
      case 'action_sync':
        Provider.of<TaskProvider>(context, listen: false).performFullSync();
        break;
    }
  }
}
