import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rocis_tasks/shared/ui/widgets/celebration_particle_burst.dart';

/// A delightfully responsive circular checkbox with spring-physics bounce,
/// particle sparkles, and rich haptic sequences benchmarked against Amie & Things 3.
class BouncyCheckbox extends StatefulWidget {
  const BouncyCheckbox({
    super.key,
    required this.isChecked,
    required this.onTap,
    this.size = 26.0,
    this.activeColor = const Color(0xFF10B981),
    this.borderColor,
    this.checkColor = Colors.white,
    this.checkIcon = Icons.check,
    this.enableHaptics = true,
    this.enableSparkles = true,
    this.semanticsLabel,
  });

  /// Whether the checkbox is currently in the checked / completed state.
  final bool isChecked;

  /// Callback when user taps the checkbox.
  final VoidCallback onTap;

  /// Diameter of the checkbox circle.
  final double size;

  /// Background color when checked (defaults to emerald #10B981).
  final Color activeColor;

  /// Border color when unchecked.
  final Color? borderColor;

  /// Color of the checkmark icon.
  final Color checkColor;

  /// The checkmark icon data (defaults to Icons.check).
  final IconData checkIcon;

  /// Whether to fire tactile haptic feedback.
  final bool enableHaptics;

  /// Whether to trigger celebratory particle sparkles on completion.
  final bool enableSparkles;

  /// Accessibility semantics label.
  final String? semanticsLabel;

  @override
  State<BouncyCheckbox> createState() => _BouncyCheckboxState();
}

class _BouncyCheckboxState extends State<BouncyCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Spring scale: 1.0 -> 0.82 -> 1.18 -> 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.82,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.82,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.18,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _bounceController.forward(from: 0.0);

    if (widget.enableHaptics) {
      if (!widget.isChecked) {
        // Satisfying double-pulse haptic for completion
        HapticFeedback.heavyImpact();
        Future.delayed(
          const Duration(milliseconds: 55),
          HapticFeedback.lightImpact,
        );
      } else {
        HapticFeedback.lightImpact();
      }
    }

    if (!widget.isChecked && widget.enableSparkles) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final center = renderBox.localToGlobal(
          renderBox.size.center(Offset.zero),
        );
        CelebrationParticleBurst.triggerAt(
          context,
          center,
          primaryColor: widget.activeColor,
        );
      }
    }

    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        widget.borderColor ??
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);

    return Semantics(
      label: widget.semanticsLabel,
      checked: widget.isChecked,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) => Transform.scale(
              scale: _bounceController.isAnimating
                  ? _scaleAnimation.value
                  : 1.0,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.isChecked
                    ? widget.activeColor
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isChecked
                      ? Colors.transparent
                      : effectiveBorderColor,
                  width: 2,
                ),
                boxShadow: widget.isChecked
                    ? [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.isChecked
                    ? AnimatedScale(
                        scale: 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          widget.checkIcon,
                          size: widget.size * 0.62,
                          color: widget.checkColor,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
