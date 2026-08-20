import 'package:flutter/material.dart';
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
          // 1. Live Preview Section
          Text(
            'Live Preview',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
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

          // 4. Toggles & Behavior
          Text(
            'Behavior & Layout',
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
      border = Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1);
    }

    final todayColor = Color(int.parse(_highlightColor.replaceAll('#', '0xff')));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: previewBg,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: isGlass 
            ? [] 
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        children: [
          // Header Mock
          Row(
            children: [
              Text('❮', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  'July 2026',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Text('❯', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Text('⦿', style: TextStyle(color: todayColor, fontSize: 16)),
              const SizedBox(width: 12),
              Text('+', style: TextStyle(color: todayColor, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          // Filters Mock
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMockFilter('Tasks', _showTasks, textColor, theme),
              const SizedBox(width: 6),
              _buildMockFilter('Google', _showGoogle, textColor, theme),
            ],
          ),
          const SizedBox(height: 12),

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
                      style: TextStyle(color: dayColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),

          // Mini Calendar Grid Mock (1 row)
          Row(
            children: [
              if (_showWeekNumbers)
                Expanded(
                  child: Center(
                    child: Text('27', style: TextStyle(color: secondaryTextColor, fontSize: 11, fontStyle: FontStyle.italic)),
                  ),
                ),
              // Render 7 days in the mock row
              ...List.generate(7, (index) {
                final dayOfWeek = (_startOfWeek + index - 1) % 7 + 1;
                final dayNum = index + 1;
                final isToday = dayNum == 2; // Mock today is 2nd
                final isSelected = dayNum == 4; // Mock selected is 4th
                final isSun = dayOfWeek == 7;
                final isSat = dayOfWeek == 6;

                final Color dayTextColor;
                if (isToday || isSelected) {
                  dayTextColor = todayColor;
                } else if (_weekendHighlight && isSun) {
                  dayTextColor = Colors.redAccent;
                } else if (_weekendHighlight && isSat) {
                  dayTextColor = Colors.blueAccent;
                } else {
                  dayTextColor = textColor;
                }

                BoxDecoration? cellDec;
                if (isToday && isSelected) {
                  cellDec = BoxDecoration(
                    color: todayColor.withValues(alpha: 0.1),
                    border: Border.all(color: todayColor, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  );
                } else if (isSelected) {
                  cellDec = BoxDecoration(
                    border: Border.all(color: todayColor, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  );
                } else if (isToday) {
                  cellDec = BoxDecoration(
                    color: todayColor.withValues(alpha: 0.1),
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
                          style: TextStyle(color: dayTextColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
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
              setState(() {
                _highlightColor = c['hex'] as String;
              });
              _saveSetting('full_calendar_highlight_color', c['hex']);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: itemColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? (theme.brightness == Brightness.dark ? Colors.white : Colors.black87) 
                      : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected 
                    ? [
                        BoxShadow(
                          color: itemColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ] 
                    : [],
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
      },
      {
        'title': l10n.monthAgendaWidgetTitle,
        'subtitle': l10n.monthAgendaWidgetSubtitle,
        'icon': Icons.calendar_view_month_rounded,
        'tag': '4x4 / 4x3',
        'color': const Color(0xFF10B981),
      },
      {
        'title': l10n.timelineAgendaWidgetTitle,
        'subtitle': l10n.timelineAgendaWidgetSubtitle,
        'icon': Icons.timeline_rounded,
        'tag': '4x3 / 4x4',
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': l10n.quickActionWidgetTitle,
        'subtitle': l10n.quickActionWidgetSubtitle,
        'icon': Icons.add_task_rounded,
        'tag': '2x2',
        'color': const Color(0xFFEF4444),
      },
      {
        'title': l10n.upNextWidgetTitle,
        'subtitle': l10n.upNextWidgetSubtitle,
        'icon': Icons.play_arrow_rounded,
        'tag': '3x1 / 4x1',
        'color': const Color(0xFF06B6D4),
      },
      {
        'title': l10n.tasksWidgetTitle,
        'subtitle': l10n.tasksWidgetSubtitle,
        'icon': Icons.checklist_rounded,
        'tag': '4x3',
        'color': const Color(0xFFA855F7),
      },
    ];

    return Column(
      children: widgets.map((w) {
        final iconColor = w['color'] as Color;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
        );
      }).toList(),
    );
  }
}

