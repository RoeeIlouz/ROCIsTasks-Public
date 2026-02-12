import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/core/services/validation_service.dart';
import 'package:rocis_tasks/core/services/error_service.dart';
import 'package:rocis_tasks/core/validation/validators.dart';

import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';

import 'package:google_fonts/google_fonts.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;

  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _selectedDate;
  TaskPriority _priority = TaskPriority.medium;
  String? _category;
  ui.TextDirection _titleDirection = ui.TextDirection.ltr;
  ui.TextDirection _descriptionDirection = ui.TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _selectedDate = widget.task?.dueDate;
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _category = widget.task?.categoryId;
    _titleDirection = _getTextDirection(_titleController.text);
    _descriptionDirection = _getTextDirection(_descriptionController.text);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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

        // Sanitize inputs
        final sanitizedTitle = ValidationService.sanitizeText(
          _titleController.text,
        );
        final sanitizedDescription = ValidationService.sanitizeText(
          _descriptionController.text,
        );

        if (widget.task != null) {
          Provider.of<TaskProvider>(context, listen: false).updateTask(
            widget.task!,
            title: sanitizedTitle,
            description: sanitizedDescription,
            dueDate: _selectedDate,
            priority: _priority,
            categoryId: _category,
          );
        } else {
          Provider.of<TaskProvider>(context, listen: false).addTask(
            sanitizedTitle,
            sanitizedDescription,
            _selectedDate,
            _priority,
            _category,
          );
        }
        Navigator.pop(context);
      } catch (e) {
        ErrorService.handleUserError(
          context,
          'Failed to save task. Please try again.',
          error: e,
        );
      }
    }
  }

  ui.TextDirection _getTextDirection(String text) {
    return Bidi.detectRtlDirectionality(text)
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;
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
                validator: (value) {
                  final sanitized = ValidationService.sanitizeText(value ?? '');
                  final error = Validators.validateTaskTitle(
                    sanitized,
                    context,
                  );
                  if (error != null) return error;

                  if (ValidationService.containsHarmfulContent(sanitized)) {
                    return 'Title contains invalid content';
                  }

                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _titleDirection = _getTextDirection(value);
                  });
                },
              ),
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
                validator: (value) {
                  final error = ValidationService.validateTaskDescription(
                    value,
                  );
                  if (error != null) return error;

                  if (value != null &&
                      ValidationService.containsHarmfulContent(value)) {
                    return 'Description contains invalid content';
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
              Text(
                l10n.dueDateAndTime,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: l10n.dueDateAndTime,
                hint: 'Double tap to open date and time picker',
                button: true,
                child: InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.light
                          ? Colors.grey.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
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
                  return DropdownButtonFormField<String>(
                    initialValue: categories.any((c) => c.id == _category)
                        ? _category
                        : null,
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: SharedInputDecorations.getFieldDecoration(
                      label: l10n.category,
                      prefixIcon: Icons.category_outlined,
                      theme: theme,
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          l10n.noCategory,
                          style: GoogleFonts.outfit(),
                        ),
                      ),
                      ...categories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Color(category.colorValue),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(category.name, style: GoogleFonts.outfit()),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _category = value;
                      });
                    },
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
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                decoration: SharedInputDecorations.getFieldDecoration(
                  label: l10n.priorityLabel,
                  prefixIcon: Icons.flag_outlined,
                  theme: theme,
                ),
                items: TaskPriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(
                      _getPriorityLabel(priority, l10n),
                      style: GoogleFonts.outfit(),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _priority = value;
                    });
                  }
                },
              ),
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
}
