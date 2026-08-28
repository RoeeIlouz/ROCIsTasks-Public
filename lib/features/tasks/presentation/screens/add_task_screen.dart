import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/tasks/domain/services/custom_field_action_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/validation_service.dart';
import 'package:rocis_tasks/core/services/error_service.dart';
import 'package:rocis_tasks/core/validation/validators.dart';
import 'package:rocis_tasks/features/tasks/services/nlp_service.dart';
import 'package:rocis_tasks/features/tasks/domain/services/task_recurrence_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/recurrence_picker_sheet.dart';

import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_attachments_section.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_custom_fields_section.dart';

import 'package:google_fonts/google_fonts.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;
  final DateTime? initialDueDate;
  final TaskPriority? initialPriority;
  final String? initialCategoryId;

  const AddTaskScreen({
    super.key,
    this.task,
    this.initialDueDate,
    this.initialPriority,
    this.initialCategoryId,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _selectedDate;
  bool _dateCleared = false;
  String? _recurrenceRule;
  bool _recurrenceCleared = false;
  TaskPriority _priority = TaskPriority.medium;
  List<String> _selectedCategoryIds = [];
  ui.TextDirection _titleDirection = ui.TextDirection.ltr;
  ui.TextDirection _descriptionDirection = ui.TextDirection.ltr;
  List<SubTask> _subTasks = [];
  List<TextEditingController> _subTaskControllers = [];
  NlpResult? _nlpSuggestion;
  bool _requireSubTasksBeforeReminders = false;
  bool _syncWithGoogleTasks = false;
  bool _skipReminders = false;
  bool _isGroceryList = false;
  List<String> _attachmentPaths = [];
  List<TaskCustomField> _customFields = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _selectedDate = widget.task?.dueDate ?? widget.initialDueDate;
    _priority = widget.task?.priority ?? widget.initialPriority ?? TaskPriority.medium;
    _selectedCategoryIds = widget.task?.categoryIds.toList() ?? [];
    if (_selectedCategoryIds.isEmpty && widget.task?.categoryId != null) {
      _selectedCategoryIds.add(widget.task!.categoryId!);
    } else if (_selectedCategoryIds.isEmpty && widget.initialCategoryId != null) {
      _selectedCategoryIds.add(widget.initialCategoryId!);
    }
    _titleDirection = _getTextDirection(_titleController.text);
    _descriptionDirection = _getTextDirection(_descriptionController.text);
    _subTasks =
        widget.task?.subTasks?.map((st) => st.copyWith()).toList() ?? [];
    _subTaskControllers = _subTasks
        .map((st) => TextEditingController(text: st.title))
        .toList();
    _requireSubTasksBeforeReminders =
        widget.task?.requireSubTasksBeforeReminders ?? false;
    _syncWithGoogleTasks = widget.task?.syncWithGoogleTasks ?? false;
    _skipReminders = widget.task?.skipReminders ?? false;
    _isGroceryList = widget.task?.isGroceryList ?? false;
    _attachmentPaths = List<String>.from(widget.task?.attachmentPaths ?? const []);
    _customFields =
        widget.task?.customFields?.map((cf) => cf.copyWith()).toList() ?? [];
    _recurrenceRule = widget.task?.recurrenceRule;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final controller in _subTaskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDate != null
            ? TimeOfDay.fromDateTime(_selectedDate!)
            : TimeOfDay.now(),
      );

      if (!context.mounted) return;

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            12,
            0,
          );
        });
      }
    }
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      try {
        // Validate due date
        final dateError = ValidationService.validateDueDate(_selectedDate);
        if (dateError != null) {
          ErrorService.handleUserError(context, dateError);
          return;
        }

        // Google Tasks does not require a due date to sync.

        // Sanitize inputs
        final sanitizedTitle = ValidationService.sanitizeText(
          _titleController.text,
        );
        final sanitizedDescription = ValidationService.sanitizeText(
          _descriptionController.text,
        );

        final validCustomFields = _customFields
            .where((cf) => cf.label.trim().isNotEmpty || cf.value.trim().isNotEmpty)
            .toList();

        if (widget.task != null) {
          Provider.of<TaskProvider>(context, listen: false).updateTask(
            widget.task!,
            title: sanitizedTitle,
            description: sanitizedDescription,
            dueDate: _selectedDate,
            clearDueDate: _dateCleared,
            priority: _priority,
            categoryId: _selectedCategoryIds.isNotEmpty ? _selectedCategoryIds.first : null,
            categoryIds: _selectedCategoryIds,
            subTasks: _subTasks,
            requireSubTasksBeforeReminders: _requireSubTasksBeforeReminders,
            syncWithGoogleTasks: _syncWithGoogleTasks,
            attachmentPaths: _attachmentPaths,
            skipReminders: _skipReminders,
            isGroceryList: _isGroceryList,
            recurrenceRule: _recurrenceRule,
            clearRecurrenceRule: _recurrenceCleared,
            customFields: validCustomFields,
          );
        } else {
          Provider.of<TaskProvider>(context, listen: false).addTask(
            sanitizedTitle,
            sanitizedDescription,
            _selectedDate,
            _priority,
            _selectedCategoryIds.isNotEmpty ? _selectedCategoryIds.first : null,
            categoryIds: _selectedCategoryIds,
            subTasks: _subTasks,
            requireSubTasksBeforeReminders: _requireSubTasksBeforeReminders,
            syncWithGoogleTasks: _syncWithGoogleTasks,
            attachmentPaths: _attachmentPaths,
            skipReminders: _skipReminders,
            isGroceryList: _isGroceryList,
            recurrenceRule: _recurrenceRule,
            customFields: validCustomFields,
          );
        }
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      } catch (e) {
        final l10n = AppLocalizations.of(context)!;
        ErrorService.handleUserError(
          context,
          l10n.failedToSaveTask,
          error: e,
        );
      }
    }
  }

  void _addCustomField(CustomFieldType type) {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _customFields.add(
        TaskCustomField(
          type: type,
          label: CustomFieldActionService.getDefaultLabel(type, l10n),
          value: '',
        ),
      );
    });
    HapticFeedback.lightImpact();
  }

  void _removeCustomFieldAt(int index) {
    setState(() {
      _customFields.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  void _updateCustomFieldAt(int index, String label, String value) {
    if (index >= 0 && index < _customFields.length) {
      _customFields[index].label = label;
      _customFields[index].value = value;
    }
  }

  Future<void> _pickAttachments() async {
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    if (!subscriptionService.isPremium) {
      subscriptionService.showPaywall();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (!mounted || result == null) return;

    final pickedPaths = result.paths.whereType<String>().where((p) => p.isNotEmpty);
    if (pickedPaths.isEmpty) return;

    setState(() {
      for (final path in pickedPaths) {
        if (!_attachmentPaths.contains(path)) {
          _attachmentPaths.add(path);
        }
      }
    });
    HapticFeedback.lightImpact();
  }

  void _removeAttachmentAt(int index) {
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    if (!subscriptionService.isPremium) {
      subscriptionService.showPaywall();
      return;
    }

    setState(() {
      _attachmentPaths.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  DateTime _getQuickDateToday() {
    final now = DateTime.now();
    if (now.hour >= 18) {
      return DateTime(now.year, now.month, now.day, 23, 59);
    }
    return DateTime(now.year, now.month, now.day, 18, 0);
  }

  DateTime _getQuickDateTomorrow() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
  }

  DateTime _getQuickDateThisWeekend() {
    final now = DateTime.now();
    int daysUntilSaturday = (DateTime.saturday - now.weekday) % 7;
    if (daysUntilSaturday == 0 && now.hour >= 12) {
      daysUntilSaturday = 1;
    }
    final weekendDay = now.add(Duration(days: daysUntilSaturday));
    return DateTime(weekendDay.year, weekendDay.month, weekendDay.day, 10, 0);
  }

  DateTime _getQuickDateNextWeek() {
    final now = DateTime.now();
    int daysUntilNextMonday = (DateTime.monday - now.weekday + 7) % 7;
    if (daysUntilNextMonday == 0) {
      daysUntilNextMonday = 7;
    }
    final nextMonday = now.add(Duration(days: daysUntilNextMonday));
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day, 9, 0);
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onQuickDateTap(DateTime targetDate) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedDate != null && _isSameDay(_selectedDate, targetDate)) {
        _selectedDate = null;
        _dateCleared = true;
      } else {
        _selectedDate = targetDate;
        _dateCleared = false;
      }
    });
  }

  Widget _buildQuickDateChips(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final today = _getQuickDateToday();
    final tomorrow = _getQuickDateTomorrow();
    final weekend = _getQuickDateThisWeekend();
    final nextWeek = _getQuickDateNextWeek();

    final isToday = _isSameDay(_selectedDate, today);
    final isTomorrow = _isSameDay(_selectedDate, tomorrow);
    final isWeekend = _isSameDay(_selectedDate, weekend);
    final isNextWeek = _isSameDay(_selectedDate, nextWeek);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickDateChip(
            label: l10n.quickDateToday,
            icon: Icons.today_rounded,
            isSelected: isToday,
            onTap: () => _onQuickDateTap(today),
            theme: theme,
          ),
          const SizedBox(width: 8),
          _buildQuickDateChip(
            label: l10n.quickDateTomorrow,
            icon: Icons.wb_sunny_outlined,
            isSelected: isTomorrow,
            onTap: () => _onQuickDateTap(tomorrow),
            theme: theme,
          ),
          const SizedBox(width: 8),
          _buildQuickDateChip(
            label: l10n.quickDateThisWeekend,
            icon: Icons.weekend_outlined,
            isSelected: isWeekend,
            onTap: () => _onQuickDateTap(weekend),
            theme: theme,
          ),
          const SizedBox(width: 8),
          _buildQuickDateChip(
            label: l10n.quickDateNextWeek,
            icon: Icons.next_week_outlined,
            isSelected: isNextWeek,
            onTap: () => _onQuickDateTap(nextWeek),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : icon,
              size: 16,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ui.TextDirection _getTextDirection(String text) {
    return Bidi.detectRtlDirectionality(text)
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;
  }

  void _applyNlpSuggestion() {
    if (_nlpSuggestion == null || _nlpSuggestion!.dueDate == null) return;
    
    final themeService = Provider.of<ThemeService>(context, listen: false);
    
    setState(() {
      _selectedDate = _nlpSuggestion!.dueDate;
      if (themeService.autoRemoveNlpDates) {
        _titleController.text = _nlpSuggestion!.title;
        // Reset suggestion after applying and removing from title
        _nlpSuggestion = null;
      }
    });
    HapticFeedback.lightImpact();
  }

  String _getPriorityLabel(TaskPriority priority, AppLocalizations l10n) {
    switch (priority) {
      case TaskPriority.high:
        return l10n.high;
      case TaskPriority.medium:
        return l10n.medium;
      case TaskPriority.low:
        return l10n.low;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);
    final subscriptionService = Provider.of<SubscriptionService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l10n.editTask : l10n.newTask,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                textDirection: _titleDirection,
                decoration: SharedInputDecorations.getFieldDecoration(
                  label: l10n.title,
                  prefixIcon: Icons.title,
                  theme: theme,
                ),
                maxLength: 100,
                validator: (value) {
                  final sanitized = ValidationService.sanitizeText(value ?? '');
                  final error = Validators.validateTaskTitle(
                    sanitized,
                    context,
                  );
                  if (error != null) return error;

                  if (ValidationService.containsHarmfulContent(sanitized)) {
                    return l10n.titleInvalidContent;
                  }

                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _titleDirection = _getTextDirection(value);
                    _nlpSuggestion = NlpService.parse(value);
                    // Clear suggestion if it doesn't have a date or matches current
                    if (_nlpSuggestion?.dueDate == null || _nlpSuggestion?.dueDate == _selectedDate) {
                      _nlpSuggestion = null;
                    }
                  });
                },
              ),
              if (_nlpSuggestion != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(
                      'Suggest: ${DateFormat.yMMMd().add_jm().format(_nlpSuggestion!.dueDate!)}',
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                    onPressed: _applyNlpSuggestion,
                    backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                style: GoogleFonts.outfit(),
                textDirection: _descriptionDirection,
                decoration: SharedInputDecorations.getFieldDecoration(
                  label: l10n.description,
                  prefixIcon: Icons.description_outlined,
                  theme: theme,
                ),
                maxLines: 4,
                maxLength: 500,
                validator: (value) {
                  final error = ValidationService.validateTaskDescription(
                    value,
                  );
                  if (error != null) return error;

                  if (value != null &&
                      ValidationService.containsHarmfulContent(value)) {
                    return l10n.descriptionInvalidContent;
                  }

                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _descriptionDirection = _getTextDirection(value);
                  });
                },
              ),
              const SizedBox(height: 24),
              TaskAttachmentsSection(
                attachmentPaths: _attachmentPaths,
                onAddAttachment: _pickAttachments,
                onRemoveAttachment: _removeAttachmentAt,
              ),
              const SizedBox(height: 24),
              TaskCustomFieldsSection(
                customFields: _customFields,
                onAddField: _addCustomField,
                onRemoveField: _removeCustomFieldAt,
                onUpdateField: _updateCustomFieldAt,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.dueDateAndTime,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              _buildQuickDateChips(context, l10n, theme),
              const SizedBox(height: 10),
              Semantics(
                label: l10n.dueDateAndTime,
                hint: 'Double tap to open date and time picker',
                button: true,
                child: InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(16),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate == null
                              ? l10n.noDateSelected
                              : themeService.use24HourFormat
                              ? DateFormat.yMMMd().add_Hm().format(
                                  _selectedDate!,
                                )
                              : DateFormat.yMMMd().add_jm().format(
                                  _selectedDate!,
                                ),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedDate != null)
                          Semantics(
                            label: 'Clear selected date',
                            button: true,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDate = null;
                                  _dateCleared = true;
                                });
                              },
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 20,
                                color: theme.disabledColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.recurrence,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (!subscriptionService.isPremium)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PRO',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                    ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label: l10n.recurrence,
                hint: 'Double tap to configure recurrence',
                button: true,
                child: InkWell(
                  onTap: () async {
                    if (!subscriptionService.isPremium) {
                      subscriptionService.showPaywall();
                      return;
                    }
                    HapticFeedback.lightImpact();
                    final selectedRule = await RecurrencePickerSheet.show(
                      context,
                      currentRule: _recurrenceRule,
                    );
                    if (selectedRule != _recurrenceRule) {
                      setState(() {
                        _recurrenceRule = selectedRule;
                        _recurrenceCleared = selectedRule == null;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 20,
                          color: _recurrenceRule != null
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          TaskRecurrenceService.getRecurrenceLabel(
                            _recurrenceRule,
                            l10n,
                          ),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (_recurrenceRule != null)
                          Semantics(
                            label: 'Clear recurrence',
                            button: true,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _recurrenceRule = null;
                                  _recurrenceCleared = true;
                                });
                              },
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 20,
                                color: theme.disabledColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  _syncWithGoogleTasks
                      ? Icons.playlist_add_check_rounded
                      : Icons.playlist_add_rounded,
                ),
                title: Text(
                  l10n.syncWithGoogleTasks,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.syncWithGoogleTasksSubtitle,
                  style: GoogleFonts.outfit(fontSize: 13),
                ),
                value: _syncWithGoogleTasks,
                onChanged: (value) async {
                  if (!value) {
                    setState(() => _syncWithGoogleTasks = false);
                    return;
                  }

                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  
                  final token = await authService.getGoogleAccessToken();
                  if (!context.mounted) return;

                  if (token == null) {
                    final success = await authService.linkGoogleTasks();
                    if (!context.mounted) return;
                    if (!success) {
                      setState(() => _syncWithGoogleTasks = false);
                      return;
                    }
                  }

                  setState(() => _syncWithGoogleTasks = true);
                },
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  _skipReminders
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_rounded,
                ),
                title: Text(
                  l10n.doNotRemind,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.doNotRemindSubtitle,
                  style: GoogleFonts.outfit(fontSize: 13),
                ),
                value: _skipReminders,
                onChanged: (value) {
                  setState(() => _skipReminders = value);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  Icons.checklist_rounded,
                  color: _isGroceryList ? theme.colorScheme.primary : null,
                ),
                title: Text(
                  l10n.groceryListMode,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.groceryListModeSubtitle,
                  style: GoogleFonts.outfit(fontSize: 13),
                ),
                value: _isGroceryList,
                onChanged: (value) {
                  setState(() => _isGroceryList = value);
                },
              ),
              const SizedBox(height: 24),
              Text(
                l10n.category,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Consumer<TaskProvider>(
                builder: (context, provider, child) {
                  final categories = provider.categories;
                  if (categories.isEmpty) {
                    return Text(
                      l10n.noCategory,
                      style: GoogleFonts.outfit(color: theme.colorScheme.onSurfaceVariant),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((category) {
                      final isSelected = _selectedCategoryIds.contains(category.id);
                      return FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(category.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(category.name, style: GoogleFonts.outfit()),
                          ],
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategoryIds.add(category.id);
                            } else {
                              _selectedCategoryIds.remove(category.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                l10n.priorityLabel,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: TaskPriority.values.map((priority) {
                  final isSelected = _priority == priority;
                  final Color color = priority == TaskPriority.high
                      ? Colors.redAccent
                      : (priority == TaskPriority.medium
                          ? Colors.orangeAccent
                          : Colors.greenAccent);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _priority = priority);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.18)
                                : theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : theme.dividerColor.withValues(alpha: 0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.6),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getPriorityLabel(priority, l10n),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? color
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _buildSubTasksSection(context, l10n),
              const SizedBox(height: 40),
              Semantics(
                label: isEditing ? l10n.updateTask : l10n.saveTask,
                button: true,
                child: FilledButton(
                  onPressed: _saveTask,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isEditing ? Icons.check_rounded : Icons.add_rounded),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? l10n.updateTask : l10n.saveTask,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTasksSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.subtasks,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
            ),
            if (!subscriptionService.isPremium)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PRO',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () {
                if (!subscriptionService.isPremium) {
                  subscriptionService.showPaywall();
                  return;
                }
                HapticFeedback.lightImpact();
                setState(() {
                  _subTasks.add(SubTask(title: ''));
                  _subTaskControllers.add(TextEditingController());
                });
              },
            ),
          ],
        ),
        if (_subTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(l10n.noSubtasksAdded, style: theme.textTheme.bodySmall),
          ),
        ...List.generate(_subTasks.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Checkbox(
                  value: _subTasks[index].isCompleted,
                  onChanged: (value) {
                    setState(() {
                      _subTasks[index].isCompleted = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _subTaskControllers[index],
                    onChanged: (value) {
                      _subTasks[index].title = value;
                    },
                    decoration: InputDecoration(
                      hintText: l10n.enterSubtask,
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.outfit(fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    setState(() {
                      _subTasks.removeAt(index);
                      _subTaskControllers[index].dispose();
                      _subTaskControllers.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        }),
        if (_subTasks.isNotEmpty)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              _requireSubTasksBeforeReminders
                  ? Icons.link_rounded
                  : Icons.link_off_rounded,
            ),
            title: Text(
              l10n.requireSubTasksBeforeReminders,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l10n.requireSubTasksBeforeRemindersSubtitle,
              style: GoogleFonts.outfit(fontSize: 13),
            ),
            value: _requireSubTasksBeforeReminders,
            onChanged: (value) {
              if (!subscriptionService.isPremium) {
                subscriptionService.showPaywall();
                return;
              }
              setState(() => _requireSubTasksBeforeReminders = value);
            },
          ),
      ],
    );
  }
}
