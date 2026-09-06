import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../models/rotation_operation.dart';
import '../../widgets/image_preview.dart';

class ImageSection extends StatelessWidget {
  const ImageSection({
    super.key,
    required this.hasImage,
    required this.imagePath,
    required this.imageName,
    required this.isDesktop,
    required this.totalAngle,
    required this.showTrace,
    required this.includeDirect,
    required this.normalized,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onCrop,
  });

  final bool hasImage;
  final String? imagePath;
  final String imageName;
  final bool isDesktop;
  final double totalAngle;
  final bool showTrace;
  final bool includeDirect;
  final double normalized;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onCrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '1. Selecciona tu imagen',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (isDesktop)
          FilledButton.icon(
            onPressed: onPickGallery,
            icon: const Icon(Icons.photo_library),
            label: const Text('Seleccionar imagen'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )
        else if (!FeatureFlags.enableCamera)
          // Variante sin cámara (--dart-define=ENABLE_CAMERA=false): solo galería, sin crop si flag off
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                ),
              ),
              if (FeatureFlags.enableCrop && hasImage) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onCrop,
                  icon: const Icon(Icons.crop),
                  tooltip: 'Recortar (uCrop nativo)',
                ),
              ],
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickCamera,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Cámara'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              if (FeatureFlags.enableCrop && hasImage) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onCrop,
                  icon: const Icon(Icons.crop),
                  tooltip: 'Recortar (uCrop nativo)',
                ),
              ],
            ],
          ),
        if (hasImage) ...[
          const SizedBox(height: 12),
          Container(
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: ImagePreview(
              imagePath: imagePath!,
              angleDegrees: totalAngle,
              showTrace: showTrace,
              traceMode: includeDirect && normalized != totalAngle
                  ? TraceMode.direct
                  : TraceMode.cumulative,
              cacheWidth: 720,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            imageName,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
