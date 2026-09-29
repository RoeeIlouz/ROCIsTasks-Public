import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class FabSpeedDialAction<T> {
  final T value;
  final IconData icon;
  final String label;

  const FabSpeedDialAction({
    required this.value,
    required this.icon,
    required this.label,
  });
}

/// Opens the speed dial over a dimmed backdrop, anchored to the FAB whose
/// [fabKey] is given. Returns the chosen action's value, or null if dismissed
/// (tap outside, the close button or Back).
Future<T?> showFabSpeedDial<T>({
  required BuildContext context,
  required GlobalKey fabKey,
  required List<FabSpeedDialAction<T>> actions,
  required bool useGlass,
}) {
  final box = fabKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Future.value();
  final anchor = box.localToGlobal(Offset.zero) & box.size;
  HapticFeedback.lightImpact();

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, _) => _FabSpeedDial<T>(
      anchor: anchor,
      actions: actions,
      useGlass: useGlass,
      animation: animation,
    ),
  );
}

class _FabSpeedDial<T> extends StatelessWidget {
  final Rect anchor;
  final List<FabSpeedDialAction<T>> actions;
  final bool useGlass;
  final Animation<double> animation;

  const _FabSpeedDial({
    required this.anchor,
    required this.actions,
    required this.useGlass,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return Stack(
      children: [
        Positioned(
          // Line the column's end edge up with the FAB (left in RTL).
          left: isRtl ? anchor.left : null,
          right: isRtl ? null : screen.width - anchor.right,
          bottom: screen.height - anchor.bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < actions.length; i++)
                _staggered(
                  curved,
                  // The option nearest the FAB appears first.
                  index: actions.length - 1 - i,
                  child: RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ActionPill<T>(
                        action: actions[i],
                        useGlass: useGlass,
                      ),
                    ),
                  ),
                ),
              // Covers the FAB exactly, so the FAB appears to turn into ✕.
              SizedBox(
                height: anchor.height,
                width: anchor.width,
                child: _roundButton(
                  theme,
                  icon: Icons.close_rounded,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  filled: true,
                  onTap: () => Navigator.pop(context),
                  rotation: curved,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _staggered(
    Animation<double> animation, {
    required int index,
    required Widget child,
  }) {
    final start = (index * 0.08).clamp(0.0, 0.3);
    final interval = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: interval,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(interval),
        child: child,
      ),
    );
  }

  Widget _roundButton(
    ThemeData theme, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool filled = false,
    Animation<double>? rotation,
  }) {
    final fg = useGlass || !filled
        ? theme.colorScheme.primary
        : theme.colorScheme.onPrimary;
    Widget iconWidget = Icon(icon, color: fg);
    if (rotation != null) {
      iconWidget = RotationTransition(
        turns: Tween(begin: -0.125, end: 0.0).animate(rotation),
        child: iconWidget,
      );
    }
    return Tooltip(
      message: tooltip,
      child: GlassContainer(
        blur: 0,
        borderRadius: BorderRadius.circular(16),
        elevation: 4.0,
        color: useGlass
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : (filled ? theme.colorScheme.primary : theme.colorScheme.surface),
        opacity: 0.92,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Center(child: iconWidget),
          ),
        ),
      ),
    );
  }
}

class _ActionPill<T> extends StatelessWidget {
  final FabSpeedDialAction<T> action;
  final bool useGlass;

  const _ActionPill({required this.action, required this.useGlass});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: GlassContainer(
        blur: 0,
        borderRadius: BorderRadius.circular(16),
        elevation: 3.0,
        color: useGlass
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHigh,
        opacity: 0.92,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, action.value);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.label,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(action.icon, size: 20, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
