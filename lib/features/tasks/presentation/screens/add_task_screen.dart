import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';

import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/core/theme/theme_service.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
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
      if (widget.task != null) {
        Provider.of<TaskProvider>(context, listen: false).updateTask(
          widget.task!,
          title: _titleController.text,
          description: _descriptionController.text,
          dueDate: _selectedDate,
          priority: _priority,
          categoryId: _category,
        );
      } else {
        Provider.of<TaskProvider>(context, listen: false).addTask(
          _titleController.text,
          _descriptionController.text,
          _selectedDate,
          _priority,
          _category,
        );
      }
      Navigator.pop(context);
    }
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
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? l10n.editTask : l10n.newTask)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.title,
                  border: const OutlineInputBorder(),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.pleaseEnterATitle;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  border: const OutlineInputBorder(),
                  filled: true,
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.dueDateAndTime,
                          border: const OutlineInputBorder(),
                          filled: true,
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDate == null
                              ? l10n.noDateSelected
                              : themeService.use24HourFormat
                              ? DateFormat.yMMMd().add_Hm().format(
                                  _selectedDate!,
                                )
                              : DateFormat.yMMMd().add_jm().format(
                                  _selectedDate!,
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedDate = null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Consumer<TaskProvider>(
                builder: (context, provider, child) {
                  final categories = provider.categories;
                  return DropdownButtonFormField<String>(
                    initialValue: categories.any((c) => c.id == _category)
                        ? _category
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.category,
                      border: const OutlineInputBorder(),
                      filled: true,
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(l10n.noCategory),
                      ),
                      ...categories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Color(category.colorValue),
                                child: Icon(
                                  IconUtils.getIconData(category.iconCode),
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: InputDecoration(
                  labelText: l10n.priorityLabel,
                  border: const OutlineInputBorder(),
                  filled: true,
                  prefixIcon: const Icon(Icons.flag),
                ),
                items: TaskPriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(
                      _getPriorityLabel(priority, l10n).toUpperCase(),
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
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _saveTask,
                icon: const Icon(Icons.save),
                label: Text(isEditing ? l10n.updateTask : l10n.saveTask),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
