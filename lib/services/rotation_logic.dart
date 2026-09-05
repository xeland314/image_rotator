// Port 1:1 de src/components/tools/rotador-imagenes/rotador.ts + canvas.ts (lógica pura, sin DOM)
import 'dart:math' as math;
import '../models/rotation_operation.dart';

/// Equivalente a parseDirection en rotador.ts
String parseDirection(RotationDirection dir) =>
    dir == RotationDirection.cw ? 'horario' : 'antihorario';

/// calculateTotalAngle
double calculateTotalAngle(List<RotationOperation> ops) {
  return ops.fold<double>(0, (total, op) {
    return total + (op.direction == RotationDirection.cw ? op.degrees : -op.degrees);
  });
}

/// normalizeAngle -> ((angle % 360)+360)%360
double normalizeAngle(double angle) {
  return ((angle % 360) + 360) % 360;
}

bool validateDegrees(dynamic degrees) {
  if (degrees is! num) return false;
  if (degrees.isNaN) return false;
  return degrees >= 0;
}

double? parseDegreesInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final value = double.tryParse(trimmed);
  if (value == null) return null;
  return validateDegrees(value) ? value : null;
}

String formatFormula(List<RotationOperation> ops) {
  if (ops.isEmpty) return '0°';
  final terms = ops.map((op) {
    final signed = op.direction == RotationDirection.cw ? op.degrees : -op.degrees;
    final s = signed >= 0 ? '+${signed.toStringAsFixed(signed.truncateToDouble() == signed ? 0 : 1)}°' : '${signed.toStringAsFixed(signed.truncateToDouble() == signed ? 0 : 1)}°';
    // limpiar .0
    return s.replaceAll('.0°', '°');
  }).join(' ');
  final total = calculateTotalAngle(ops);
  final normalized = normalizeAngle(total);
  final effective = normalized != total ? ' = ${normalized.toStringAsFixed(normalized.truncateToDouble() == normalized ? 0 : 1).replaceAll('.0', '')}° efectivos' : ' = ${total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 1).replaceAll('.0', '')}°';
  return '$terms$effective';
}

double interpolateAngle(double from, double to, double t) {
  final clamped = t.clamp(0.0, 1.0);
  return from + (to - from) * clamped;
}

List<AnimationStep> buildAnimationSteps(
  List<RotationOperation> ops, {
  AnimationOptions options = AnimationOptions.defaultOptions,
  bool includeDirectScene = false,
}) {
  if (ops.isEmpty) return [];
  final steps = <AnimationStep>[];
  double prevAngle = 0;
  for (var i = 0; i < ops.length; i++) {
    final cumulative = calculateTotalAngle(ops.sublist(0, i + 1));
    final op = ops[i];
    steps.add(AnimationStep(
      fromAngle: prevAngle,
      toAngle: cumulative,
      duration: options.stepDuration,
      label: 'Paso ${i + 1}: ${op.degrees.toStringAsFixed(op.degrees.truncateToDouble() == op.degrees ? 0 : 1).replaceAll('.0', '')}° ${parseDirection(op.direction)}',
      traceMode: TraceMode.cumulative,
    ));
    prevAngle = cumulative;
  }
  steps.add(AnimationStep(
    fromAngle: prevAngle,
    toAngle: prevAngle,
    duration: options.holdDuration,
    label: 'Resultado final',
    traceMode: TraceMode.cumulative,
  ));
  if (includeDirectScene) {
    final totalAngle = calculateTotalAngle(ops);
    final normalized = normalizeAngle(totalAngle);
    steps.add(AnimationStep(
      fromAngle: 0,
      toAngle: normalized,
      duration: options.stepDuration,
      label: 'Resultado directo (efectivo)',
      traceMode: TraceMode.direct,
    ));
    steps.add(AnimationStep(
      fromAngle: normalized,
      toAngle: normalized,
      duration: options.holdDuration,
      label: 'Resultado directo (efectivo)',
      traceMode: TraceMode.direct,
    ));
  }
  return steps;
}

int totalAnimationDuration(List<AnimationStep> steps) =>
    steps.fold(0, (sum, s) => sum + s.duration);

double resolveAngleAtTime(List<AnimationStep> steps, int elapsedMs) {
  int remaining = elapsedMs;
  for (final step in steps) {
    if (remaining <= step.duration) {
      final t = remaining / step.duration;
      return interpolateAngle(step.fromAngle, step.toAngle, t);
    }
    remaining -= step.duration;
  }
  return steps.isNotEmpty ? steps.last.toAngle : 0;
}

AnimationStep? resolveStepAtTime(List<AnimationStep> steps, int elapsedMs) {
  int remaining = elapsedMs;
  for (final step in steps) {
    if (remaining <= step.duration) return step;
    remaining -= step.duration;
  }
  return steps.isNotEmpty ? steps.last : null;
}

// Extras portados de canvas.ts para cálculo de escala (no Canvas DOM)
double computePreviewScale({
  required int imgW,
  required int imgH,
  required int canvasW,
  required int canvasH,
  double factor = 0.7,
}) {
  return math.min(canvasW / imgW, canvasH / imgH) * factor;
}
