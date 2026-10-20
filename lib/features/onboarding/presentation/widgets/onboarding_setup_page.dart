import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/features/onboarding/data/services/starter_templates.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

/// Last onboarding page: a starter template, one-tap calendar import and a
/// home screen widget. Every step is optional.
class OnboardingSetupPage extends StatefulWidget {
  final String title;
  final String description;
  final Color accent;
  final StarterTemplate template;
  final ValueChanged<StarterTemplate> onTemplateChanged;

  const OnboardingSetupPage({
    super.key,
    required this.title,
    required this.description,
    required this.accent,
    required this.template,
    required this.onTemplateChanged,
  });

  @override
  State<OnboardingSetupPage> createState() => _OnboardingSetupPageState();
}

class _OnboardingSetupPageState extends State<OnboardingSetupPage> {
  bool _calendarConnected = false;
  bool _connecting = false;
  bool _canPinWidget = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      HomeWidget.isRequestPinWidgetSupported()
          .then((supported) {
            if (mounted) setState(() => _canPinWidget = supported ?? false);
          })
          .catchError((Object e) {
            AppLogger.warning('Pin widget check failed', error: e);
          });
    }
  }

  Future<void> _connectCalendar() async {
    setState(() => _connecting = true);
    var granted = false;
    try {
      granted = await Provider.of<CalendarProvider>(
        context,
        listen: false,
      ).requestPermissionsAndReload();
    } catch (e) {
      AppLogger.warning('Onboarding calendar import failed', error: e);
    }
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _calendarConnected = granted;
    });
  }

  Future<void> _pinWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        name: 'TaskWidgetProvider',
        androidName: 'TaskWidgetProvider',
      );
    } catch (e) {
      AppLogger.warning('Pin widget request failed', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final templates = {
      StarterTemplate.none: l10n.templateNone,
      StarterTemplate.student: l10n.templateStudent,
      StarterTemplate.grocery: l10n.templateGrocery,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.tune_rounded, size: 64, color: widget.accent),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.grey[400],
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.onboardingTemplateLabel,
            style: GoogleFonts.outfit(
              color: Colors.grey[300],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in templates.entries)
                _TemplatePill(
                  label: entry.value,
                  selected: widget.template == entry.key,
                  accent: widget.accent,
                  onTap: () => widget.onTemplateChanged(entry.key),
                ),
            ],
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 24),
            _ActionTile(
              icon: _calendarConnected
                  ? Icons.check_circle_rounded
                  : Icons.event_available_rounded,
              label: _calendarConnected
                  ? l10n.onboardingCalendarConnected
                  : l10n.onboardingImportCalendar,
              color: const Color(0xFF38BDF8),
              busy: _connecting,
              onTap: _calendarConnected || _connecting
                  ? null
                  : _connectCalendar,
            ),
          ],
          if (_canPinWidget) ...[
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.widgets_rounded,
              label: l10n.onboardingAddWidget,
              color: const Color(0xFF10B981),
              onTap: _pinWidget,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

/// Template choice. Not a ChoiceChip: the app's chip theme paints a light
/// surface that ignores per-chip colors, and onboarding is always dark.
class _TemplatePill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _TemplatePill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.06),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? accent : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check_rounded, size: 16, color: accent),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: selected ? Colors.white : Colors.grey[300],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
