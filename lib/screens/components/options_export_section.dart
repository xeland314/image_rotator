import 'package:flutter/material.dart';

class OptionsSection extends StatelessWidget {
  const OptionsSection({
    super.key,
    required this.showTrace,
    required this.includeDirect,
    required this.onShowTraceChanged,
    required this.onIncludeDirectChanged,
  });

  final bool showTrace;
  final bool includeDirect;
  final ValueChanged<bool> onShowTraceChanged;
  final ValueChanged<bool> onIncludeDirectChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: showTrace,
              onChanged: (v) => onShowTraceChanged(v!),
              title: const Text(
                'Trazar arco (goniómetro con vueltas)',
                style: TextStyle(fontSize: 13),
              ),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: includeDirect,
              onChanged: (v) => onIncludeDirectChanged(v!),
              title: const Text(
                'Incluir resultado directo (ángulo efectivo)',
                style: TextStyle(fontSize: 13),
              ),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ],
      ),
    );
  }
}

class ExportSection extends StatelessWidget {
  const ExportSection({
    super.key,
    required this.canApply,
    required this.exportProgress,
    required this.onExportFinal,
    required this.onExportZip,
  });

  final bool canApply;
  final double exportProgress;
  final VoidCallback onExportFinal;
  final VoidCallback onExportZip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: canApply ? onExportFinal : null,
                icon: const Icon(Icons.save_alt),
                label: const Text('Guardar en galería'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: canApply ? onExportZip : null,
                icon: const Icon(Icons.folder_zip),
                label: const Text('ZIP pasos'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        if (exportProgress > 0) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: exportProgress),
          const SizedBox(height: 4),
          Text(
            '${(exportProgress * 100).toInt()}%',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
