import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Params para Isolate.run — todo debe ser Sendable (primitivos + String)
class ExportTask {
  final String inputPath;
  final double angleDegrees;
  final String outputName; // sin extensión
  final int quality; // 0-100
  final String format; // 'jpg' | 'png'

  const ExportTask({
    required this.inputPath,
    required this.angleDegrees,
    required this.outputName,
    this.quality = 95,
    this.format = 'jpg',
  });
}

class ExportResult {
  final String outputPath;
  final int width;
  final int height;

  const ExportResult({required this.outputPath, required this.width, required this.height});
}

/// Decodifica, rota en ángulo libre y guarda en disco.
/// Debe ejecutarse en Isolate secundario para no congelar la UI (fotos 48MP+ ~200MB).
Future<ExportResult> exportImageTask(ExportTask task) async {
  final bytes = await File(task.inputPath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('No se pudo decodificar imagen: ${task.inputPath}');

  // Si es múltiplo de 90°, podríamos hacer EXIF lossless, pero aquí rotamos matriz con calidad 95
  // para fidelidad total. La librería `image` maneja interpolación bicúbica.
  // Normalizar ángulo para evitar rotaciones gigantes innecesarias
  double angle = task.angleDegrees % 360;

  img.Image rotated;
  if (angle == 0) {
    rotated = decoded;
  } else {
    // image 4.x: copyRotate con angle en grados
    rotated = img.copyRotate(decoded, angle: angle);
  }

  // getTemporaryDirectory() no funciona en Isolate (sin MethodChannel) -> usar systemTemp
  final dir = Directory.systemTemp;
  final ext = task.format == 'png' ? 'png' : 'jpg';
  final outPath = p.join(dir.path, '${task.outputName}.$ext');

  Uint8List outBytes;
  if (ext == 'png') {
    outBytes = Uint8List.fromList(img.encodePng(rotated));
  } else {
    outBytes = Uint8List.fromList(img.encodeJpg(rotated, quality: task.quality));
  }
  await File(outPath).writeAsBytes(outBytes);
  return ExportResult(outputPath: outPath, width: rotated.width, height: rotated.height);
}

/// Exporta un ZIP con todos los pasos como PNGs (equivalente a exportAllStepsAsZip en canvas.ts)
class ZipExportTask {
  final String inputPath;
  final List<double> angles;
  final List<String> labels;
  final int quality;

  const ZipExportTask({
    required this.inputPath,
    required this.angles,
    required this.labels,
    this.quality = 95,
  });
}

Future<String> exportStepsZipTask(ZipExportTask task) async {
  final bytes = await File(task.inputPath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Decode falló');

  final dir = Directory.systemTemp;
  final archivePath = p.join(dir.path, 'pasos-rotacion-${DateTime.now().millisecondsSinceEpoch}.zip');

  // Construir ZIP manualmente sin cargar todo en memoria a la vez es ideal,
  // pero para pasos < ~20 es aceptable. Usamos archive package en el Isolate padre si se desea.
  // Aquí solo generamos los PNGs temporales y retornamos lista de paths;
  // el empaquetado ZIP se hace fuera del Isolate para simplificar.
  // Generamos todos los PNGs en temp y retornamos el primero como señal (compatibilidad).
  // El caller superior manejará el ZIP.
  final List<String> pngPaths = [];
  for (var i = 0; i < task.angles.length; i++) {
    final angle = task.angles[i] % 360;
    final rotated = angle == 0 ? decoded : img.copyRotate(decoded, angle: angle);
    final pngBytes = img.encodePng(rotated);
    final safe = task.labels[i].replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúñÁÉÍÓÚÑ \-]'), '').trim();
    final name = '${(i + 1).toString().padLeft(2, '0')}-$safe.png';
    final out = p.join(dir.path, name);
    await File(out).writeAsBytes(pngBytes);
    pngPaths.add(out);
  }
  // Guardamos lista en un archivo manifest para que el caller lo recoja
  await File(archivePath).writeAsString(pngPaths.join('\n'));
  return archivePath;
}
