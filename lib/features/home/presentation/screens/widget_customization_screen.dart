import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class WidgetCustomizationScreen extends StatefulWidget {
  const WidgetCustomizationScreen({super.key});

  @override
  State<WidgetCustomizationScreen> createState() => _WidgetCustomizationScreenState();
}

class _WidgetCustomizationScreenState extends State<WidgetCustomizationScreen> {
  bool _showWeekNumbers = true;
  bool _weekendHighlight = true;
  String _widgetTheme = 'system';
  bool _showTasks = true;
  bool _showGoogle = true;
  int _startOfWeek = 7;
  String _highlightColor = '#6C63FF';
  bool _isLoading = true;
  int _selectedPreviewIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showWeekNumbers = prefs.getBool('full_calendar_show_week_numbers') ?? true;
        _weekendHighlight = prefs.getBool('full_calendar_weekend_highlight') ?? true;
        _widgetTheme = prefs.getString('full_calendar_theme') ?? 'system';
        _showTasks = prefs.getBool('full_calendar_show_tasks') ?? true;
        _showGoogle = prefs.getBool('full_calendar_show_google') ?? true;
        _startOfWeek = prefs.getInt('full_calendar_start_of_week') ?? 7;
        _highlightColor = prefs.getString('full_calendar_highlight_color') ?? '#6C63FF';
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
        await HomeWidget.saveWidgetData<bool>(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
        await HomeWidget.saveWidgetData<String>(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
        await HomeWidget.saveWidgetData<int>(key, value);
      }

      // Update widget dynamically
      if (mounted) {
        final service = Provider.of<FullCalendarWidgetService>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        await service.updateFullCalendarWidget(userId: authService.currentUser?.uid);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.widgetSettings)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Determine current theme settings for the live preview
    final isDark = _widgetTheme == 'dark' || 
        (_widgetTheme == 'system' && theme.brightness == Brightness.dark);
    final isGlass = _widgetTheme == 'glassmorphic';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.widgetSettings),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // 1. Live Preview Section & Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Widget Preview',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getWidgetTag(_selectedPreviewIndex),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildWidgetSwitcher(theme, l10n),
          const SizedBox(height: 12),
          _buildLivePreview(theme, isDark, isGlass),
          const SizedBox(height: 24),

          // 2. Theme Selection
          Text(
            l10n.widgetTheme,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildThemeSelector(theme, themeService),
          const SizedBox(height: 24),

          // 3. Accent Color Selection
          Text(
            l10n.widgetAccentColor,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildColorPicker(theme),
          const SizedBox(height: 24),

          // 4. Toggles & Behavior (Active for Calendar widgets)
          Text(
            'Calendar Widget Behavior',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTogglesCard(theme, l10n),
          const SizedBox(height: 24),

          // 5. Available Home Widgets Gallery
          Text(
            l10n.widgetSuiteTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.widgetSuiteSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          _buildWidgetSuiteSection(theme, l10n),
        ],
      ),
    );
  }

  String _getWidgetTag(int index) {
    switch (index) {
      case 0:
        return '4x4 Full Calendar';
      case 1:
        return '4x3 Day Agenda';
      case 2:
        return '4x4 Month & Agenda';
      case 3:
        return '4x3 Timeline';
      case 4:
        return '2x2 Quick Actions';
      case 5:
        return '3x1 Up Next Pill';
      default:
        return 'Widget';
    }
  }

