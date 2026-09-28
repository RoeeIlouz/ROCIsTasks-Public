import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:rocis_tasks/core/utils/web_helper.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/import_task_preview_sheet.dart';
import 'package:rocis_tasks/features/tasks/services/task_share_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

/// Target of `https://tasks.rocisapps.com/share?d=…|id=…` links (App Link on
/// Android, `/share` route on web). Shows the import preview, then goes home.
class SharedTaskLinkScreen extends StatefulWidget {
  final Uri link;

  const SharedTaskLinkScreen({super.key, required this.link});

  @override
  State<SharedTaskLinkScreen> createState() => _SharedTaskLinkScreenState();
}

class _SharedTaskLinkScreenState extends State<SharedTaskLinkScreen> {
  final TaskShareService _shareService = TaskShareService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openLink());
  }

  Future<void> _openLink() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    try {
      // On a cold start the categories may still be loading; they are needed
      // to match the shared task's category by name.
      await _waitForTasksLoaded(taskProvider);
      final shareData = await _shareService.resolveQrString(
        widget.link.toString(),
        taskProvider.categories,
      );
      if (!mounted) return;
      await ImportTaskPreviewSheet.show(context, shareData);
    } catch (e) {
      final expired = e is StateError && e.message == 'TASK_EXPIRED';
      messenger.showSnackBar(
        SnackBar(
          content: Text(expired ? l10n.taskExpired : l10n.invalidQrCode),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (kIsWeb) replaceBrowserUrl('/');
    if (mounted) context.go('/');
  }

  Future<void> _waitForTasksLoaded(TaskProvider provider) async {
    if (!provider.isLoading) return;
    final loaded = Completer<void>();
    void listener() {
      if (!provider.isLoading && !loaded.isCompleted) loaded.complete();
    }

    provider.addListener(listener);
    try {
      await loaded.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    } finally {
      provider.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
