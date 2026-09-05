import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

/// Reusable modal sheet providing curated preset swatches and an expandable
/// custom color picker with Hue, Saturation, Value, and Opacity sliders,
/// plus a direct HEX code input field.
class AppColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final String? title;
  final VoidCallback? onResetToDefault;
  final String? resetLabel;
  final List<Color>? presetColors;

  const AppColorPickerSheet({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.title,
    this.onResetToDefault,
    this.resetLabel,
    this.presetColors,
  });

  /// Static helper to display the sheet in a bottom sheet modal
  static Future<Color?> show({
    required BuildContext context,
    required Color initialColor,
    ValueChanged<Color>? onColorChanged,
    String? title,
    VoidCallback? onResetToDefault,
    String? resetLabel,
    List<Color>? presetColors,
  }) {
    Color selected = initialColor;
    return showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => AppColorPickerSheet(
        initialColor: initialColor,
        title: title,
        onResetToDefault: onResetToDefault != null
            ? () {
                onResetToDefault();
                Navigator.of(ctx).pop();
              }
            : null,
        resetLabel: resetLabel,
        presetColors: presetColors,
        onColorChanged: (c) {
          selected = c;
          onColorChanged?.call(c);
        },
      ),
    ).then((_) => selected);
  }

  @override
  State<AppColorPickerSheet> createState() => _AppColorPickerSheetState();
}

class _AppColorPickerSheetState extends State<AppColorPickerSheet> {
  late HSVColor _currentHsv;
  late double _opacity;
  late TextEditingController _hexController;
  bool _isCustomExpanded = false;

