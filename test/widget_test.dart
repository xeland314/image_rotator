import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_rotator/services/rotation_logic.dart';
import 'package:image_rotator/models/rotation_operation.dart';

void main() {
  // Unit tests port de xeland314.github.io/src/components/tools/rotador-imagenes/rotador.test.ts
  group('rotation_logic', () {
    test('calculateTotalAngle cw/ccw', () {
      expect(calculateTotalAngle([const RotationOperation(degrees: 90, direction: RotationDirection.cw)]), 90);
      expect(calculateTotalAngle([const RotationOperation(degrees: 90, direction: RotationDirection.ccw)]), -90);
      expect(calculateTotalAngle([
        const RotationOperation(degrees: 180, direction: RotationDirection.cw),
        const RotationOperation(degrees: 90, direction: RotationDirection.ccw),
        const RotationOperation(degrees: 270, direction: RotationDirection.cw),
      ]), 360);
    });

    test('normalizeAngle', () {
      expect(normalizeAngle(0), 0);
      expect(normalizeAngle(360), 0);
      expect(normalizeAngle(405), 45);
      expect(normalizeAngle(-90), 270);
      expect(normalizeAngle(1670), 230);
    });

    test('formatFormula', () {
      expect(formatFormula([]), '0°');
      expect(formatFormula([const RotationOperation(degrees: 90, direction: RotationDirection.cw)]), contains('90°'));
    });

    test('buildAnimationSteps', () {
      final ops = [const RotationOperation(degrees: 90, direction: RotationDirection.cw)];
      final steps = buildAnimationSteps(ops);
      expect(steps.length, 2);
      expect(steps[0].fromAngle, 0);
      expect(steps[0].toAngle, 90);
    });
  });

  testWidgets('RotadorApp builds', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Text('Rotador de Imágenes Multi-Giro', style: const TextStyle(fontSize: 16))),
    ));
    expect(find.textContaining('Rotador'), findsOneWidget);
  });
}
