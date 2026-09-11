import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/services/nlp_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';

class QuickAddTaskBottomSheet extends StatefulWidget {
  final DateTime? initialDueDate;
  final String? initialCategoryId;

  const QuickAddTaskBottomSheet({
    super.key,
    this.initialDueDate,
    this.initialCategoryId,
  });

  @override
  State<QuickAddTaskBottomSheet> createState() =>
      _QuickAddTaskBottomSheetState();
}

class _QuickAddTaskBottomSheetState extends State<QuickAddTaskBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  DateTime? _selectedDate;
  TaskPriority _priority = TaskPriority.medium;
  String? _selectedCategoryId;

  NlpResult? _nlpResult;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDueDate;
    _selectedCategoryId = widget.initialCategoryId;
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      if (_nlpResult != null) {
        setState(() => _nlpResult = null);
      }
      return;
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final result = NlpService.parse(text, categories: taskProvider.categories);

    setState(() {
      _nlpResult = result;
      if (result.dueDate != null) {
        _selectedDate = result.dueDate;
      }
      if (result.priority != null) {
        _priority = result.priority!;
      }
      if (result.categoryId != null) {
        _selectedCategoryId = result.categoryId;
      }
    });
  }

  Future<void> _submitTask() async {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final themeService = Provider.of<ThemeService>(context, listen: false);

    // If NLP title is clean and user has setting or parsed title, use clean title
    final title = (_nlpResult != null && themeService.autoRemoveNlpDates)
        ? _nlpResult!.title
        : rawText;

    try {
      await taskProvider.addTask(
        title,
        '',
        _selectedDate,
        _priority,
        _selectedCategoryId,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Task created!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openFullAddTaskScreen() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTaskScreen(
          task: null,
          initialDueDate: _selectedDate,
          initialPriority: _priority,
          initialCategoryId: _selectedCategoryId,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDate != null
            ? TimeOfDay.fromDateTime(_selectedDate!)
            : const TimeOfDay(hour: 12, minute: 0),
      );

      setState(() {
        if (pickedTime != null) {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        } else {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            12,
            0,
          );
        }
      });
      HapticFeedback.lightImpact();
    }
  }

  void _cyclePriority() {
    setState(() {
      switch (_priority) {
        case TaskPriority.low:
          _priority = TaskPriority.medium;
          break;
        case TaskPriority.medium:
          _priority = TaskPriority.high;
          break;
        case TaskPriority.high:
          _priority = TaskPriority.low;
          break;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _showCategoryPicker(List<Category> categories, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                l10n.categories,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.clear_rounded),
                    title: Text(l10n.noCategory, style: GoogleFonts.outfit()),
                    onTap: () {
                      setState(() => _selectedCategoryId = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  ...categories.map(
                    (cat) => ListTile(
                      leading: Icon(
                        IconUtils.getIconData(cat.iconCode),
                        color: Color(cat.colorValue),
                      ),
                      title: Text(cat.name, style: GoogleFonts.outfit()),
                      trailing: _selectedCategoryId == cat.id
                          ? const Icon(Icons.check_rounded, color: Colors.green)
                          : null,
                      onTap: () {
                        setState(() => _selectedCategoryId = cat.id);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return const Color(0xFFFF5252);
      case TaskPriority.medium:
        return const Color(0xFFFFAB40);
      case TaskPriority.low:
        return const Color(0xFF69F0AE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final taskProvider = Provider.of<TaskProvider>(context);
    final categories = taskProvider.categories;

    Category? selectedCategory;
    if (_selectedCategoryId != null) {
      try {
        selectedCategory = categories.firstWhere(
          (c) => c.id == _selectedCategoryId,
        );
      } catch (_) {}
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle pill
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
                const SizedBox(height: 12),

                // Main Text Input Field
                TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Finish report tomorrow 3pm !high #work',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _submitTask(),
                ),

                // Live NLP Token Chip Bar
                if (_selectedDate != null ||
                    _selectedCategoryId != null ||
                    _priority != TaskPriority.medium) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_selectedDate != null) ...[
                          _buildTokenChip(
                            icon: Icons.calendar_today_rounded,
                            label: DateFormat.MMMd().add_jm().format(
                              _selectedDate!,
                            ),
                            color: theme.colorScheme.primary,
                            onClear: () => setState(() => _selectedDate = null),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (_selectedCategoryId != null &&
                            selectedCategory != null) ...[
                          _buildTokenChip(
                            icon: IconUtils.getIconData(
                              selectedCategory.iconCode,
                            ),
                            label: selectedCategory.name,
                            color: Color(selectedCategory.colorValue),
                            onClear: () =>
                                setState(() => _selectedCategoryId = null),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (_priority != TaskPriority.medium) ...[
                          _buildTokenChip(
                            icon: Icons.flag_rounded,
                            label: _priority.name.toUpperCase(),
                            color: _getPriorityColor(_priority),
                            onClear: () =>
                                setState(() => _priority = TaskPriority.medium),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Bottom Controls Row
                Row(
                  children: [
                    // Quick Date Preset: Today
                    _buildActionButton(
                      icon: Icons.today_rounded,
                      label: l10n.quickDateToday,
                      isSelected:
                          _selectedDate != null &&
                          DateUtils.isSameDay(_selectedDate, DateTime.now()),
                      onTap: () {
                        setState(() {
                          final now = DateTime.now();
                          _selectedDate = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            12,
                            0,
                          );
                        });
                        HapticFeedback.lightImpact();
                      },
                      theme: theme,
                    ),
                    const SizedBox(width: 6),

                    // Quick Date Preset: Tomorrow
                    _buildActionButton(
                      icon: Icons.wb_sunny_outlined,
                      label: l10n.quickDateTomorrow,
                      isSelected:
                          _selectedDate != null &&
                          DateUtils.isSameDay(
                            _selectedDate,
                            DateTime.now().add(const Duration(days: 1)),
                          ),
                      onTap: () {
                        setState(() {
                          final tom = DateTime.now().add(
                            const Duration(days: 1),
                          );
                          _selectedDate = DateTime(
                            tom.year,
                            tom.month,
                            tom.day,
                            12,
                            0,
                          );
                        });
                        HapticFeedback.lightImpact();
                      },
                      theme: theme,
                    ),
                    const SizedBox(width: 6),

                    // Date Picker Icon
                    IconButton(
                      icon: Icon(
                        Icons.event_available_rounded,
                        size: 20,
                        color: _selectedDate != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                      ),
                      tooltip: l10n.dueDateTime,
                      onPressed: _pickCustomDate,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),

                    // Priority Toggle
                    IconButton(
                      icon: Icon(
                        Icons.flag_rounded,
                        size: 20,
                        color: _getPriorityColor(_priority),
                      ),
                      tooltip: '${l10n.priority}: ${_priority.name}',
                      onPressed: _cyclePriority,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),

                    // Category Picker
                    IconButton(
                      icon: Icon(
                        selectedCategory != null
                            ? IconUtils.getIconData(selectedCategory.iconCode)
                            : Icons.label_outline_rounded,
                        size: 20,
                        color: selectedCategory != null
                            ? Color(selectedCategory.colorValue)
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                      ),
                      tooltip: l10n.categories,
                      onPressed: () => _showCategoryPicker(categories, l10n),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),

                    // More Options (Open Full AddTaskScreen)
                    IconButton(
                      icon: Icon(
                        Icons.open_in_full_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      tooltip: 'More options',
                      onPressed: _openFullAddTaskScreen,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),

                    const Spacer(),

                    // Submit / Create Task FAB Pill
                    Material(
                      color: theme.colorScheme.primary,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        onTap: _submitTask,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close_rounded, size: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
