import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/history_entry.dart';
import '../../models/rotation_operation.dart';
import '../../services/history_service.dart';

class HistorySection extends StatelessWidget {
  const HistorySection({
    super.key,
    required this.history,
    required this.onRestore,
    required this.onRefresh,
  });

  final List<HistoryEntry> history;
  final void Function(HistoryEntry) onRestore;
  final Future<void> Function() onRefresh;

  String _formatDate(int ms) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(ms).toLocal().toString().split('.').first;
    } catch (_) {
      return '$ms';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Historial', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                const SizedBox(width: 6),
                Chip(
                  label: Text('${history.length}', style: const TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            TextButton(
              onPressed: history.isEmpty
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Borrar historial'),
                          content: const Text('¿Borrar todo?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await HistoryService.clear();
                        await onRefresh();
                      }
                    },
              child: Text('Limpiar', style: TextStyle(color: cs.error)),
            ),
          ],
        ),
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Aún no hay elementos. La vista previa es automática; al guardar se creará el historial local (100 máx).',
              style: TextStyle(fontStyle: FontStyle.italic, color: cs.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ...history.map(
          (e) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: cs.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDate(e.createdAt), style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cs.onSurfaceVariant)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${e.operations.length} op · ${e.totalAngle}° → ${e.normalizedAngle}°',
                          style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(e.formula, style: const TextStyle(fontFamily: 'monospace', fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Inicial', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(e.imageOriginal), height: 80, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image)),
                            ),
                            Text(e.name, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Resultado', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(e.imageResult), height: 80, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image)),
                            ),
                            Text('${e.showTrace ? 'con trazo' : 'sin trazo'}${e.includeDirect ? ' · directo' : ''}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: e.operations
                        .map((op) => Chip(
                              label: Text(
                                '${op.degrees}° ${op.direction == RotationDirection.cw ? 'horario' : 'antihorario'}',
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: FilledButton(onPressed: () => onRestore(e), child: const Text('Restaurar', style: TextStyle(fontSize: 12)))),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          await HistoryService.delete(e.id);
                          await onRefresh();
                        },
                        child: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text('Imágenes guardadas localmente (no se suben al servidor). Máx 100.', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))),
        const SizedBox(height: 30),
      ],
    );
  }
}
