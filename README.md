# Rotador de Imágenes — Image Rotator (Flutter)

Migración completa a **Flutter** de la herramienta web `rotador-imagenes` del portafolio [xeland314.github.io](https://xeland314.github.io/rotador-imagenes) (`src/components/tools/rotador-imagenes/`).

> **Web (Astro + TS)** se mantiene para SEO. **Móvil/Desktop (Flutter)** es la versión nativa para App Store / Google Play con rendimiento hardware (Impeller/Skia), gestos nativos y procesamiento en `Isolate`.

## Qué hace
Carga una imagen y aplica **múltiples rotaciones concatenadas** (ej. `900° horario + 770° horario = 1670° → 230° efectivos`). Visualiza cada paso, traza goniómetro con vueltas y exporta resultado en alta calidad sin congelar la UI.

Paridad 1:1 con la web:
- `rotador.ts:32` `calculateTotalAngle`, `normalizeAngle`, `formatFormula`, `buildAnimationSteps`, `resolveAngleAtTime` → `lib/services/rotation_logic.dart:1`
- `canvas.ts:28` `drawRotatedImage`, `drawTraceLayer`, `exportVideo/ZIP` → `lib/widgets/trace_painter.dart:8` + `lib/services/image_processor.dart:24`
- `history.ts:36` IndexedDB (100 entradas) → `lib/services/history_service.dart:1` con `hive_flutter`

## Stack elegido (criterio del portafolio)

| Tarea | Paquete | Por qué |
|-------|---------|---------|
| Selección | `image_picker` | Retorna `XFile` path sin cargar bytes en Dart RAM |
| Procesamiento | `image` (Pure Dart) | Rotación en ángulo libre, `quality:95` en `Isolate.run` |
| Guardado | `gal` | Scoped Storage Android 10+ / PhotoLibrary iOS |
| Recorte | `image_cropper` | uCrop (Android) / TOCropViewController (iOS) nativo |
| Historial | `hive_flutter` | KV local, prune 100, alternativa a IndexedDB |
| ZIP pasos | `archive` | Equivalente a `JSZip` web |
| Share | `share_plus` | Sheet nativo |

**Estrategias clave:**
1. **Preview liviano:** `Image.file(cacheWidth:720)` + `Transform.rotate` + `InteractiveViewer` (`lib/widgets/image_preview.dart:18`). La matriz original solo se decodifica al exportar.
2. **Lossless 90°:** Si `angle % 90 == 0` se podría mutar solo EXIF (no re-encode). Actualmente se hace `copyRotate` con calidad 95 para fidelidad total; adaptable a EXIF.
3. **Isolate:** `exportImageTask` (`image_processor.dart:24`) evita caídas de frames con fotos 48MP+ (~200MB temporales).

## Estructura
```
lib/
  main.dart                          # Hive.init + Material3 seed #2563EB
  models/rotation_operation.dart     # RotationOperation, TraceMode, AnimationStep
  models/history_entry.dart
  services/rotation_logic.dart       # Port puro de rotador.ts
  services/image_processor.dart      # Isolate + image 4.x
  services/history_service.dart      # Hive box rotador_history
  widgets/image_preview.dart         # preview + cacheWidth
  widgets/trace_painter.dart         # CustomPainter goniómetro
  screens/home_screen.dart           # Flujo completo (galería/cámara, ops, trace, export, historial)
assets/images/
  logo.png (1024, 1.6MB strip), logo_512.png, logo_256.png, logo_192.png, logo_512.webp, logo_v3.png, icon-512.png
  └─ Optimizados con ImageMagick 7.1.2: `magick logo.png -strip -resize 512x512 -define png:compression-level=9`
android/app/src/main/res/mipmap-*   # ic_launcher regenerados 48/72/96/144/192 desde logo.png
web/icons/Icon-*.png                 # idem
```

## Package ID
- Android `android/app/build.gradle.kts:8` → `com.xeland314.imagerotator`
- iOS `ios/Runner.xcodeproj/project.pbxproj:1` → `com.xeland314.imagerotator`
- macOS `macos/Runner/Configs/AppInfo.xcconfig:10` → `com.xeland314.imagerotator`
- Linux `linux/CMakeLists.txt:1` → `com.xeland314.imagerotator`
- Windows `windows/runner/Runner.rc:1` → `Rotador de Imagenes`
- Web `web/manifest.json:1` → `Rotador de Imagenes`

## Requisitos
- Flutter 3.47.2 (Dart 3.13.2), `flutter doctor` sin issues
- Android SDK 35, `cmdline-tools/latest` (ver Fix 1)
- Windows: Visual Studio 2022 + Windows 10 SDK 10.0.26100.0
- GPU con aceleración (Impeller/Skia). Proyecto Windows-first, no Linux.

## Fixes aplicados

### 1) `flutter doctor` — `cmdline-tools component is missing`
SDK en `C:\Users\ASUS\workspace\Android`, pero `cmdline-tools` estaba en `C:\Users\ASUS\workspace\cmdline-tools` suelto → `sdkmanager` error `Could not determine SDK root. Move to <sdk>\cmdline-tools\latest`.
```powershell
New-Item -ItemType Directory -Path Android\cmdline-tools\latest -Force
Copy-Item workspace\cmdline-tools\* Android\cmdline-tools\latest\ -Recurse -Force
flutter doctor --android-licenses  # aceptar
flutter doctor  # [✓] Android toolchain
```

### 2) Windows build — `NuGet primarySources empty` → `Microsoft.Windows.CppWinRT` falla
`CMakeLists.txt:29` de `permission_handler_windows` ejecuta NuGet sin fuentes.
```powershell
# %APPDATA%\NuGet\NuGet.Config estaba vacío
notepad %APPDATA%\NuGet\NuGet.Config
```
Contenido fix:
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
</configuration>
```
Luego:
```powershell
flutter clean
flutter pub get
flutter run -d windows  # CMake ya descarga CppWinRT 2.0.210806.1
```
> Nota de `gradle.properties`: `org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m` (config inicial Flutter). En equipos con 8GB RAM, si Gradle hace OOM, Windows gestiona pagefile; cerrar Edge/VS Code libera ~600MB si fuera necesario. No es entorno Linux, no se limita a 2G manualmente.

## Uso
```bash
flutter pub get
flutter run -d windows  # o -d chrome / -d android
flutter test            # 5 tests (port de rotador.test.ts:18)
flutter analyze         # 0 errores
```

Flujo en app:
1. **Galería/Cámara** (`image_picker`) → preview 220px con `cacheWidth:720`
2. **Operaciones:** grados + dirección (cw/ccw), add/edit/↑↓/×
3. **Opciones:** trazar arco goniómetro, incluir resultado directo (efectivo)
4. **Aplicar** → calcula `totalAngle`/`normalized`/`formula`, genera pasos, guarda en Hive
5. **Export:** Guardar en galería (`gal`, JPG quality 95) o ZIP pasos (`archive` + `share_plus`)
6. **Historial:** grid 2 col con inicial/resultado, restaurar/eliminar, límite 100

## Logos
Originales: `xeland314.github.io/src/assets/logo.png` (1024) y `public/assets/images/logo_v3.png` (640). Optimizados con `magick`/`mogrify` 7.1.2: `strip`, `compression-level=9`, `resize`. WebP 19KB para preview ligero.

## Diferencias web vs Flutter
| Web | Flutter |
|-----|---------|
| `canvas.captureStream` + `MediaRecorder` → WebM | `Isolate.run` + `encodeJpg(95)` → JPG/PNG en disco + `gal` |
| `JSZip` + `toDataURL` | `archive` + `ArchiveFile` |
| `IndexedDB` `RotadorHistoryDB` | `Hive` box `rotador_history` |
| `getUserMedia` modal | `image_picker` `ImageSource.camera` + `image_cropper` |

## Licencia
Portafolio xeland314 — uso interno. `gal`, `image`, `image_cropper` con sus licencias.