  Widget _buildWidgetSwitcher(ThemeData theme, AppLocalizations l10n) {
    final tabs = [
      {'icon': Icons.calendar_month_rounded, 'name': 'Calendar'},
      {'icon': Icons.view_agenda_rounded, 'name': 'Day Agenda'},
      {'icon': Icons.calendar_view_month_rounded, 'name': 'Month & List'},
      {'icon': Icons.timeline_rounded, 'name': 'Timeline'},
      {'icon': Icons.add_task_rounded, 'name': 'Quick Actions'},
      {'icon': Icons.play_arrow_rounded, 'name': 'Up Next'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _selectedPreviewIndex == i;
          final item = tabs[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedPreviewIndex = i;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item['name'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLivePreview(ThemeData theme, bool isDark, bool isGlass) {
    // Style configuration based on selected theme
    final Color previewBg;
    final Color textColor;
    final Color secondaryTextColor;
    final BoxBorder? border;

    if (isGlass) {
      previewBg = isDark ? const Color(0xB31A1A1A) : const Color(0xB3FFFFFF);
      textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
      secondaryTextColor = isDark ? const Color(0xFFAEAEB2) : const Color(0xFF8E8E93);
      border = Border.all(color: Colors.white24, width: 1);
    } else if (isDark) {
      previewBg = const Color(0xFF121212);
      textColor = Colors.white;
      secondaryTextColor = const Color(0xFFAEAEB2);
      border = null;
    } else {
      previewBg = const Color(0xFFFFFFFF);
      textColor = const Color(0xFF1C1C1E);
      secondaryTextColor = const Color(0xFF8E8E93);
      border = Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1);
    }

    final accentColor = Color(int.parse(_highlightColor.replaceAll('#', '0xff')));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: previewBg,
        borderRadius: BorderRadius.circular(18),
        border: border,
        boxShadow: isGlass 
            ? [] 
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: _buildSelectedWidgetMock(theme, textColor, secondaryTextColor, accentColor),
    );
  }

  Widget _buildSelectedWidgetMock(ThemeData theme, Color textColor, Color secondaryTextColor, Color accentColor) {
    switch (_selectedPreviewIndex) {
      case 0:
        return _buildFullCalendarMock(theme, textColor, secondaryTextColor, accentColor);
      case 1:
        return _buildDayAgendaMock(theme, textColor, secondaryTextColor, accentColor);
      case 2:
        return _buildMonthAgendaMock(theme, textColor, secondaryTextColor, accentColor);
      case 3:
        return _buildTimelineMock(theme, textColor, secondaryTextColor, accentColor);
      case 4:
        return _buildQuickActionsMock(theme, textColor, secondaryTextColor, accentColor);
      case 5:
        return _buildUpNextMock(theme, textColor, secondaryTextColor, accentColor);
      default:
        return _buildFullCalendarMock(theme, textColor, secondaryTextColor, accentColor);
    }
  }

  Widget _buildFullCalendarMock(ThemeData theme, Color textColor, Color secondaryTextColor, Color accentColor) {
    return Column(
      children: [
        // Header Mock
        Row(
          children: [
            Text('❮', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            Expanded(
              child: Text(
                'August 2026',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            Text('❯', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 10),
            Text('⦿', style: TextStyle(color: accentColor, fontSize: 15)),
            const SizedBox(width: 10),
            Text('+', style: TextStyle(color: accentColor, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),

        // Filters Mock
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMockFilter('Tasks', _showTasks, textColor, theme),
            const SizedBox(width: 6),
            _buildMockFilter('Google', _showGoogle, textColor, theme),
          ],
        ),
        const SizedBox(height: 10),

        // Weekdays Header Mock
        Row(
          children: [
            if (_showWeekNumbers)
              Expanded(
                child: Center(
                  child: Text('#', style: TextStyle(color: secondaryTextColor, fontSize: 11, fontStyle: FontStyle.italic)),
                ),
              ),
            ...List.generate(7, (index) {
              final dayOfWeek = (_startOfWeek + index - 1) % 7 + 1;
              final dayLetter = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][dayOfWeek - 1];
              final Color dayColor;
              if (_weekendHighlight) {
                if (dayOfWeek == 7) {
                  dayColor = Colors.redAccent;
                } else if (dayOfWeek == 6) {
                  dayColor = Colors.blueAccent;
                } else {
                  dayColor = textColor;
                }
              } else {
                dayColor = textColor;
              }

              return Expanded(
                child: Center(
                  child: Text(
                    dayLetter,
                    style: TextStyle(color: dayColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 6),

        // Mini Calendar Grid Mock (1 row)
        Row(
          children: [
            if (_showWeekNumbers)
              Expanded(
                child: Center(
                  child: Text('34', style: TextStyle(color: secondaryTextColor, fontSize: 11, fontStyle: FontStyle.italic)),
                ),
              ),
            ...List.generate(7, (index) {
              final dayOfWeek = (_startOfWeek + index - 1) % 7 + 1;
              final dayNum = 17 + index;
              final isToday = dayNum == 21;
              final isSelected = dayNum == 21;
              final isSun = dayOfWeek == 7;
              final isSat = dayOfWeek == 6;

              final Color dayTextColor;
              if (isToday || isSelected) {
                dayTextColor = accentColor;
              } else if (_weekendHighlight && isSun) {
                dayTextColor = Colors.redAccent;
              } else if (_weekendHighlight && isSat) {
                dayTextColor = Colors.blueAccent;
              } else {
                dayTextColor = textColor;
              }

              BoxDecoration? cellDec;
              if (isToday) {
                cellDec = BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  border: Border.all(color: accentColor, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                );
              }

              return Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: cellDec,
                    child: Center(
                      child: Text(
                        '$dayNum',
                        style: TextStyle(color: dayTextColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildDayAgendaMock(ThemeData theme, Color textColor, Color secondaryTextColor, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('❮', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Friday, Aug 21',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Today · 3 tasks remaining',
                    style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Text('❯', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, size: 16, color: accentColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildAgendaRowMock('Design Review & Handoff', '10:00 AM', accentColor, textColor, secondaryTextColor, isDone: false),
        const SizedBox(height: 6),
        _buildAgendaRowMock('Update Flutter Dependencies', '02:30 PM', const Color(0xFF10B981), textColor, secondaryTextColor, isDone: true),
      ],
    );
  }

  Widget _buildMonthAgendaMock(ThemeData theme, Color textColor, Color secondaryTextColor, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left mini month
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Text('August 2026', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => Text(d, style: TextStyle(fontSize: 9, color: secondaryTextColor, fontWeight: FontWeight.bold))).toList(),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [17, 18, 19, 20, 21, 22, 23].map((d) {
                  final isToday = d == 21;
                  return Container(
                    padding: const EdgeInsets.all(2),
                    decoration: isToday ? BoxDecoration(color: accentColor, shape: BoxShape.circle) : null,
                    child: Text('$d', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isToday ? Colors.white : textColor)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(width: 1, height: 60, color: secondaryTextColor.withValues(alpha: 0.2)),
        const SizedBox(width: 10),
        // Right side agenda
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Agenda (21st)', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 4),
              _buildAgendaRowMock('Sprint Planning', '09:00 AM', accentColor, textColor, secondaryTextColor, isDone: false, compact: true),
              const SizedBox(height: 4),
              _buildAgendaRowMock('Grocery Shopping', '06:00 PM', const Color(0xFFF59E0B), textColor, secondaryTextColor, isDone: false, compact: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineMock(ThemeData theme, Color textColor, Color secondaryTextColor, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'TODAY · Fri, Aug 21',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildTimelineRowMock('09:00 AM', 'Daily Standup Call', 'Google Meet · Team', accentColor, textColor, secondaryTextColor),
        const SizedBox(height: 6),
        _buildTimelineRowMock('11:30 AM', 'Prepare Release v0.2.9', 'Product Tasks', const Color(0xFF10B981), textColor, secondaryTextColor),
      ],
    );
  }

  Widget _buildQuickActionsMock(ThemeData theme, Color textColor, Color secondaryTextColor, Color accentColor) {
    final actions = [
      {'icon': Icons.add_task_rounded, 'label': 'New Task', 'color': accentColor},
      {'icon': Icons.shopping_basket_rounded, 'label': 'Grocery', 'color': const Color(0xFF10B981)},
      {'icon': Icons.calendar_month_rounded, 'label': 'Calendar', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.lock_outline_rounded, 'label': 'Private', 'color': const Color(0xFFEF4444)},
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Launch', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            Text('09:41 AM', style: TextStyle(color: secondaryTextColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: actions.map((a) {
            final aColor = a['color'] as Color;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: aColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: aColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Icon(a['icon'] as IconData, size: 18, color: aColor),
                    const SizedBox(height: 3),
                    Text(
                      a['label'] as String,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUpNextMock(ThemeData theme, Color textColor, Color secondaryTextColor, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.check_circle_outline_rounded, color: accentColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next: Product Launch Review',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Starts in 25 min · 11:00 AM',
                style: TextStyle(color: secondaryTextColor, fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Up Next',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildAgendaRowMock(String title, String time, Color tagColor, Color textColor, Color secondaryTextColor, {required bool isDone, bool compact = false}) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: compact ? 14 : 18,
          color: isDone ? tagColor : secondaryTextColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: isDone ? secondaryTextColor : textColor,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              decoration: isDone ? TextDecoration.lineThrough : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          time,
          style: TextStyle(color: secondaryTextColor, fontSize: compact ? 9 : 10),
        ),
      ],
    );
  }

  Widget _buildTimelineRowMock(String time, String title, String subtitle, Color tagColor, Color textColor, Color secondaryTextColor) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            time,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: secondaryTextColor),
          ),
        ),
        Container(
          width: 3,
          height: 28,
          decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1),
              Text(subtitle, style: TextStyle(color: secondaryTextColor, fontSize: 9), maxLines: 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMockFilter(String text, bool active, Color textColor, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: active ? theme.colorScheme.primary : textColor.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? theme.colorScheme.primary : textColor.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeData theme, ThemeService themeService) {
    final l10n = AppLocalizations.of(context)!;
    final themes = [
      {'id': 'system', 'label': l10n.widgetThemeSystem, 'icon': Icons.brightness_auto},
      {'id': 'light', 'label': l10n.widgetThemeLight, 'icon': Icons.light_mode},
      {'id': 'dark', 'label': l10n.widgetThemeDark, 'icon': Icons.dark_mode},
      {'id': 'glassmorphic', 'label': l10n.widgetThemeGlassmorphic, 'icon': Icons.blur_on},
    ];

    return GlassContainer(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double itemWidth = (constraints.maxWidth - 24) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: themes.map((t) {
              final isSel = _widgetTheme == t['id'];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _widgetTheme = t['id'] as String;
                  });
                  _saveSetting('full_calendar_theme', t['id']);
                },
                child: Container(
                  width: itemWidth,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSel ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(
                      color: isSel ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        t['icon'] as IconData,
                        color: isSel ? theme.colorScheme.primary : theme.iconTheme.color?.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t['label'] as String,
                          style: TextStyle(
                            color: isSel ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildColorPicker(ThemeData theme) {
    final colors = [
      {'hex': '#6C63FF', 'name': 'Indigo', 'color': const Color(0xFF6C63FF)},
      {'hex': '#10B981', 'name': 'Emerald', 'color': const Color(0xFF10B981)},
      {'hex': '#F59E0B', 'name': 'Orange', 'color': const Color(0xFFF59E0B)},
      {'hex': '#EF4444', 'name': 'Red', 'color': const Color(0xFFEF4444)},
      {'hex': '#06B6D4', 'name': 'Cyan', 'color': const Color(0xFF06B6D4)},
      {'hex': '#A855F7', 'name': 'Purple', 'color': const Color(0xFFA855F7)},
    ];

    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: colors.map((c) {
          final isSelected = _highlightColor.toLowerCase() == (c['hex'] as String).toLowerCase();
          final itemColor = c['color'] as Color;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _highlightColor = c['hex'] as String;
              });
              _saveSetting('full_calendar_highlight_color', c['hex']);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: itemColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: itemColor.withValues(alpha: isSelected ? 0.6 : 0.2),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTogglesCard(ThemeData theme, AppLocalizations l10n) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Show Week Numbers
          SwitchListTile(
            secondary: Icon(Icons.format_list_numbered, color: theme.colorScheme.primary),
            title: Text(l10n.showWeekNumbers),
            value: _showWeekNumbers,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() {
                _showWeekNumbers = val;
              });
              _saveSetting('full_calendar_show_week_numbers', val);
            },
          ),
          const Divider(height: 1),

          // Highlight Weekends
          SwitchListTile(
            secondary: Icon(Icons.date_range, color: theme.colorScheme.primary),
            title: Text(l10n.weekendHighlights),
            value: _weekendHighlight,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() {
                _weekendHighlight = val;
              });
              _saveSetting('full_calendar_weekend_highlight', val);
            },
          ),
          const Divider(height: 1),

          // Show Tasks
          SwitchListTile(
            secondary: Icon(Icons.check_box_outlined, color: theme.colorScheme.primary),
            title: Text(l10n.showCalendarTasks),
            value: _showTasks,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() {
                _showTasks = val;
              });
              _saveSetting('full_calendar_show_tasks', val);
            },
          ),
          const Divider(height: 1),

          // Show Google Calendar
          SwitchListTile(
            secondary: Icon(Icons.calendar_month, color: theme.colorScheme.primary),
            title: Text(l10n.showGoogleCalendar),
            value: _showGoogle,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() {
                _showGoogle = val;
              });
              _saveSetting('full_calendar_show_google', val);
            },
          ),
          const Divider(height: 1),

          // Start of Week Dropdown
          ListTile(
            leading: Icon(Icons.first_page_rounded, color: theme.colorScheme.primary),
            title: Text(l10n.startOfWeek),
            trailing: DropdownButton<int>(
              value: _startOfWeek,
              dropdownColor: theme.colorScheme.surfaceContainerLow,
              underline: const SizedBox(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
              items: [
                DropdownMenuItem(value: 7, child: Text(l10n.sunday)),
                DropdownMenuItem(value: 1, child: Text(l10n.monday)),
                DropdownMenuItem(value: 6, child: Text(l10n.saturday)),
              ],
              onChanged: (val) {
                if (val != null) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _startOfWeek = val;
                  });
                  _saveSetting('full_calendar_start_of_week', val);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetSuiteSection(ThemeData theme, AppLocalizations l10n) {
    final widgets = [
      {
        'title': l10n.todayAgendaWidgetTitle,
        'subtitle': l10n.todayAgendaWidgetSubtitle,
        'icon': Icons.view_agenda_rounded,
        'tag': '4x3 / 4x2',
        'color': const Color(0xFF6C63FF),
        'previewIndex': 1,
      },
      {
        'title': l10n.monthAgendaWidgetTitle,
        'subtitle': l10n.monthAgendaWidgetSubtitle,
        'icon': Icons.calendar_view_month_rounded,
        'tag': '4x4 / 4x3',
        'color': const Color(0xFF10B981),
        'previewIndex': 2,
      },
      {
        'title': l10n.timelineAgendaWidgetTitle,
        'subtitle': l10n.timelineAgendaWidgetSubtitle,
        'icon': Icons.timeline_rounded,
        'tag': '4x3 / 4x4',
        'color': const Color(0xFFF59E0B),
        'previewIndex': 3,
      },
      {
        'title': l10n.quickActionWidgetTitle,
        'subtitle': l10n.quickActionWidgetSubtitle,
        'icon': Icons.add_task_rounded,
        'tag': '2x2',
        'color': const Color(0xFFEF4444),
        'previewIndex': 4,
      },
      {
        'title': l10n.upNextWidgetTitle,
        'subtitle': l10n.upNextWidgetSubtitle,
        'icon': Icons.play_arrow_rounded,
        'tag': '3x1 / 4x1',
        'color': const Color(0xFF06B6D4),
        'previewIndex': 5,
      },
      {
        'title': l10n.tasksWidgetTitle,
        'subtitle': l10n.tasksWidgetSubtitle,
        'icon': Icons.checklist_rounded,
        'tag': '4x3',
        'color': const Color(0xFFA855F7),
        'previewIndex': 0,
      },
    ];

    return Column(
      children: widgets.map((w) {
        final iconColor = w['color'] as Color;
        final previewIndex = w['previewIndex'] as int;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedPreviewIndex = previewIndex;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: GlassContainer(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      w['icon'] as IconData,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                w['title'] as String,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                w['tag'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          w['subtitle'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
