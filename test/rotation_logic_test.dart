import 'package:flutter_test/flutter_test.dart';
import 'package:image_rotator/services/rotation_logic.dart';
import 'package:image_rotator/models/rotation_operation.dart';

// Port exhaustivo de xeland314.github.io/src/components/tools/rotador-imagenes/rotador.test.ts
void main() {
  group('parseDirection', () {
    test('cw -> horario', () => expect(parseDirection(RotationDirection.cw), 'horario'));
    test('ccw -> antihorario', () => expect(parseDirection(RotationDirection.ccw), 'antihorario'));
  });

  group('calculateTotalAngle', () {
    test('vacío 0', () => expect(calculateTotalAngle([]), 0));
    test('cw 90', () => expect(calculateTotalAngle([const RotationOperation(degrees: 90, direction: RotationDirection.cw)]), 90));
    test('ccw 90', () => expect(calculateTotalAngle([const RotationOperation(degrees: 90, direction: RotationDirection.ccw)]), -90));
    test('mixto 180 cw -90 ccw +270 cw =360', () {
      expect(calculateTotalAngle([
        const RotationOperation(degrees: 180, direction: RotationDirection.cw),
        const RotationOperation(degrees: 90, direction: RotationDirection.ccw),
        const RotationOperation(degrees: 270, direction: RotationDirection.cw),
      ]), 360);
    });
    test('900 cw +770 cw =1670', () {
      expect(calculateTotalAngle([
        const RotationOperation(degrees: 900, direction: RotationDirection.cw),
        const RotationOperation(degrees: 770, direction: RotationDirection.cw),
      ]), 1670);
    });
  });

  group('normalizeAngle', () {
    test('0->0', () => expect(normalizeAngle(0), 0));
    test('360->0', () => expect(normalizeAngle(360), 0));
    test('405->45', () => expect(normalizeAngle(405), 45));
    test('-90->270', () => expect(normalizeAngle(-90), 270));
    test('-360->0', () => expect(normalizeAngle(-360), 0));
    test('1670->230', () => expect(normalizeAngle(1670), 230));
  });

  group('validateDegrees', () {
    test('90 true', () => expect(validateDegrees(90), true));
    test('0 true', () => expect(validateDegrees(0), true));
    test('-10 false', () => expect(validateDegrees(-10), false));
    test('NaN false', () => expect(validateDegrees(double.nan), false));
    test('string false', () => expect(validateDegrees('90'), false));
  });

  group('parseDegreesInput', () {
    test('90', () => expect(parseDegreesInput('90'), 90));
    test('45.5', () => expect(parseDegreesInput('45.5'), 45.5));
    test('vacío null', () => expect(parseDegreesInput(''), null));
    test('espacios null', () => expect(parseDegreesInput('   '), null));
    test('abc null', () => expect(parseDegreesInput('abc'), null));
    test('-10 null', () => expect(parseDegreesInput('-10'), null));
    test('0', () => expect(parseDegreesInput('0'), 0));
    test('trim', () => expect(parseDegreesInput('  90  '), 90));
  });

  group('formatFormula', () {
    test('vacío 0°', () => expect(formatFormula([]), '0°'));
    test('single cw +90 =90', () => expect(formatFormula([const RotationOperation(degrees: 90, direction: RotationDirection.cw)]), '+90° = 90°'));
    test('single ccw -90 =270 efectivos', () => expect(formatFormula([const RotationOperation(degrees: 90, direction: RotationDirection.ccw)]), '-90° = 270° efectivos'));
    test('mixto +180 -90 =90', () => expect(formatFormula([
          const RotationOperation(degrees: 180, direction: RotationDirection.cw),
          const RotationOperation(degrees: 90, direction: RotationDirection.ccw),
        ]), '+180° -90° = 90°'));
    test('450 cw efectivos', () => expect(formatFormula([const RotationOperation(degrees: 450, direction: RotationDirection.cw)]), '+450° = 90° efectivos'));
  });

  group('interpolateAngle', () {
    test('t0', () => expect(interpolateAngle(0, 90, 0), 0));
    test('t1', () => expect(interpolateAngle(0, 90, 1), 90));
    test('t0.5', () => expect(interpolateAngle(0, 90, 0.5), 45));
    test('clamp low', () => expect(interpolateAngle(0, 90, -0.5), 0));
    test('clamp high', () => expect(interpolateAngle(0, 90, 1.5), 90));
  });

  group('buildAnimationSteps', () {
    test('vacío', () => expect(buildAnimationSteps([]), isEmpty));
    test('single', () {
      final steps = buildAnimationSteps([const RotationOperation(degrees: 90, direction: RotationDirection.cw)]);
      expect(steps.length, 2);
      expect(steps[0].fromAngle, 0);
      expect(steps[0].toAngle, 90);
      expect(steps[0].label, 'Paso 1: 90° horario');
      expect(steps[1].label, 'Resultado final');
    });
    test('cumulative chain', () {
      final steps = buildAnimationSteps([
        const RotationOperation(degrees: 90, direction: RotationDirection.cw),
        const RotationOperation(degrees: 45, direction: RotationDirection.cw),
      ]);
      expect(steps[0].toAngle, 90);
      expect(steps[1].fromAngle, 90);
      expect(steps[1].toAngle, 135);
    });
    test('includeDirect true', () {
      final steps = buildAnimationSteps([const RotationOperation(degrees: 450, direction: RotationDirection.cw)], includeDirectScene: true);
      expect(steps.length, 4);
      expect(steps[2].traceMode, TraceMode.direct);
      expect(steps[2].toAngle, 90);
    });
    test('direct normalized 1670->230', () {
      final steps = buildAnimationSteps([
        const RotationOperation(degrees: 900, direction: RotationDirection.cw),
        const RotationOperation(degrees: 770, direction: RotationDirection.cw),
      ], includeDirectScene: true);
      final direct = steps.firstWhere((s) => s.traceMode == TraceMode.direct && s.fromAngle == 0);
      expect(direct.toAngle, 230);
    });
  });

  group('totalAnimationDuration', () {
    test('sum', () => expect(totalAnimationDuration([
          const AnimationStep(fromAngle: 0, toAngle: 90, duration: 1000, label: 'a'),
          const AnimationStep(fromAngle: 90, toAngle: 90, duration: 500, label: 'b'),
        ]), 1500));
  });

  group('resolveAngleAtTime', () {
    final steps = [
      const AnimationStep(fromAngle: 0, toAngle: 90, duration: 1000, label: 's1'),
      const AnimationStep(fromAngle: 90, toAngle: 180, duration: 1000, label: 's2'),
    ];
    test('0ms', () => expect(resolveAngleAtTime(steps, 0), 0));
    test('500ms', () => expect(resolveAngleAtTime(steps, 500), 45));
    test('1000ms', () => expect(resolveAngleAtTime(steps, 1000), 90));
    test('1500ms', () => expect(resolveAngleAtTime(steps, 1500), 135));
    test('beyond', () => expect(resolveAngleAtTime(steps, 3000), 180));
  });
}
