import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A lightweight, high-performance particle sparkle burst widget that renders
/// a radiant burst of sparkles on a hardware-accelerated canvas.
///
/// Can be triggered anywhere using the static helper [triggerAt], or embedded
/// directly in the widget tree.
class CelebrationParticleBurst extends StatefulWidget {
  const CelebrationParticleBurst({
    super.key,
    required this.center,
    this.primaryColor,
    this.onCompleted,
    this.particleCount = 12,
  });

  /// The center point in local coordinates where particles radiate from.
  final Offset center;

  /// Primary color of the burst. Defaults to emerald green (#10B981) + amber accents.
  final Color? primaryColor;

  /// Callback when the particle animation finishes.
  final VoidCallback? onCompleted;

  /// Number of particles to spawn.
  final int particleCount;

  /// Triggers a celebratory particle burst at [globalCenter] inside the current [Overlay].
  static void triggerAt(
    BuildContext context,
    Offset globalCenter, {
    Color? primaryColor,
    int particleCount = 14,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(
              child: CelebrationParticleBurst(
                center: globalCenter,
                primaryColor: primaryColor,
                particleCount: particleCount,
                onCompleted: () {
                  if (entry.mounted) {
                    entry.remove();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<CelebrationParticleBurst> createState() =>
      _CelebrationParticleBurstState();
}

class _CelebrationParticleBurstState extends State<CelebrationParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_BurstParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _initParticles();

    _controller.forward().then((_) {
      if (mounted) {
        widget.onCompleted?.call();
      }
    });
  }

  void _initParticles() {
    final random = math.Random();
    final baseColor = widget.primaryColor ?? const Color(0xFF10B981);
    final accentColors = [
      baseColor,
      const Color(0xFFF59E0B), // Amber gold
      const Color(0xFF34D399), // Emerald light
      const Color(0xFF60A5FA), // Blue accent
      Colors.white,
    ];

    _particles = List.generate(widget.particleCount, (i) {
      // Distribute evenly around circle with slight jitter
      final baseAngle = (i / widget.particleCount) * 2 * math.pi;
      final angle = baseAngle + (random.nextDouble() - 0.5) * 0.4;
      final maxDistance = 30.0 + random.nextDouble() * 38.0;
      final size = 2.5 + random.nextDouble() * 3.5;
      final color = accentColors[random.nextInt(accentColors.length)];
      final isStar = random.nextBool();

      return _BurstParticle(
        angle: angle,
        maxDistance: maxDistance,
        size: size,
        color: color,
        isStar: isStar,
        rotationSpeed: (random.nextDouble() - 0.5) * 4 * math.pi,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            progress: _controller.value,
            center: widget.center,
            particles: _particles,
          ),
        );
      },
    );
  }
}

class _BurstParticle {
  _BurstParticle({
    required this.angle,
    required this.maxDistance,
    required this.size,
    required this.color,
    required this.isStar,
    required this.rotationSpeed,
  });

  final double angle;
  final double maxDistance;
  final double size;
  final Color color;
  final bool isStar;
  final double rotationSpeed;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.center,
    required this.particles,
  });

  final double progress;
  final Offset center;
  final List<_BurstParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    // Deceleration curve for natural explosive physics
    final distanceProgress = Curves.easeOutCubic.transform(progress);
    // Alpha fades out in the latter 60% of the animation
    final alphaProgress = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final distance = p.maxDistance * distanceProgress;
      final x = center.dx + math.cos(p.angle) * distance;
      final y = center.dy + math.sin(p.angle) * distance;
      final particlePos = Offset(x, y);

      // Shrink particle as it fades
      final currentSize = p.size * (1.0 - progress * 0.4);
      final paint = Paint()
        ..color = p.color.withValues(alpha: alphaProgress)
        ..style = PaintingStyle.fill;

      if (p.isStar) {
        _drawSparkle(
          canvas,
          particlePos,
          currentSize,
          p.rotationSpeed * progress,
          paint,
        );
      } else {
        canvas.drawCircle(particlePos, currentSize, paint);
      }
    }
  }

  void _drawSparkle(
    Canvas canvas,
    Offset center,
    double size,
    double rotation,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final path = Path();
    // 4-pointed sparkle diamond
    path.moveTo(0, -size * 1.5);
    path.quadraticBezierTo(0, 0, size * 1.5, 0);
    path.quadraticBezierTo(0, 0, 0, size * 1.5);
    path.quadraticBezierTo(0, 0, -size * 1.5, 0);
    path.quadraticBezierTo(0, 0, 0, -size * 1.5);
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
