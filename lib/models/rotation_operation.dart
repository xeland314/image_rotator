// Port de xeland314.github.io/src/components/tools/rotador-imagenes/rotador.ts
enum RotationDirection { cw, ccw }

enum TraceMode { cumulative, direct }

class RotationOperation {
  final double degrees;
  final RotationDirection direction;

  const RotationOperation({required this.degrees, required this.direction});

  Map<String, dynamic> toJson() => {
        'degrees': degrees,
        'direction': direction.name,
      };

  factory RotationOperation.fromJson(Map<String, dynamic> json) {
    return RotationOperation(
      degrees: (json['degrees'] as num).toDouble(),
      direction: json['direction'] == 'cw' ? RotationDirection.cw : RotationDirection.ccw,
    );
  }

  RotationOperation copyWith({double? degrees, RotationDirection? direction}) {
    return RotationOperation(
      degrees: degrees ?? this.degrees,
      direction: direction ?? this.direction,
    );
  }
}

class AnimationOptions {
  final int stepDuration; // ms
  final int holdDuration; // ms
  final int fps;

  const AnimationOptions({
    this.stepDuration = 2000,
    this.holdDuration = 1500,
    this.fps = 30,
  });

  static const defaultOptions = AnimationOptions();
}

class AnimationStep {
  final double fromAngle;
  final double toAngle;
  final int duration;
  final String label;
  final TraceMode traceMode;

  const AnimationStep({
    required this.fromAngle,
    required this.toAngle,
    required this.duration,
    required this.label,
    this.traceMode = TraceMode.cumulative,
  });
}
