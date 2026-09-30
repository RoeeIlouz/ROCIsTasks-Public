import 'package:flutter/gestures.dart' show kDoubleTapSlop, kDoubleTapTimeout;
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
  Duration? _lastUpTime;
  Offset? _lastUpPosition;

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

  // Double taps are read from raw pointer events: an onDoubleTap recognizer
  // holds the gesture arena for kDoubleTapTimeout after every tap, which
  // delayed the child's own onTap (e.g. the FAB) by ~300ms.
  void _handlePointerUp(PointerUpEvent event) {
    final lastTime = _lastUpTime;
    final lastPosition = _lastUpPosition;
    if (lastTime != null &&
        lastPosition != null &&
        event.timeStamp - lastTime <= kDoubleTapTimeout &&
        (event.position - lastPosition).distance <= kDoubleTapSlop) {
      _lastUpTime = null;
      _lastUpPosition = null;
      _triggerSpin();
      return;
    }
    _lastUpTime = event.timeStamp;
    _lastUpPosition = event.position;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: _handlePointerUp,
      child: GestureDetector(
        onLongPress: _triggerSpin,
        behavior: HitTestBehavior.opaque,
        child: RotationTransition(
          turns: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
