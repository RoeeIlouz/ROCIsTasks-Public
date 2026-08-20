import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EasterEggSpinner extends StatefulWidget {
  final Widget child;
  final bool enableHaptic;

  const EasterEggSpinner({
    super.key,
    required this.child,
    this.enableHaptic = true,
  });

  @override
  State<EasterEggSpinner> createState() => _EasterEggSpinnerState();
}

class _EasterEggSpinnerState extends State<EasterEggSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerSpin() {
    if (!_controller.isAnimating) {
      if (widget.enableHaptic) {
        HapticFeedback.mediumImpact();
      }
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _triggerSpin,
      onDoubleTap: _triggerSpin,
      behavior: HitTestBehavior.opaque,
      child: RotationTransition(
        turns: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.elasticOut,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
