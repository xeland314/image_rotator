import 'package:flutter/material.dart';

import '../../models/rotation_operation.dart';
import '../../widgets/image_preview.dart';

class ResultSection extends StatelessWidget {
  const ResultSection({
    super.key,
    required this.canApply,
    required this.totalAngle,
    required this.normalized,
    required this.formula,
    required this.displaySteps,
    required this.hasImage,
    required this.imagePath,
    required this.showTrace,
    required this.includeDirect,
  });

  final bool canApply;
  final double totalAngle;
  final double normalized;
  final String formula;
  final List<AnimationStep> displaySteps;
  final bool hasImage;
  final String? imagePath;
  final bool showTrace;
  final bool includeDirect;

  String _fmt(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1).replaceAll('.0', '');

  @override
  Widget build(BuildContext context) {
    if (!canApply) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Resultado final',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Rotación total: ${_fmt(totalAngle)}° ${normalized != totalAngle ? '(${_fmt(normalized)}° efectivos)' : ''}',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w300),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(formula, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: Text(
            'Ver desglose paso a paso (${displaySteps.length} pasos)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          children: displaySteps.map((s) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          Text(
                            '${s.toAngle.toStringAsFixed(1).replaceAll('.0', '')}°',
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 130,
                        child: hasImage
                            ? ImagePreview(
                                imagePath: imagePath!,
                                angleDegrees: s.toAngle,
                                showTrace: false,
                                cacheWidth: 400,
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (showTrace) ...[
          const SizedBox(height: 12),
          Text('Trazos', style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 160,
                  child: hasImage
                      ? ImagePreview(
                          imagePath: imagePath!,
                          angleDegrees: totalAngle,
                          showTrace: true,
                          traceMode: TraceMode.cumulative,
                        )
                      : const SizedBox(),
                ),
              ),
              if (includeDirect) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 160,
                    child: hasImage
                        ? ImagePreview(
                            imagePath: imagePath!,
                            angleDegrees: normalized,
                            showTrace: true,
                            traceMode: TraceMode.direct,
                          )
                        : const SizedBox(),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Acumulado: $totalAngle°',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ),
              if (includeDirect)
                Expanded(
                  child: Text(
                    'Directo: $normalized°',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
