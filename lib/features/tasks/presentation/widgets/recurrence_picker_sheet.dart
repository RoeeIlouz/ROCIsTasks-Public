import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/features/tasks/domain/services/task_recurrence_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class RecurrencePickerSheet extends StatefulWidget {
  final String? currentRule;

  const RecurrencePickerSheet({
    super.key,
    this.currentRule,
  });

  static Future<String?> show(BuildContext context, {String? currentRule}) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecurrencePickerSheet(currentRule: currentRule),
    );
  }

  @override
  State<RecurrencePickerSheet> createState() => _RecurrencePickerSheetState();
}

class _RecurrencePickerSheetState extends State<RecurrencePickerSheet> {
  late RecurrencePreset _selectedPreset;
  late RecurrenceFrequency _customFrequency;
  late int _customInterval;
  bool _isCustomMode = false;

  @override
  void initState() {
    super.initState();
    _selectedPreset = TaskRecurrenceService.getPresetFromRule(widget.currentRule);
    if (_selectedPreset == RecurrencePreset.custom) {
      _isCustomMode = true;
      final (freq, interval) = TaskRecurrenceService.parseCustomRule(widget.currentRule);
      _customFrequency = freq;
      _customInterval = interval;
    } else {
      _customFrequency = RecurrenceFrequency.daily;
      _customInterval = 1;
    }
  }

  void _selectPreset(RecurrencePreset preset) {
    HapticFeedback.lightImpact();
    if (preset == RecurrencePreset.custom) {
      setState(() {
        _selectedPreset = RecurrencePreset.custom;
        _isCustomMode = true;
      });
    } else {
      final rule = switch (preset) {
        RecurrencePreset.none => null,
        RecurrencePreset.daily => TaskRecurrenceService.rruleDaily,
        RecurrencePreset.weekdays => TaskRecurrenceService.rruleWeekdays,
        RecurrencePreset.weekly => TaskRecurrenceService.rruleWeekly,
        RecurrencePreset.monthly => TaskRecurrenceService.rruleMonthly,
        RecurrencePreset.yearly => TaskRecurrenceService.rruleYearly,
        RecurrencePreset.custom => null,
      };
      Navigator.pop(context, rule);
    }
  }

  void _applyCustom() {
    HapticFeedback.mediumImpact();
    final rule = TaskRecurrenceService.buildCustomRule(
      frequency: _customFrequency,
      interval: _customInterval,
    );
    Navigator.pop(context, rule);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isCustomMode ? l10n.customRecurrence : l10n.selectRecurrence,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (_isCustomMode)
                    TextButton(
                      onPressed: () {
                        setState(() => _isCustomMode = false);
                      },
                      child: Text(
                        l10n.cancel,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isCustomMode) ...[
                _buildPresetTile(
                  context,
                  preset: RecurrencePreset.none,
                  title: l10n.repeatNone,
                  icon: Icons.block_rounded,
                  isSelected: _selectedPreset == RecurrencePreset.none,
                ),
                _buildPresetTile(
                  context,
                  preset: RecurrencePreset.daily,
                  title: l10n.repeatDaily,
                  icon: Icons.today_rounded,
                  isSelected: _selectedPreset == RecurrencePreset.daily,
                ),
                _buildPresetTile(
                  context,
                  preset: RecurrencePreset.weekdays,
                  title: l10n.repeatWeekdays,
                  icon: Icons.calendar_view_week_rounded,
                  isSelected: _selectedPreset == RecurrencePreset.weekdays,
                ),
                _buildPresetTile(
                  context,
                  preset: RecurrencePreset.weekly,
                  title: l10n.repeatWeekly,
                  icon: Icons.date_range_rounded,
                  isSelected: _selectedPreset == RecurrencePreset.weekly,
                ),
                _buildPresetTile(
                  context,
                  preset: RecurrencePreset.monthly,
                  title: l10n.repeatMonthly,
                  icon: Icons.calendar_month_rounded,
                  isSelected: _selectedPreset == RecurrencePreset.monthly,
                ),
                _buildPresetTile(
                  context,
                  preset: RecurrencePreset.yearly,
                  title: l10n.repeatYearly,
                  icon: Icons.event_repeat_rounded,
                  isSelected: _selectedPreset == RecurrencePreset.yearly,
                ),
                _buildPresetTile(
                  context,
                  preset: RecurrencePreset.custom,
                  title: l10n.repeatCustom,
                  icon: Icons.tune_rounded,
                  isSelected: _selectedPreset == RecurrencePreset.custom,
                ),
              ] else ...[
                _buildCustomControls(context, l10n, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetTile(
    BuildContext context, {
    required RecurrencePreset preset,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => _selectPreset(preset),
        borderRadius: BorderRadius.circular(16),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: isSelected ? primaryColor.withValues(alpha: 0.12) : null,
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? primaryColor : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? primaryColor : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomControls(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final primaryColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassContainer(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.repeatsEvery,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        onPressed: _customInterval > 1
                            ? () {
                                HapticFeedback.lightImpact();
                                setState(() => _customInterval--);
                              }
                            : null,
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$_customInterval',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        onPressed: _customInterval < 99
                            ? () {
                                HapticFeedback.lightImpact();
                                setState(() => _customInterval++);
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<RecurrenceFrequency>(
                segments: [
                  ButtonSegment(
                    value: RecurrenceFrequency.daily,
                    label: Text(
                      _customInterval == 1 ? l10n.daySingular : l10n.daysPlural,
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                  ),
                  ButtonSegment(
                    value: RecurrenceFrequency.weekly,
                    label: Text(
                      _customInterval == 1 ? l10n.weekSingular : l10n.weeksPlural,
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                  ),
                  ButtonSegment(
                    value: RecurrenceFrequency.monthly,
                    label: Text(
                      _customInterval == 1 ? l10n.monthSingular : l10n.monthsPlural,
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                  ),
                  ButtonSegment(
                    value: RecurrenceFrequency.yearly,
                    label: Text(
                      _customInterval == 1 ? l10n.yearSingular : l10n.yearsPlural,
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                  ),
                ],
                selected: {_customFrequency},
                onSelectionChanged: (newSelection) {
                  HapticFeedback.lightImpact();
                  setState(() => _customFrequency = newSelection.first);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _applyCustom,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            l10n.save,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
