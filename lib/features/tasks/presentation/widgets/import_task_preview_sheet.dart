import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:rocis_tasks/core/utils/app_date_formats.dart';
import 'package:rocis_tasks/core/utils/haptic_utils.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/services/task_share_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class ImportTaskPreviewSheet extends StatefulWidget {
  final TaskShareData shareData;

  const ImportTaskPreviewSheet({
    super.key,
    required this.shareData,
  });

  static Future<bool?> show(BuildContext context, TaskShareData shareData) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImportTaskPreviewSheet(shareData: shareData),
    );
  }

  @override
  State<ImportTaskPreviewSheet> createState() => _ImportTaskPreviewSheetState();
}

class _ImportTaskPreviewSheetState extends State<ImportTaskPreviewSheet> {
  late Task _task;
  String? _selectedCategoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _task = widget.shareData.task;
    _selectedCategoryId = _task.categoryId;
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return const Color(0xFFFF5252);
      case TaskPriority.medium:
        return const Color(0xFFFFB300);
      case TaskPriority.low:
        return const Color(0xFF4CAF50);
    }
  }

  Future<void> _importTask() async {
    setState(() => _isSaving = true);
    HapticUtils.throttledLightImpact();

    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);

      // Create task via TaskProvider with positional and named arguments
      await taskProvider.addTask(
        _task.title,
        _task.description,
        _task.dueDate,
        _task.priority,
        _selectedCategoryId,
        categoryIds:
            _selectedCategoryId != null ? [_selectedCategoryId!] : null,
        subTasks: _task.subTasks,
        recurrenceRule: _task.recurrenceRule,
        customFields: _task.customFields,
        isGroceryList: _task.isGroceryList,
      );

      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.taskImportedSuccess),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = theme.colorScheme.primary;
    final taskProvider = Provider.of<TaskProvider>(context);
    final categories = taskProvider.categories;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        tintColor: primary,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.importTaskPreview,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.shareData.isCloud)
                          Text(
                            l10n.cloudShare7Days,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Text(
                            l10n.offlineDirect,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Task Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      _task.title.isEmpty ? l10n.newTask : _task.title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                    // Description
                    if (_task.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _task.description.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Badges row: Priority, Due Date, Recurrence
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Priority Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(_task.priority)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getPriorityColor(_task.priority)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag_rounded,
                                size: 14,
                                color: _getPriorityColor(_task.priority),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppDateFormats.priority(
                                  l10n,
                                  _task.priority,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getPriorityColor(_task.priority),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Due Date
                        if (_task.dueDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat.yMMMd().format(_task.dueDate!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Recurrence
                        if (_task.recurrenceRule != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.repeat_rounded,
                                  size: 14,
                                  color: theme.colorScheme.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.repeat,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // Subtasks checklist preview (reset to uncompleted)
                    if (_task.subTasks != null &&
                        _task.subTasks!.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        '${l10n.subtasks} (${_task.subTasks!.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _task.subTasks!.length,
                          itemBuilder: (ctx, index) {
                            final st = _task.subTasks![index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      st.title,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  if (st.quantity != null)
                                    Text(
                                      st.quantity!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Category Selection
              Text(
                l10n.destinationCategory,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              if (widget.shareData.suggestedCategoryName != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.suggestedCategory(
                      widget.shareData.suggestedCategoryName!,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],

              // Dropdown to pick local category
              DropdownButtonFormField<String?>(
                initialValue: _selectedCategoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.noCategory),
                  ),
                  ...categories.map(
                    (cat) => DropdownMenuItem<String?>(
                      value: cat.id,
                      child: Row(
                        children: [
                          Icon(
                            IconUtils.getIconData(cat.iconCode),
                            color: Color(cat.colorValue),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(cat.name),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _selectedCategoryId = val);
                },
              ),
              const SizedBox(height: 24),

              // Actions: Import vs Cancel
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context, false),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(l10n.importTask),
                      onPressed: _isSaving ? null : _importTask,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
