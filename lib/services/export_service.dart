import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'image_processor.dart';

/// Servicio dedicado a exports. Single Responsibility:
/// - convierte I/O + Isolate en operaciones testeables
/// - HomeScreen solo orquesta UI/progreso/dialogs
/// Usa `compute` (Flutter) en lugar de `Isolate.run` crudo para no arrastrar
/// WidgetsBinding.firstFrameCompleter (_AsyncCompleter) al Isolate.

// Top-level entries para `compute` -> no capturan `this` ni Zone de Flutter
@pragma('vm:entry-point')
Future<ExportResult> _exportEntry(ExportTask task) => exportImageTask(task);

class ExportService {
  /// Exporta imagen final rotada. Retorna [ExportResult] con path en systemTemp.
  static Future<ExportResult> exportSingle({
    required String inputPath,
    required double angleDegrees,
    String? outputName,
    int quality = 95,
    String format = 'jpg',
  }) async {
    final task = ExportTask(
      inputPath: inputPath,
      angleDegrees: angleDegrees,
      outputName: outputName ?? 'rotado_${DateTime.now().millisecondsSinceEpoch}',
      quality: quality,
      format: format,
    );
    // compute evita el bug `Invalid argument in isolate message: _AsyncCompleter`
    // que ocurre con `Isolate.run(() => fn(task))` cuando la closure captura Zone/Binding
    try {
      return await compute(_exportEntry, task);
    } catch (e) {
      debugPrint('ExportService.compute fallback to direct: $e');
      // Fallback síncrono en main isolate para debug (lento pero funciona)
      return await exportImageTask(task);
    }
  }

  /// Exporta ZIP con todos los pasos (PNGs) y retorna path del .zip en temp.
  /// `onProgress` 0..1 para UI. Cada paso usa `compute` aislado.
  static Future<String> exportZip({
    required String inputPath,
    required List<double> angles,
    required List<String> labels,
    void Function(double progress)? onProgress,
  }) async {
    assert(angles.length == labels.length);
    final dir = await getTemporaryDirectory();
    final List<String> pngPaths = [];

    for (var i = 0; i < angles.length; i++) {
      onProgress?.call(0.05 + 0.8 * (i / angles.length));
      final safe = labels[i].replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúñÁÉÍÓÚÑ \-]'), '').trim();
      final outName = 'paso_${i}_${DateTime.now().millisecondsSinceEpoch}';
      final task = ExportTask(
        inputPath: inputPath,
        angleDegrees: angles[i],
        outputName: outName,
        quality: 95,
        format: 'png',
      );
      ExportResult r;
      try {
        r = await compute(_exportEntry, task);
      } catch (e) {
        debugPrint('ExportService zip step $i compute fallback: $e');
        r = await exportImageTask(task);
      }
      final newName = '${(i + 1).toString().padLeft(2, '0')}-$safe.png';
      final newPath = p.join(dir.path, newName);
      // rename puede fallar cross-device, usar copy+delete
      try {
        await File(r.outputPath).rename(newPath);
      } catch (_) {
        await File(r.outputPath).copy(newPath);
        try {
          await File(r.outputPath).delete();
        } catch (_) {}
      }
      pngPaths.add(newPath);
    }

    onProgress?.call(0.9);
    final archive = Archive();
    for (final path in pngPaths) {
      final bytes = await File(path).readAsBytes();
      archive.addFile(ArchiveFile(p.basename(path), bytes.length, bytes));
    }
    final zipBytes = ZipEncoder().encode(archive);
    final zipPath = p.join(dir.path, 'pasos-rotacion-${DateTime.now().millisecondsSinceEpoch}.zip');
    await File(zipPath).writeAsBytes(zipBytes);
    return zipPath;
  }
}
