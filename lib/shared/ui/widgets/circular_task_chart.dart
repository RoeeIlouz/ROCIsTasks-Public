import 'dart:math';
import 'package:flutter/material.dart';

class CircularTaskChart extends StatelessWidget {
  final int high;
  final int medium;
  final int low;
  final double size;

  const CircularTaskChart({
    super.key,
    required this.high,
    required this.medium,
    required this.low,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CircularChartPainter(high: high, medium: medium, low: low),
      ),
    );
  }
}

class _CircularChartPainter extends CustomPainter {
  final int high;
  final int medium;
  final int low;

  _CircularChartPainter({
    required this.high,
    required this.medium,
    required this.low,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.12; // 12% thickness

    final total = high + medium + low;
    if (total == 0) {
      // Draw empty circle
      final paint = Paint()
        ..color = const Color(0xFFEEEEEE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    // Colors
    const colorHigh = Color(0xFFFF5252); // Red Accent
    const colorMedium = Color(0xFFFFAB40); // Orange Accent
    const colorLow = Color(0xFF69F0AE); // Green Accent

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -pi / 2; // Start from top

    final segments = [
      _ChartSegment(low, colorLow),
      _ChartSegment(medium, colorMedium),
      _ChartSegment(high, colorHigh),
    ];

    // Filter empty segments
    final activeSegments = segments.where((s) => s.value > 0).toList();

    if (activeSegments.length == 1) {
      // Single full circle
      paint.color = activeSegments.first.color;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    for (final segment in activeSegments) {
      final sweepAngle = (segment.value / total) * 2 * pi;

      paint.color = segment.color;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ChartSegment {
  final int value;
  final Color color;

  _ChartSegment(this.value, this.color);
}
