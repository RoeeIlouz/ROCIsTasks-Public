import 'dart:math';
import 'package:flutter/material.dart';

class CircularTaskChart extends StatelessWidget {
  final int completed;
  final int pending;
  final int deleted;
  final double size;

  const CircularTaskChart({
    super.key,
    required this.completed,
    required this.pending,
    required this.deleted,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CircularChartPainter(
          completed: completed,
          pending: pending,
          deleted: deleted,
        ),
      ),
    );
  }
}

class _CircularChartPainter extends CustomPainter {
  final int completed;
  final int pending;
  final int deleted;

  _CircularChartPainter({
    required this.completed,
    required this.pending,
    required this.deleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.12; // 12% thickness

    final total = completed + pending + deleted;
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
    const colorCompleted = Color(0xFF4CAF50); // Green
    const colorPending = Color(0xFFFF9800); // Orange
    const colorDeleted = Color(0xFFF44336); // Red

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -pi / 2; // Start from top

    // Draw background circle first to ensure continuity if gaps exist
    // Actually, distinct segments look better.

    final segments = [
      _ChartSegment(completed, colorCompleted),
      _ChartSegment(pending, colorPending),
      _ChartSegment(deleted, colorDeleted),
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

      // Add a small gap between segments ?
      // For a progressive circle, typically they are continuous.

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
