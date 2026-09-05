import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/rotation_operation.dart';

/// Port visual de drawTraceLayer de canvas.ts
/// Dibuja anillos concéntricos por cada vuelta completa (360°) + arco parcial
class TracePainter extends CustomPainter {
  final double totalAngle;
  final TraceMode traceMode;
  final bool showTurns;

  static const Color traceFull = Color(0xFFC4392B);
  static const Color tracePartial = Color(0xFFF0A05A);
  static const Color guideColor = Color.fromRGBO(195, 90, 40, 0.18);

  const TracePainter({
    required this.totalAngle,
    this.traceMode = TraceMode.cumulative,
    this.showTurns = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseRadius = math.min(size.width, size.height) * 0.38;
    final ringStep = math.max(4.0, math.min(size.width, size.height) * 0.012);

    final absAngle = totalAngle.abs();
    final fullTurns = (absAngle / 360).floor();
    final remainder = absAngle - fullTurns * 360;
    final sign = totalAngle >= 0 ? 1 : -1;

    final guideRadius = math.max(
      baseRadius + ringStep * 4,
      baseRadius + ringStep * fullTurns + (remainder > 0 ? ringStep : 0),
    );

    // Guía punteada
    final guidePaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // simular dashed con path
    _drawDashedCircle(canvas, Offset(cx, cy), guideRadius, guidePaint);

    void drawArc(double radius, double fromDeg, double toDeg) {
      if (toDeg == fromDeg) return;
      final paint = Paint()
        ..color = traceFull
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final sweep = (toDeg - fromDeg) * math.pi / 180;
      final start = fromDeg * math.pi / 180;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius), start, sweep, false, paint);
    }

    for (int t = 0; t < fullTurns; t++) {
      drawArc(baseRadius + ringStep * t, 0, sign * 360);
    }
    if (remainder > 0) {
      final partialRadius = baseRadius + ringStep * fullTurns;
      final paint = Paint()
        ..color = tracePartial
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final sweep = remainder * sign * math.pi / 180;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: partialRadius), 0, sweep, false, paint);
      final tipAngle = remainder * sign * math.pi / 180;
      final tipPaint = Paint()..color = tracePartial;
      canvas.drawCircle(Offset(cx + partialRadius * math.cos(tipAngle), cy + partialRadius * math.sin(tipAngle)), 3.5, tipPaint);
    }

    if (showTurns) {
      final scale = size.width / 720;
      final fontPx = math.max(12.0, (18 * scale));
      final remainderText = remainder > 0 ? ' + ${remainder.round()}°' : '';
      final label = traceMode == TraceMode.direct ? 'Efectivo: ${absAngle.round()}°' : 'Vueltas: $fullTurns$remainderText';
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: traceFull, fontSize: fontPx, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 16 * scale, size.height - tp.height - 20 * scale));
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    final path = Path();
    const segments = 60;
    for (int i = 0; i < segments; i++) {
      final start = (i * (dash + gap)) * math.pi / 180 * (360 / segments);
      final sweep = dash * math.pi / 180 * (360 / segments) / (dash + gap) * 2;
      path.addArc(Rect.fromCircle(center: center, radius: radius), start, sweep);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TracePainter old) =>
      old.totalAngle != totalAngle || old.traceMode != traceMode || old.showTurns != showTurns;
}
