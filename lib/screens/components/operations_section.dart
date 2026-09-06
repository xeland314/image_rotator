import 'package:flutter/material.dart';

import '../../models/rotation_operation.dart';
import '../../services/rotation_logic.dart';

class OperationsSection extends StatelessWidget {
  const OperationsSection({
    super.key,
    required this.ops,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final List<RotationOperation> ops;
  final void Function(int) onMoveUp;
  final void Function(int) onMoveDown;
  final void Function(int) onEdit;
  final void Function(int) onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '2. Operaciones de rotación',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (ops.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              'No hay operaciones. Agrega una abajo.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ...ops.asMap().entries.map((e) {
          final i = e.key;
          final op = e.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            color: cs.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              dense: true,
              leading: Text(
                '${i + 1}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: cs.onSurfaceVariant,
                ),
              ),
              title: Text(
                '${op.degrees.toStringAsFixed(op.degrees.truncateToDouble() == op.degrees ? 0 : 1).replaceAll('.0', '')}° ${parseDirection(op.direction)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: i == 0 ? null : () => onMoveUp(i),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed: i == ops.length - 1 ? null : () => onMoveDown(i),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => onEdit(i),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: cs.error),
                    onPressed: () => onDelete(i),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class OperationInput extends StatelessWidget {
  const OperationInput({
    super.key,
    required this.degreesCtrl,
    required this.direction,
    required this.isEditing,
    required this.onDirectionChanged,
    required this.onSubmit,
  });

  final TextEditingController degreesCtrl;
  final RotationDirection direction;
  final bool isEditing;
  final ValueChanged<RotationDirection> onDirectionChanged;
  final VoidCallback onSubmit;

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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: degreesCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Grados',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<RotationDirection>(
                    initialValue: direction,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: RotationDirection.cw,
                        child: Text('Horario', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: RotationDirection.ccw,
                        child: Text('Antihorario', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) onDirectionChanged(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(isEditing ? 'Guardar' : 'Agregar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