  static const List<Color> defaultPresets = [
    Color(0xFF4285F4), // Google Blue
    Color(0xFF039BE5), // Light Blue
    Color(0xFF009688), // Teal
    Color(0xFF0B8043), // Google Green
    Color(0xFF33B679), // Sage Green
    Color(0xFF7CB342), // Olive Green
    Color(0xFFF6BF26), // Yellow
    Color(0xFFF4511E), // Orange / Tangerine
    Color(0xFFE67C73), // Flamingo Pink
    Color(0xFFD50000), // Tomato Red
    Color(0xFF8E24AA), // Purple / Grape
    Color(0xFF7986CB), // Lavender
    Color(0xFF3F51B5), // Indigo
    Color(0xFF616161), // Graphite / Gray
    Color(0xFF8D6E63), // Brown
    Color(0xFF00ACC1), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF6366F1), // Indigo ROCIs
    Color(0xFFEC4899), // Pink
  ];

  @override
  void initState() {
    super.initState();
    final col = widget.initialColor;
    _currentHsv = HSVColor.fromColor(col.withValues(alpha: 1.0));
    _opacity = col.a.clamp(0.2, 1.0);
    _hexController = TextEditingController(text: _formatHex(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor {
    return _currentHsv.toColor().withValues(alpha: _opacity);
  }

  String _formatHex(Color c) {
    final int argb = c.toARGB32();
    if (_opacity < 0.999) {
      return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    }
    return '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _updateColor(Color newColor, {bool updateText = true}) {
    setState(() {
      _currentHsv = HSVColor.fromColor(newColor.withValues(alpha: 1.0));
      _opacity = newColor.a.clamp(0.2, 1.0);
      if (updateText) {
        _hexController.text = _formatHex(_currentColor);
      }
    });
    widget.onColorChanged(_currentColor);
  }

  void _onHexChanged(String input) {
    String clean = input.trim().replaceAll('#', '');
    if (clean.length == 6) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) {
        final color = Color(0xFF000000 | val).withValues(alpha: _opacity);
        _updateColor(color, updateText: false);
      }
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) {
        final fullColor = Color(val);
        _updateColor(fullColor, updateText: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final presets = widget.presetColors ?? defaultPresets;

    return GlassContainer(
      opacity: 0.95,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Title & optional Reset Button
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title ?? l10n.selectColor,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onResetToDefault != null)
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onResetToDefault!();
                    },
                    icon: const Icon(Icons.restore, size: 18),
                    label: Text(widget.resetLabel ?? l10n.resetColors),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Color Preview Card with Hex & Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _currentColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Swatch
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _currentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // HEX text / information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatHex(_currentColor),
                          style: GoogleFonts.firaCode(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${l10n.opacity}: ${(_opacity * 100).round()}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Toggle Button between Presets & Custom Sliders
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isCustomExpanded = !_isCustomExpanded;
                      });
                    },
                    icon: Icon(
                      _isCustomExpanded
                          ? Icons.grid_view_rounded
                          : Icons.tune_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _isCustomExpanded
                          ? l10n.presets
                          : l10n.expandCustomPicker,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Mode 1: Presets Grid
            if (!_isCustomExpanded) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: presets.map((color) {
                  final isSelected =
                      _currentColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _updateColor(color);
                    },
                    child: Semantics(
                      label: 'Color ${_formatHex(color)}',
                      selected: isSelected,
                      button: true,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.2,
                                  ),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(
                                alpha: isSelected ? 0.4 : 0.15,
                              ),
                              blurRadius: isSelected ? 8 : 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                size: 22,
                                color: color.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Mode 2: Custom Sliders & Direct HEX Input
            if (_isCustomExpanded) ...[
              // Hue Slider
              _buildSliderLabel(context, 'Hue', '${_currentHsv.hue.round()}°'),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: _currentHsv.hue,
                    min: 0,
                    max: 360,
                    onChanged: (val) {
                      setState(() {
                        _currentHsv = _currentHsv.withHue(val);
                        _hexController.text = _formatHex(_currentColor);
                      });
                      widget.onColorChanged(_currentColor);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Saturation Slider
              _buildSliderLabel(
                context,
                'Saturation',
                '${(_currentHsv.saturation * 100).round()}%',
              ),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      HSVColor.fromAHSV(
                        1.0,
                        _currentHsv.hue,
                        1.0,
                        _currentHsv.value,
                      ).toColor(),
                    ],
                  ),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: _currentHsv.saturation,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) {
                      setState(() {
                        _currentHsv = _currentHsv.withSaturation(val);
                        _hexController.text = _formatHex(_currentColor);
                      });
                      widget.onColorChanged(_currentColor);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Value / Brightness Slider
              _buildSliderLabel(
                context,
                'Brightness',
                '${(_currentHsv.value * 100).round()}%',
              ),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black,
                      HSVColor.fromAHSV(
                        1.0,
                        _currentHsv.hue,
                        _currentHsv.saturation,
                        1.0,
                      ).toColor(),
                    ],
                  ),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: _currentHsv.value,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) {
                      setState(() {
                        _currentHsv = _currentHsv.withValue(val);
                        _hexController.text = _formatHex(_currentColor);
                      });
                      widget.onColorChanged(_currentColor);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Opacity Slider (bounded 20% to 100% per user spec 1.1)
              _buildSliderLabel(
                context,
                l10n.opacity,
                '${(_opacity * 100).round()}%',
              ),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      _currentHsv.toColor().withValues(alpha: 0.2),
                      _currentHsv.toColor().withValues(alpha: 1.0),
                    ],
                  ),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: _opacity,
                    min: 0.2,
                    max: 1.0,
                    onChanged: (val) {
                      setState(() {
                        _opacity = val;
                        _hexController.text = _formatHex(_currentColor);
                      });
                      widget.onColorChanged(_currentColor);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Direct HEX text input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      decoration: InputDecoration(
                        labelText: l10n.hexCode,
                        hintText: '#4285F4',
                        prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      style: GoogleFonts.firaCode(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(9)],
                      onChanged: _onHexChanged,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Done Button
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop(_currentColor);
              },
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(l10n.done),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderLabel(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
