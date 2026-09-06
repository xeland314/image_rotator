import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/feature_flags.dart';
import '../models/history_entry.dart';
import '../models/rotation_operation.dart';
import '../services/export_service.dart';
import '../services/gallery_service.dart';
import '../services/history_service.dart';
import '../services/rotation_logic.dart';
import '../services/theme_service.dart';
import 'components/history_section.dart';
import 'components/image_section.dart';
import 'components/operations_section.dart';
import 'components/options_export_section.dart';
import 'components/result_section.dart';

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
  List<AnimationStep> get _steps => buildAnimationSteps(_ops, includeDirectScene: _includeDirect);
  List<AnimationStep> get _displaySteps => _steps.where((s) => s.label.startsWith('Paso')).toList();
  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux);

  // --- lógica de imagen (feature flags) ---
  Future<void> _pickImage(ImageSource src) async {
    if (!FeatureFlags.enableCamera && src == ImageSource.camera) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cámara desactivada por feature flag (ENABLE_CAMERA=false). Usa Galería.')),
        );
      }
      return;
    }
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
      if (_isDesktop) {
        await _pickViaFileSelectorAsCameraFallback();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir cámara: $e. Usa Galería.')));
      }
    } on MissingPluginException {
      if (_isDesktop) await _pickViaFileSelectorAsCameraFallback();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar imagen: $e')));
    }
  }

  Future<void> _pickViaFileSelectorAsCameraFallback() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cámara no disponible en Windows/Linux. Abriendo selector de archivos como alternativa.')),
    );
    try {
      const typeGroup = fs.XTypeGroup(label: 'Imágenes', extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp']);
      final file = await fs.openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      setState(() {
        _imagePath = file.path;
        _imageName = p.basename(file.path);
      });
    } catch (e) {
      try {
        final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
        if (x == null) return;
        setState(() {
          _imagePath = x.path;
          _imageName = p.basename(x.path);
        });
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir selector: $e')));
      }
    }
  }

  Future<void> _cropImage() async {
    if (!FeatureFlags.enableCrop) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recorte desactivado por feature flag (ENABLE_CROP=false). Activa con --dart-define=ENABLE_CROP=true')),
        );
      }
      return;
    }
    if (_imagePath == null) return;
    if (_isDesktop) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recorte no disponible en Windows/Linux (image_cropper sin plugin desktop). Usa una app externa y vuelve a cargar la imagen.')),
        );
      }
      return;
    }
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _imagePath!,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Recortar', lockAspectRatio: false, hideBottomControls: false),
          IOSUiSettings(title: 'Recortar'),
          if (kIsWeb) WebUiSettings(context: context),
        ],
      );
      if (cropped != null) setState(() => _imagePath = cropped.path);
    } catch (e) {
      if (mounted) {
        final msg = e is MissingPluginException ? 'Recorte no soportado en esta plataforma.' : 'Error al recortar: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  void _addOrSave() {
    final v = parseDegreesInput(_degreesCtrl.text);
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa grados válidos (≥0)')));
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
      final res = await ExportService.exportSingle(inputPath: _imagePath!, angleDegrees: _totalAngle);
      setState(() => _exportProgress = 0.9);
      String savedPath;
      String msg;
      if (_isDesktop) {
        try {
          final location = await fs.getSaveLocation(
            suggestedName: p.basename(res.outputPath),
            acceptedTypeGroups: const [fs.XTypeGroup(label: 'JPEG', extensions: ['jpg', 'jpeg'])],
          );
          if (location == null) {
            savedPath = await GalleryService.saveImage(res.outputPath);
            msg = 'Guardado en $savedPath — elige ubicación para la próxima';
          } else {
            final dest = p.join(location.path, p.basename(res.outputPath));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exportando: $e')));
      setState(() => _exportProgress = 0);
    }
  }

  Future<void> _exportZip() async {
    if (_imagePath == null || _displaySteps.isEmpty) return;
    try {
      setState(() => _exportProgress = 0.05);
      final steps = _displaySteps;
      final angles = steps.map((s) => s.toAngle).toList();
      final labels = steps.map((s) => s.label).toList();
      final zipPath = await ExportService.exportZip(
        inputPath: _imagePath!,
        angles: angles,
        labels: labels,
        onProgress: (v) => mounted ? setState(() => _exportProgress = v) : null,
      );
      if (_isDesktop) {
        try {
          final location = await fs.getSaveLocation(
            suggestedName: p.basename(zipPath),
            acceptedTypeGroups: const [fs.XTypeGroup(label: 'ZIP', extensions: ['zip'])],
          );
          if (location != null) {
            final target = location.path.endsWith('.zip') ? location.path : p.join(location.path, p.basename(zipPath));
            final dest = File(target);
            if (await dest.exists()) await dest.delete();
            await File(zipPath).copy(target);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP guardado en $target (${angles.length} pasos)')));
          } else {
            final fallback = await GalleryService.saveImage(zipPath);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP guardado en $fallback (${angles.length} pasos)')));
          }
        } catch (_) {
          try {
            await SharePlus.instance.share(ShareParams(files: [XFile(zipPath)], text: 'Pasos rotación $_formula'));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP en $zipPath (${angles.length} pasos) - error compartir: $e')));
          }
        }
      } else {
        await SharePlus.instance.share(ShareParams(files: [XFile(zipPath)], text: 'Pasos rotación $_formula'));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP con ${angles.length} pasos compartido')));
      }
      setState(() => _exportProgress = 0);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error ZIP: $e')));
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

  Future<void> _openOriginalApp() async {
    final uri = Uri.parse('https://xeland314.github.io/rotador-imagenes/');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir $uri')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error abriendo link: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imagePath != null;
    final canApply = hasImage && _ops.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo_192.png', width: 32, height: 32, errorBuilder: (_, _, _) => const Icon(Icons.rotate_90_degrees_cw)),
            const SizedBox(width: 10),
            const Text('Rotador Imágenes'),
          ],
        ),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeModeNotifier,
            builder: (context, mode, _) => IconButton(
              icon: Icon(ThemeService.icon),
              tooltip: 'Tema: ${ThemeService.label} (tocar para cambiar)',
              onPressed: () async {
                await ThemeService.cycleTheme();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tema: ${ThemeService.label}'), duration: const Duration(seconds: 1)));
                }
              },
            ),
          ),
          IconButton(onPressed: _clearAll, icon: const Icon(Icons.delete_sweep), tooltip: 'Limpiar todo'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ImageSection(
              hasImage: hasImage,
              imagePath: _imagePath,
              imageName: _imageName,
              isDesktop: _isDesktop,
              totalAngle: _totalAngle,
              showTrace: _showTrace,
              includeDirect: _includeDirect,
              normalized: _normalized,
              onPickGallery: () => _pickImage(ImageSource.gallery),
              onPickCamera: () => _pickImage(ImageSource.camera),
              onCrop: _cropImage,
            ),
            const SizedBox(height: 20),
            OperationsSection(
              ops: _ops,
              onMoveUp: (i) => setState(() {
                final tmp = _ops[i - 1];
                _ops[i - 1] = _ops[i];
                _ops[i] = tmp;
              }),
              onMoveDown: (i) => setState(() {
                final t = _ops[i + 1];
                _ops[i + 1] = _ops[i];
                _ops[i] = t;
              }),
              onEdit: (i) => setState(() {
                _degreesCtrl.text = _ops[i].degrees.toString();
                _dir = _ops[i].direction;
                _editingIndex = i;
              }),
              onDelete: (i) => setState(() {
                if (_editingIndex == i) {
                  _editingIndex = null;
                } else if (_editingIndex case final idx? when idx > i) {
                  _editingIndex = idx - 1;
                }
                _ops.removeAt(i);
              }),
            ),
            const SizedBox(height: 8),
            OperationInput(
              degreesCtrl: _degreesCtrl,
              direction: _dir,
              isEditing: _editingIndex != null,
              onDirectionChanged: (v) => setState(() => _dir = v),
              onSubmit: _addOrSave,
            ),
            const SizedBox(height: 16),
            OptionsSection(
              showTrace: _showTrace,
              includeDirect: _includeDirect,
              onShowTraceChanged: (v) => setState(() => _showTrace = v),
              onIncludeDirectChanged: (v) => setState(() => _includeDirect = v),
            ),
            const SizedBox(height: 16),
            ExportSection(canApply: canApply, exportProgress: _exportProgress, onExportFinal: _exportFinal, onExportZip: _exportZip),
            const SizedBox(height: 20),
            ResultSection(
              canApply: canApply,
              totalAngle: _totalAngle,
              normalized: _normalized,
              formula: _formula,
              displaySteps: _displaySteps,
              hasImage: hasImage,
              imagePath: _imagePath,
              showTrace: _showTrace,
              includeDirect: _includeDirect,
            ),
            const SizedBox(height: 24),
            HistorySection(
              history: _history,
              onRestore: (e) => setState(() {
                _imagePath = e.imageOriginal;
                _imageName = e.name;
                _ops
                  ..clear()
                  ..addAll(e.operations.map((o) => RotationOperation(degrees: o.degrees, direction: o.direction)));
                _showTrace = e.showTrace;
                _includeDirect = e.includeDirect;
              }),
              onRefresh: _loadHistory,
            ),
            const SizedBox(height: 32),
            const Divider(),
            // Footer portfolio — versión web original (Astro SEO) para publicidad portafolio
            Center(
              child: Column(
                children: [
                  Text(
                    '¿Prefieres la versión web?',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _openOriginalApp,
                    icon: const Icon(Icons.public, size: 18),
                    label: const Text('Abrir app original en Astro — xeland314.github.io/rotador-imagenes'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Portafolio: xeland314.github.io • Herramienta educativa de razonamiento abstracto',
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
