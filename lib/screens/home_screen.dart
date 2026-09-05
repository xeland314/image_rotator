import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/history_entry.dart';
import '../models/rotation_operation.dart';
import '../services/gallery_service.dart';
import '../services/history_service.dart';
import '../services/image_processor.dart';
import '../services/rotation_logic.dart';
import '../services/theme_service.dart';
import '../widgets/image_preview.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  String? _imagePath;
  String _imageName = 'imagen';
  final List<RotationOperation> _ops = [];
  final _degreesCtrl = TextEditingController(text: '90');
  RotationDirection _dir = RotationDirection.cw;
  int? _editingIndex;
  bool _showTrace = false;
  bool _includeDirect = true;
  double _exportProgress = 0;
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await HistoryService.getAll();
    if (mounted) setState(() => _history = list);
  }

  double get _totalAngle => calculateTotalAngle(_ops);
  double get _normalized => normalizeAngle(_totalAngle);
  String get _formula => formatFormula(_ops);
  List<AnimationStep> get _steps =>
      buildAnimationSteps(_ops, includeDirectScene: _includeDirect);
  // Solo pasos reales (sin Resultado final/directo) para UI compacta
  List<AnimationStep> get _displaySteps =>
      _steps.where((s) => s.label.startsWith('Paso')).toList();

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux);

  Future<void> _pickImage(ImageSource src) async {
    // Desktop: cámara no disponible vía image_picker (cameraDelegate). Alternativa: file_selector.
    if (_isDesktop && src == ImageSource.camera) {
      await _pickViaFileSelectorAsCameraFallback();
      return;
    }
    try {
      final x = await _picker.pickImage(source: src, imageQuality: 100);
      if (x == null) return;
      setState(() {
        _imagePath = x.path;
        _imageName = p.basename(x.path);
      });
    } on StateError catch (e) {
      // Maneja Bad state: This implementation requires a cameraDelegate (Windows)
      if (_isDesktop) {
        await _pickViaFileSelectorAsCameraFallback();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir cámara: $e. Usa Galería.')),
        );
      }
    } on MissingPluginException {
      if (_isDesktop) {
        await _pickViaFileSelectorAsCameraFallback();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _pickViaFileSelectorAsCameraFallback() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cámara no disponible en Windows/Linux. Abriendo selector de archivos como alternativa.',
        ),
      ),
    );
    try {
      const typeGroup = fs.XTypeGroup(
        label: 'Imágenes',
        extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );
      final file = await fs.openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      setState(() {
        _imagePath = file.path;
        _imageName = p.basename(file.path);
      });
    } catch (e) {
      // Fallback final: image_picker gallery
      try {
        final x = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 100,
        );
        if (x == null) return;
        setState(() {
          _imagePath = x.path;
          _imageName = p.basename(x.path);
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir selector: $e')),
          );
        }
      }
    }
  }

  Future<void> _cropImage() async {
    if (_imagePath == null) return;
    if (_isDesktop) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recorte no disponible en Windows/Linux (image_cropper sin plugin desktop). Usa una app externa y vuelve a cargar la imagen.',
            ),
          ),
        );
      }
      return;
    }
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _imagePath!,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar',
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: 'Recortar'),
        ],
      );
      if (cropped != null) setState(() => _imagePath = cropped.path);
    } catch (e) {
      if (mounted) {
        final msg = e is MissingPluginException
            ? 'Recorte no soportado en esta plataforma.'
            : 'Error al recortar: $e';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  void _addOrSave() {
    final v = parseDegreesInput(_degreesCtrl.text);
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa grados válidos (≥0)')),
      );
      return;
    }
    setState(() {
      if (_editingIndex != null) {
        _ops[_editingIndex!] = RotationOperation(degrees: v, direction: _dir);
        _editingIndex = null;
      } else {
        _ops.add(RotationOperation(degrees: v, direction: _dir));
      }
    });
  }

  Future<void> _exportFinal() async {
    if (_imagePath == null) return;
    try {
      setState(() => _exportProgress = 0.1);
      // Extraer valores sendables antes del Isolate: la closure no debe capturar `this`/WidgetsBinding
      final String inputPath = _imagePath!;
      final double angle = _totalAngle;
      final String outName = 'rotado_${DateTime.now().millisecondsSinceEpoch}';
      final task = ExportTask(inputPath: inputPath, angleDegrees: angle, outputName: outName, quality: 95, format: 'jpg');
      final res = await Isolate.run(() => exportImageTask(task));
      setState(() => _exportProgress = 0.9);
      String savedPath;
      String msg;
      if (_isDesktop) {
        // Windows/Linux: file_selector save dialog (gal no fiable)
        try {
          final location = await fs.getSaveLocation(
            suggestedName: p.basename(res.outputPath),
            acceptedTypeGroups: const [
              fs.XTypeGroup(label: 'JPEG', extensions: ['jpg', 'jpeg']),
            ],
          );
          if (location == null) {
            savedPath = await GalleryService.saveImage(res.outputPath);
            msg = 'Guardado en $savedPath — elige ubicación para la próxima';
          } else {
            final dest = p.join(location.path, p.basename(res.outputPath));
            // getSaveLocation en Windows devuelve path sin extensión si el usuario no elige, usar save
            final target = location.path.endsWith('.jpg') || location.path.endsWith('.jpeg') ? location.path : dest;
            await File(res.outputPath).copy(target);
            savedPath = target;
            msg = 'Imagen guardada en $savedPath (calidad 95)';
          }
        } catch (_) {
          savedPath = await GalleryService.saveImage(res.outputPath);
          msg = 'Imagen guardada en $savedPath (calidad 95)';
        }
      } else {
        savedPath = await GalleryService.saveImage(res.outputPath);
        msg = 'Imagen guardada en galería (calidad 95)';
      }
      await HistoryService.save(
        HistoryEntry(
          id: '',
          createdAt: 0,
          name: _imageName,
          imageOriginal: _imagePath!,
          imageResult: res.outputPath,
          operations: List.from(_ops),
          totalAngle: _totalAngle,
          normalizedAngle: _normalized,
          formula: _formula,
          showTrace: _showTrace,
          includeDirect: _includeDirect,
        ),
      );
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        setState(() => _exportProgress = 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error exportando: $e')));
      }
      setState(() => _exportProgress = 0);
    }
  }

  Future<void> _exportZip() async {
    if (_imagePath == null || _displaySteps.isEmpty) return;
    try {
      setState(() => _exportProgress = 0.05);
      // ZIP solo pasos reales, sin holds ni duplicados (trazos va aparte)
      final steps = _displaySteps;
      final angles = steps.map((s) => s.toAngle).toList();
      final labels = steps.map((s) => s.label).toList();
      final dir = await getTemporaryDirectory();
      final List<String> pngPaths = [];
      final String zipInputPath = _imagePath!;
      for (var i = 0; i < angles.length; i++) {
        setState(() => _exportProgress = 0.05 + 0.8 * (i / angles.length));
        // Extraer task fuera de la closure: Isolate.run no puede capturar `this`/WidgetsBinding
        final double angleAtI = angles[i];
        final String outNameAtI = 'paso_${i}_${DateTime.now().millisecondsSinceEpoch}';
        final taskAtI = ExportTask(inputPath: zipInputPath, angleDegrees: angleAtI, outputName: outNameAtI, quality: 95, format: 'png');
        final r = await Isolate.run(() => exportImageTask(taskAtI));
        final safe = labels[i]
            .replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúñÁÉÍÓÚÑ \-]'), '')
            .trim();
        final newName = '${(i + 1).toString().padLeft(2, '0')}-$safe.png';
        final newPath = p.join(dir.path, newName);
        await File(r.outputPath).rename(newPath);
        pngPaths.add(newPath);
      }
      setState(() => _exportProgress = 0.9);
      final archive = Archive();
      for (final path in pngPaths) {
        final bytes = await File(path).readAsBytes();
        archive.addFile(ArchiveFile(p.basename(path), bytes.length, bytes));
      }
      final zipBytes = ZipEncoder().encode(archive);
      final zipPath = p.join(
        dir.path,
        'pasos-rotacion-${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      await File(zipPath).writeAsBytes(zipBytes);
      if (_isDesktop) {
        try {
          final location = await fs.getSaveLocation(
            suggestedName: p.basename(zipPath),
            acceptedTypeGroups: const [fs.XTypeGroup(label: 'ZIP', extensions: ['zip'])],
          );
          if (location != null) {
            final target = location.path.endsWith('.zip') ? location.path : p.join(location.path, p.basename(zipPath));
            // Si el usuario eligió directorio, copiar ahí
            final dest = File(target);
            if (await dest.exists()) await dest.delete();
            await File(zipPath).copy(target);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP guardado en $target (${pngPaths.length} pasos)')));
            }
          } else {
            // Canceló: guardar en Downloads como fallback
            final fallback = await GalleryService.saveImage(zipPath);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP guardado en $fallback (${pngPaths.length} pasos)')));
            }
          }
        } catch (_) {
          // Fallback share (puede fallar en Windows sin handler)
          try {
            await SharePlus.instance.share(ShareParams(files: [XFile(zipPath)], text: 'Pasos rotación $_formula'));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP en $zipPath (${pngPaths.length} pasos) - error compartir: $e')));
          }
        }
      } else {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(zipPath)], text: 'Pasos rotación $_formula'),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ZIP con ${pngPaths.length} pasos compartido'),
            ),
          );
        }
      }
      setState(() => _exportProgress = 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error ZIP: $e')));
      }
      setState(() => _exportProgress = 0);
    }
  }

  void _clearAll() {
    setState(() {
      _ops.clear();
      _editingIndex = null;
      _degreesCtrl.text = '90';
      _dir = RotationDirection.cw;
    });
  }

  String _formatDate(int ms) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(ms)
          .toLocal()
          .toString()
          .split('.')
          .first;
    } catch (_) {
      return '$ms';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imagePath != null;
    final canApply = hasImage && _ops.isNotEmpty;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_192.png',
              width: 32,
              height: 32,
              errorBuilder: (_, _, _) => const Icon(Icons.rotate_90_degrees_cw),
            ),
            const SizedBox(width: 10),
            const Text('Rotador Imágenes'),
          ],
        ),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeModeNotifier,
            builder: (context, mode, _) {
              return IconButton(
                icon: Icon(ThemeService.icon),
                tooltip: 'Tema: ${ThemeService.label} (tocar para cambiar)',
                onPressed: () async {
                  await ThemeService.cycleTheme();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tema: ${ThemeService.label}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              );
            },
          ),
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Limpiar todo',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Imagen — inicio directo (sin header web)
            Text(
              '1. Selecciona tu imagen',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (_isDesktop)
              FilledButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Seleccionar imagen'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
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
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Cámara'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _cropImage,
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
                  imagePath: _imagePath!,
                  angleDegrees: _totalAngle,
                  showTrace: _showTrace,
                  traceMode: _includeDirect && _normalized != _totalAngle
                      ? TraceMode.direct
                      : TraceMode.cumulative,
                  cacheWidth: 720,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _imageName,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            // 2. Operaciones
            Text(
              '2. Operaciones de rotación',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (_ops.isEmpty)
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
            ..._ops.asMap().entries.map((e) {
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
                        onPressed: i == 0
                            ? null
                            : () => setState(() {
                                final tmp = _ops[i - 1];
                                _ops[i - 1] = _ops[i];
                                _ops[i] = tmp;
                              }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: i == _ops.length - 1
                            ? null
                            : () => setState(() {
                                final t = _ops[i + 1];
                                _ops[i + 1] = _ops[i];
                                _ops[i] = t;
                              }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => setState(() {
                          _degreesCtrl.text = op.degrees.toString();
                          _dir = op.direction;
                          _editingIndex = i;
                        }),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: cs.error),
                        onPressed: () {
                          setState(() {
                            if (_editingIndex == i) {
                              _editingIndex = null;
                            } else if (_editingIndex case final idx?
                                when idx > i) {
                              _editingIndex = idx - 1;
                            }
                            _ops.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Card(
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
                            controller: _degreesCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
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
                            initialValue: _dir,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Dirección',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: RotationDirection.cw,
                                child: Text(
                                  'Horario',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: RotationDirection.ccw,
                                child: Text(
                                  'Antihorario',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _dir = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _addOrSave,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _editingIndex == null ? 'Agregar' : 'Guardar',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Opciones - fix ListTile inside DecoratedBox: usar Card + Material
            Card(
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
                      value: _showTrace,
                      onChanged: (v) => setState(() => _showTrace = v!),
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
                      value: _includeDirect,
                      onChanged: (v) => setState(() => _includeDirect = v!),
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
            ),
            const SizedBox(height: 16),
            // Acciones — preview es automático (Transform.rotate), botones uniformes
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canApply ? _exportFinal : null,
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
                    onPressed: canApply ? _exportZip : null,
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
            if (_exportProgress > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _exportProgress),
              const SizedBox(height: 4),
              Text(
                '${(_exportProgress * 100).toInt()}%',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            // Resultado
            if (canApply) ...[
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
                'Rotación total: ${_totalAngle.toStringAsFixed(_totalAngle.truncateToDouble() == _totalAngle ? 0 : 1).replaceAll('.0', '')}° ${_normalized != _totalAngle ? '(${_normalized.toStringAsFixed(_normalized.truncateToDouble() == _normalized ? 0 : 1).replaceAll('.0', '')}° efectivos)' : ''}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formula,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: Text(
                  'Ver desglose paso a paso (${_displaySteps.length} pasos)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                children: _displaySteps.map((s) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                                Text(
                                  s.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '${s.toAngle.toStringAsFixed(1).replaceAll('.0', '')}°',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 130,
                              child: hasImage
                                  ? ImagePreview(
                                      imagePath: _imagePath!,
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
              if (_showTrace) ...[
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
                                imagePath: _imagePath!,
                                angleDegrees: _totalAngle,
                                showTrace: true,
                                traceMode: TraceMode.cumulative,
                              )
                            : const SizedBox(),
                      ),
                    ),
                    if (_includeDirect) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 160,
                          child: hasImage
                              ? ImagePreview(
                                  imagePath: _imagePath!,
                                  angleDegrees: _normalized,
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
                        'Acumulado: $_totalAngle°',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (_includeDirect)
                      Expanded(
                        child: Text(
                          'Directo: $_normalized°',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 24),
            // Historial
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Historial',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Chip(
                      label: Text(
                        '${_history.length}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _history.isEmpty
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Borrar historial'),
                              content: const Text('¿Borrar todo?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Borrar'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await HistoryService.clear();
                            await _loadHistory();
                          }
                        },
                  child: Text('Limpiar', style: TextStyle(color: cs.error)),
                ),
              ],
            ),
            if (_history.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: cs.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Aún no hay elementos. La vista previa es automática; al guardar se creará el historial (Hive local, 100 máx).',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ..._history.map(
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
                          Text(
                            _formatDate(e.createdAt),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${e.operations.length} op · ${e.totalAngle}° → ${e.normalizedAngle}°',
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.formula,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Inicial',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(e.imageOriginal),
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.image),
                                  ),
                                ),
                                Text(
                                  e.name,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Resultado',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(e.imageResult),
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.image),
                                  ),
                                ),
                                Text(
                                  '${e.showTrace ? 'con trazo' : 'sin trazo'}${e.includeDirect ? ' · directo' : ''}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: e.operations
                            .map(
                              (op) => Chip(
                                label: Text(
                                  '${op.degrees}° ${op.direction == RotationDirection.cw ? 'horario' : 'antihorario'}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _imagePath = e.imageOriginal;
                                  _imageName = e.name;
                                  _ops
                                    ..clear()
                                    ..addAll(
                                      e.operations.map(
                                        (o) => RotationOperation(
                                          degrees: o.degrees,
                                          direction: o.direction,
                                        ),
                                      ),
                                    );
                                  _showTrace = e.showTrace;
                                  _includeDirect = e.includeDirect;
                                });
                              },
                              child: const Text(
                                'Restaurar',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              await HistoryService.delete(e.id);
                              await _loadHistory();
                            },
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Imágenes guardadas localmente con Hive (no se suben al servidor). Máx 100.',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
