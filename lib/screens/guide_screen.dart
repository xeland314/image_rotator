import 'package:flutter/material.dart';

import '../models/rotation_operation.dart';
import '../services/rotation_logic.dart';
import '../widgets/image_preview.dart';

/// Guía interna "Aprende el Método" — transforma la app de calculadora a herramienta de aprendizaje activo.
/// Valida para App Review 4.2 Minimum Functionality: teoría + método manual + caso repetitivo 90° x5/x6 con logo_v3.png
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  // Contextual: datos actuales del HomeScreen para "Explicar Resolución"
  static Widget explainCard(BuildContext context, List<RotationOperation> ops) {
    if (ops.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Agrega al menos una operación para ver la explicación paso a paso.'),
        ),
      );
    }
    final total = calculateTotalAngle(ops);
    final normalized = normalizeAngle(total);
    final formula = formatFormula(ops);
    final fullTurns = (total.abs() / 360).floor();
    final remainder = total.abs() - fullTurns * 360;
    final lowerMultiple = fullTurns * 360;
    final negativeFix = total < 0 && normalized != total ? '→ $normalized° (suma 360° por negativo)' : '';
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explicar tu caso actual', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(formula, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            const SizedBox(height: 8),
            Text('Suma con signos: Horario (+) Antihorario (−) → Total $total°', style: const TextStyle(fontSize: 12)),
            Text('Múltiplo inferior 360°: $lowerMultiple° ($fullTurns × 360°)', style: const TextStyle(fontSize: 12)),
            Text('Resta: $total° − $lowerMultiple° = ${remainder.toStringAsFixed(remainder.truncateToDouble() == remainder ? 0 : 1)}° $negativeFix', style: const TextStyle(fontSize: 12)),
            Text('Efectivo normalizado [0,360): $normalized°', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            if (fullTurns > 0) Text('Vueltas completas: $fullTurns + resto ${remainder.round()}°', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Aprende el Método')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Principio fundamental
            _sectionCard(
              context,
              icon: Icons.circle_outlined,
              title: '1. El Principio Fundamental (Círculo Unitario)',
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Una vuelta completa = 360°.'),
                  SizedBox(height: 4),
                  Text('• Cualquier ángulo >360° o <0° equivale a su ángulo en [0°, 360°).'),
                  SizedBox(height: 4),
                  Text('• Por eso 370° ≡ 10°, −90° ≡ 270°, 720° ≡ 0°.', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
            // 2. Método 1
            _sectionCard(
              context,
              icon: Icons.calculate_outlined,
              title: '2. Método 1: Cálculo Mental (múltiplos de 360°)',
              subtitle: 'Más rápido sin calculadora — memoriza 360, 720, 1080, 1440, 1800…',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ejemplo 1 — Ángulo grande positivo:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Giro: 1670° horario'),
                        Text('Múltiplo inferior: 1440° (4 × 360°)'),
                        Text('Cálculo: 1670 − 1440 = 230° efectivos', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        Text('Interpretación: 4 vueltas completas + 230°', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tip examen: resta el múltiplo más cercano sin pasar. Para 823° es 720° (2×360) → 103°.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            // 3. Método 2
            _sectionCard(
              context,
              icon: Icons.functions,
              title: '3. Método 2: Residuo Directo (módulo 360°)',
              subtitle: r'Algebraico: total mod 360',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Divide: 1670 / 360 = 4.638…'),
                    Text('2. Parte entera = 4 vueltas'),
                    Text('3. 4 × 360 = 1440'),
                    Text('4. Resta: 1670 − 1440 = 230°', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            // 4. Conversión sentidos
            _sectionCard(
              context,
              icon: Icons.compare_arrows,
              title: '4. Conversión de Sentidos (Horario vs Antihorario)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cs.secondaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ejemplo 2 — Ecuación compuesta:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('900° Horario + 77° Antihorario'),
                        Text('Ecuación: (+900) + (−77) = +823°', style: TextStyle(fontFamily: 'monospace')),
                        Text('Reducción: 823 − 720 (2×360) = 103° horario', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resultados negativos:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Si suma = −130°, suma 360° → 230° horario'),
                        Text('Fórmula: (−130 mod 360) = 230', style: TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 5. Caso repetitivo 90° x5/x6 con logo_v3.png
            _sectionCard(
              context,
              icon: Icons.repeat,
              title: '5. Caso Frecuente: Misma rotación repetida (Ej. 90° ×5 / ×6)',
              subtitle: 'Exámenes piden la quinta o sexta imagen de una secuencia',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Si cada paso es 90° horario:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _repetitionRow(context, times: 5, degrees: 90, total: 450, effective: 90),
                  const SizedBox(height: 8),
                  _repetitionRow(context, times: 6, degrees: 90, total: 540, effective: 180),
                  const SizedBox(height: 12),
                  const Text('Patrón: cada 4 repeticiones (360°) vuelves al inicio. 5→90°, 6→180°, 7→270°, 8→0°.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 12),
                  Text('Demo visual con logo_v3.png (original 640×640):', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _logoPreview(label: '90°×5 = 450°\n→ 90°', angle: 90)),
                      const SizedBox(width: 8),
                      Expanded(child: _logoPreview(label: '90°×6 = 540°\n→ 180°', angle: 180)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _logoPreview(label: '90°×7 = 630°\n→ 270°', angle: 270)),
                      const SizedBox(width: 8),
                      Expanded(child: _logoPreview(label: '90°×8 = 720°\n→ 0°', angle: 0)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Call to action
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver a practicar'),
            ),
            const SizedBox(height: 8),
            Text(
              'En el examen no usarás la app: esta guía te entrena para calcular mentalmente. Usa la app para verificar.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static Widget _sectionCard(BuildContext context, {required IconData icon, required String title, String? subtitle, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
            const Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  static Widget _repetitionRow(BuildContext context, {required int times, required int degrees, required int total, required int effective}) {
    final lower = (total ~/ 360) * 360;
    final turns = total ~/ 360;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$times × $degrees° = $total°', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          Text('$total − $lower ($turns×360) = $effective°', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ],
      ),
    );
  }

  static Widget _logoPreview({required String label, required double angle}) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: ImagePreview(imagePath: 'assets/images/logo_v3.png', angleDegrees: angle, showTrace: false, cacheWidth: 320),
        ),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
