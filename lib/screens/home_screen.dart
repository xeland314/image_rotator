import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_entry.dart';
import '../models/rotation_operation.dart';
import '../services/history_service.dart';
import '../services/image_processor.dart';
import '../services/rotation_logic.dart';
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
  bool _isApplying = false;
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

  Future<void> _pickImage(ImageSource src) async {
    final x = await _picker.pickImage(source: src, imageQuality: 100);
    if (x == null) return;
    setState(() {
      _imagePath = x.path;
      _imageName = p.basename(x.path);
    });
  }

  Future<void> _cropImage() async {
    if (_imagePath == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: _imagePath!,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Recortar', lockAspectRatio: false, hideBottomControls: false),
        IOSUiSettings(title: 'Recortar'),
      ],
    );
    if (cropped != null) setState(() => _imagePath = cropped.path);
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

  Future<void> _applyRotations() async {
    if (_imagePath == null || _ops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carga imagen y agrega una operación')));
      return;
    }
    setState(() => _isApplying = true);
    // Guardar en historial (equivalente a saveHistoryEntry con IndexedDB)
    try {
      // generar preview resultado en Isolate para historial (calidad 85 jpg como en web)
      final resultPath = await Isolate.run(() => exportImageTask(ExportTask(
            inputPath: _imagePath!,
            angleDegrees: _totalAngle,
            outputName: 'hist_${DateTime.now().millisecondsSinceEpoch}',
            quality: 85,
            format: 'jpg',
          )));
      await HistoryService.save(HistoryEntry(
        id: '',
        createdAt: 0,
        name: _imageName,
        imageOriginal: _imagePath!,
        imageResult: resultPath.outputPath,
        operations: List.from(_ops),
        totalAngle: _totalAngle,
        normalizedAngle: _normalized,
        formula: _formula,
        showTrace: _showTrace,
        includeDirect: _includeDirect,
      ));
      await _loadHistory();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rotación aplicada y guardada en historial')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _exportFinal() async {
    if (_imagePath == null) return;
    try {
      setState(() => _exportProgress = 0.1);
      final res = await Isolate.run(() => exportImageTask(ExportTask(
            inputPath: _imagePath!,
            angleDegrees: _totalAngle,
            outputName: 'rotado_${DateTime.now().millisecondsSinceEpoch}',
            quality: 95,
            format: 'jpg',
          )));
      setState(() => _exportProgress = 0.9);
      // Guardar en galería con Gal (respeta Scoped Storage)
      await Gal.putImage(res.outputPath);
      // También compartir opcional
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen guardada en galería (calidad 95)')));
        setState(() => _exportProgress = 0);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exportando: $e')));
      setState(() => _exportProgress = 0);
    }
  }

  Future<void> _exportZip() async {
    if (_imagePath == null || _steps.isEmpty) return;
    try {
      setState(() => _exportProgress = 0.05);
      final steps = _steps.where((s) => s.label != 'Resultado directo (efectivo)' || _includeDirect).toList();
      // Generar PNGs en Isolate y luego empaquetar ZIP en UI thread
      final angles = steps.map((s) => s.toAngle).toList();
      final labels = steps.map((s) => s.label).toList();
      // Usamos exportImageTask por cada paso en Isolate secuencial para no saturar RAM
      final dir = await getTemporaryDirectory();
      final List<String> pngPaths = [];
      for (var i = 0; i < angles.length; i++) {
        setState(() => _exportProgress = 0.05 + 0.8 * (i / angles.length));
        final r = await Isolate.run(() => exportImageTask(ExportTask(
              inputPath: _imagePath!,
              angleDegrees: angles[i],
              outputName: 'paso_${i}_${DateTime.now().millisecondsSinceEpoch}',
              quality: 95,
              format: 'png',
            )));
        // renombrar con label seguro
        final safe = labels[i].replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúñÁÉÍÓÚÑ \-]'), '').trim();
        final newName = '${(i + 1).toString().padLeft(2, '0')}-$safe.png';
        final newPath = p.join(dir.path, newName);
        await File(r.outputPath).rename(newPath);
        pngPaths.add(newPath);
      }
      // Crear ZIP
      setState(() => _exportProgress = 0.9);
      final archive = Archive();
      for (final path in pngPaths) {
        final bytes = await File(path).readAsBytes();
        archive.addFile(ArchiveFile(p.basename(path), bytes.length, bytes));
      }
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('ZIP encode falló');
      final zipPath = p.join(dir.path, 'pasos-rotacion-${DateTime.now().millisecondsSinceEpoch}.zip');
      await File(zipPath).writeAsBytes(zipBytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(zipPath)], text: 'Pasos rotación $_formula'));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP con ${pngPaths.length} pasos compartido')));
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

  String _formatDate(int ms) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(ms).toLocal().toString().split('.').first;
    } catch (_) {
      return '$ms';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imagePath != null;
    final canApply = hasImage && _ops.isNotEmpty;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/images/logo_192.png', width: 32, height: 32, errorBuilder: (_, __, ___) => const Icon(Icons.rotate_90_degrees_cw)),
          const SizedBox(width: 10),
          const Text('Rotador Multi-Giro'),
        ]),
        actions: [
          IconButton(onPressed: _clearAll, icon: const Icon(Icons.delete_sweep), tooltip: 'Limpiar todo'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.withOpacity(0.3))), child: const Text('HERRAMIENTA DE IMÁGENES', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.blue, fontWeight: FontWeight.bold))),
              const SizedBox(height: 10),
              Text('Rotador de Imágenes Multi-Giro', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Carga una imagen y aplica múltiples operaciones concatenadas. Cada giro se aplica sobre el anterior (ej. 900°+770°).', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
            ]),
          ),
          const SizedBox(height: 20),
          // 1. Imagen
          Text('1. Selecciona tu imagen', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('Galería'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.photo_camera), label: const Text('Cámara'))),
            if (hasImage) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: _cropImage, icon: const Icon(Icons.crop), tooltip: 'Recortar (uCrop nativo)'),
            ]
          ]),
          if (hasImage) ...[
            const SizedBox(height: 12),
            Container(
              height: 220,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: ImagePreview(imagePath: _imagePath!, angleDegrees: _totalAngle, showTrace: _showTrace, traceMode: _includeDirect && _normalized != _totalAngle ? TraceMode.direct : TraceMode.cumulative, cacheWidth: 720),
            ),
            const SizedBox(height: 6),
            Text(_imageName, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          // 2. Operaciones
          Text('2. Operaciones de rotación', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          if (_ops.isEmpty) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: const Text('No hay operaciones. Agrega una abajo.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
          ..._ops.asMap().entries.map((e) {
            final i = e.key;
            final op = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: Text('${i + 1}', style: const TextStyle(fontFamily: 'monospace', color: Colors.grey)),
                title: Text('${op.degrees.toStringAsFixed(op.degrees.truncateToDouble()==op.degrees?0:1).replaceAll('.0','')}° ${parseDirection(op.direction)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Wrap(spacing: 0, children: [
                  IconButton(icon: const Icon(Icons.arrow_upward, size: 18), onPressed: i == 0 ? null : () => setState(() { final tmp=_ops[i-1]; _ops[i-1]=_ops[i]; _ops[i]=tmp; })),
                  IconButton(icon: const Icon(Icons.arrow_downward, size: 18), onPressed: i==_ops.length-1?null:()=>setState((){final t=_ops[i+1]; _ops[i+1]=_ops[i]; _ops[i]=t;})),
                  IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => setState((){ _degreesCtrl.text=op.degrees.toString(); _dir=op.direction; _editingIndex=i; })),
                  IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red), onPressed: ()=>setState((){
                    if(_editingIndex==i) _editingIndex=null; else if(_editingIndex!=null && _editingIndex! > i) _editingIndex=_editingIndex!-1;
                    _ops.removeAt(i);
                  })),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: TextField(controller: _degreesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Grados', border: OutlineInputBorder(), isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<RotationDirection>(value: _dir, decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder(), isDense: true), items: const [DropdownMenuItem(value: RotationDirection.cw, child: Text('Horario')), DropdownMenuItem(value: RotationDirection.ccw, child: Text('Antihorario'))], onChanged: (v)=>setState(()=>_dir=v!))),
              const SizedBox(width: 8),
              FilledButton(onPressed: _addOrSave, child: Text(_editingIndex==null?'Agregar':'Guardar')),
            ]),
          ),
          const SizedBox(height: 16),
          // Opciones
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
            child: Column(children: [
              CheckboxListTile(value: _showTrace, onChanged: (v)=>setState(()=>_showTrace=v!), title: const Text('Trazar arco (goniómetro con vueltas)', style: TextStyle(fontSize: 13)), dense: true, controlAffinity: ListTileControlAffinity.leading),
              CheckboxListTile(value: _includeDirect, onChanged: (v)=>setState(()=>_includeDirect=v!), title: const Text('Incluir resultado directo (ángulo efectivo)', style: TextStyle(fontSize: 13)), dense: true, controlAffinity: ListTileControlAffinity.leading),
            ]),
          ),
          const SizedBox(height: 16),
          // Acciones
          FilledButton.icon(onPressed: canApply && !_isApplying ? _applyRotations : null, icon: _isApplying ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color: Colors.white)) : const Icon(Icons.check), label: Text(_isApplying ? 'Aplicando...' : 'Aplicar rotaciones')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: canApply ? _exportFinal : null, icon: const Icon(Icons.save_alt), label: const Text('Guardar en galería'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: canApply ? _exportZip : null, icon: const Icon(Icons.folder_zip), label: const Text('ZIP pasos'))),
          ]),
          if (_exportProgress > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _exportProgress),
            const SizedBox(height: 4),
            Text('${(_exportProgress*100).toInt()}%', style: const TextStyle(fontFamily: 'monospace', fontSize: 11), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          // Resultado
          if (canApply) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text('Resultado final', style: theme.textTheme.labelSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Text('Rotación total: ${_totalAngle.toStringAsFixed(_totalAngle.truncateToDouble()==_totalAngle?0:1).replaceAll('.0','')}° ${_normalized!=_totalAngle ? '(${_normalized.toStringAsFixed(_normalized.truncateToDouble()==_normalized?0:1).replaceAll('.0','')}° efectivos)' : ''}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w300)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Text(_formula, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
            const SizedBox(height: 12),
            ExpansionTile(title: Text('Ver desglose paso a paso (${_steps.length} pasos)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), children: _steps.map((s){
              // Mostrar cada paso con preview rotado (Transform.rotate liviano)
              final isHold = s.label=='Resultado final';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(s.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('${s.toAngle.toStringAsFixed(1).replaceAll('.0','')}°', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 8),
                  SizedBox(height: 130, child: hasImage ? ImagePreview(imagePath: _imagePath!, angleDegrees: s.toAngle, showTrace: false, cacheWidth: 400) : const SizedBox()),
                ]))),
              );
            }).toList()),
            if (_showTrace) ...[
              const SizedBox(height: 12),
              Text('Trazos', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: SizedBox(height: 160, child: hasImage ? ImagePreview(imagePath: _imagePath!, angleDegrees: _totalAngle, showTrace: true, traceMode: TraceMode.cumulative) : const SizedBox())),
                if (_includeDirect) ...[const SizedBox(width: 8), Expanded(child: SizedBox(height: 160, child: hasImage ? ImagePreview(imagePath: _imagePath!, angleDegrees: _normalized, showTrace: true, traceMode: TraceMode.direct) : const SizedBox()))],
              ]),
              const SizedBox(height: 4),
              Row(children: [Expanded(child: Text('Acumulado: ${_totalAngle}°', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey))), if(_includeDirect) Expanded(child: Text('Directo: ${_normalized}°', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)))]),
            ],
          ],
          const SizedBox(height: 24),
          // Historial
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [const Text('Historial', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)), const SizedBox(width: 6), Chip(label: Text('${_history.length}', style: const TextStyle(fontSize: 10)), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)]),
            TextButton(onPressed: _history.isEmpty?null:()async{ final ok=await showDialog<bool>(context: context, builder: (_)=>AlertDialog(title: const Text('Borrar historial'), content: const Text('¿Borrar todo?'), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancelar')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Borrar'))])); if(ok==true){await HistoryService.clear(); await _loadHistory();}}, child: const Text('Limpiar', style: TextStyle(color: Colors.red))),
          ]),
          if (_history.isEmpty) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)), child: const Text('Aún no hay elementos. Aplica una rotación y se guardará automáticamente (Hive local, 100 máx).', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12), textAlign: TextAlign.center)),
          ..._history.map((e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_formatDate(e.createdAt), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('${e.operations.length} op · ${e.totalAngle}° → ${e.normalizedAngle}°', style: const TextStyle(fontSize: 10, color: Colors.blue))),
                    ]),
                    const SizedBox(height: 4),
                    Text(e.formula, style: const TextStyle(fontFamily: 'monospace', fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: Column(children: [const Text('Inicial', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 4), ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(e.imageOriginal), height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))), Text(e.name, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                      const SizedBox(width: 8),
                      Expanded(child: Column(children: [const Text('Resultado', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 4), ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(e.imageResult), height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))), Text('${e.showTrace?'con trazo':'sin trazo'}${e.includeDirect?' · directo':''}', style: const TextStyle(fontSize: 9, color: Colors.grey))])),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 4, children: e.operations.map((op)=>Chip(label: Text('${op.degrees}° ${op.direction==RotationDirection.cw?'horario':'antihorario'}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero)).toList()),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: FilledButton(onPressed: ()=>setState((){ _imagePath=e.imageOriginal; _imageName=e.name; _ops..clear()..addAll(e.operations.map((o)=>RotationOperation(degrees: o.degrees, direction: o.direction))); _showTrace=e.showTrace; _includeDirect=e.includeDirect; }), child: const Text('Restaurar', style: TextStyle(fontSize: 12)))),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: ()async{ await HistoryService.delete(e.id); await _loadHistory(); }, child: const Text('Eliminar', style: TextStyle(fontSize: 12))),
                    ]),
                  ]),
                ),
              )),
          const SizedBox(height: 12),
          Center(child: Text('Imágenes guardadas localmente con Hive (no se suben al servidor). Máx 100.', style: TextStyle(fontSize: 10, color: Colors.grey[500]))),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}
