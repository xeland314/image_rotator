import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'trace_painter.dart';
import '../models/rotation_operation.dart';

class ImagePreview extends StatelessWidget {
  final String imagePath;
  final double angleDegrees;
  final bool showTrace;
  final TraceMode traceMode;
  final double? cacheWidth;

  const ImagePreview({
    super.key,
    required this.imagePath,
    required this.angleDegrees,
    this.showTrace = false,
    this.traceMode = TraceMode.cumulative,
    this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Estrategia clave #1: preview liviano — cacheWidth + Transform.rotate, sin decodificar matriz editada
    final file = File(imagePath);
    final angleRad = angleDegrees * math.pi / 180;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight.isFinite ? constraints.maxHeight : w;
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: angleRad,
              child: Image.file(
                file,
                fit: BoxFit.contain,
                cacheWidth: cacheWidth?.toInt() ?? 720,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
              ),
            ),
            if (showTrace)
              Positioned.fill(
                child: CustomPaint(
                  painter: TracePainter(totalAngle: angleDegrees, traceMode: traceMode),
                ),
              ),
            // etiqueta ángulo sutil
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text('${angleDegrees.toStringAsFixed(angleDegrees.truncateToDouble() == angleDegrees ? 0 : 1).replaceAll('.0','')}°', style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12)),
              ),
            ),
          ],
        ),
      );
    });
  }
}
