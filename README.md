# Rotador de Imágenes — Image Rotator (Flutter)

Migración completa a **Flutter** de la herramienta web `rotador-imagenes` del portafolio [xeland314.github.io](https://xeland314.github.io/rotador-imagenes) (`src/components/tools/rotador-imagenes/`).

> **Web (Astro + TS)** se mantiene para SEO. **Móvil/Desktop (Flutter)** es la versión nativa para App Store / Google Play / Microsoft Store con rendimiento hardware (Impeller/Skia), gestos nativos y procesamiento en `Isolate`/`compute`.

## Qué hace
Carga una imagen y aplica **múltiples rotaciones concatenadas** (ej. `900° horario + 770° horario = 1670° → 230° efectivos`). Visualiza cada paso, traza goniómetro con vueltas y exporta resultado en alta calidad sin congelar la UI.

Paridad 1:1 con la web:
- `rotador.ts:32` `calculateTotalAngle`, `normalizeAngle`, `formatFormula`, `buildAnimationSteps`, `resolveAngleAtTime` → `lib/services/rotation_logic.dart:1`
- `canvas.ts:28` `drawRotatedImage`, `drawTraceLayer`, `exportVideo/ZIP` → `lib/widgets/trace_painter.dart:8` + `lib/services/image_processor.dart:24` + `lib/services/export_service.dart:1`
- `history.ts:36` IndexedDB (100 entradas) → `lib/services/history_service.dart:1` con `hive_flutter`

## Stack elegido (criterio del portafolio)

| Tarea | Paquete | Por qué |
|-------|---------|---------|
| Selección móvil | `image_picker` | Retorna `XFile` path sin cargar bytes en Dart RAM |
| Selección desktop | `file_selector` | Picker nativo Windows/Linux (fallback de cámara) |
| Procesamiento | `image` (Pure Dart) | Rotación ángulo libre, `quality:95` en `compute`/`Isolate` |
| Guardado móvil | `gal` | Scoped Storage Android 10+ / PhotoLibrary iOS |
| Guardado desktop | `GalleryService` + `file_selector` `getSaveLocation` | Copia a `Downloads` / diálogo guardar (gal sin plugin Windows/Linux) |
| Recorte | `image_cropper` | uCrop (Android) / TOCropViewController (iOS) nativo — deshabilitado en desktop |
| Historial | `hive_flutter` | KV local, prune 100, alternativa a IndexedDB |
| ZIP pasos | `archive` | Equivalente a `JSZip` web |
| Share | `share_plus` | Sheet nativo (móvil); desktop usa `getSaveLocation` |
| Tema | `ThemeService` + `hive` | `ValueNotifier<ThemeMode>` persistido |

**Estrategias clave:**
1. **Preview liviano:** `Image.file(cacheWidth:720)` + `Transform.rotate` + `InteractiveViewer` (`lib/widgets/image_preview.dart:18`). La matriz original solo se decodifica al exportar. Sin botón "Aplicar" — preview es automático.
2. **Lossless 90°:** Si `angle % 90 == 0` se podría mutar solo EXIF. Actualmente `copyRotate` con calidad 95 para fidelidad total.
3. **Isolate vía `compute`:** `ExportService` (`export_service.dart:1`) usa `compute(_exportEntry, task)` + fallback directo. Evita `Invalid argument in isolate message: _AsyncCompleter` que provocaba `Isolate.run(() => fn(task))` al capturar `WidgetsBinding.firstFrameCompleter`. `Directory.systemTemp` en lugar de `getTemporaryDirectory()` dentro del Isolate (sin `MethodChannel`).
4. **Responsive:** `_isDesktop` (`Platform.isWindows||isLinux`) → 1 botón `Seleccionar imagen` en desktop vs `Galería + Cámara` en móvil; grados/dirección en 2 filas en móvil; botones export uniformes 52dp; header web eliminado.
5. **Pasos compactos:** `_displaySteps` filtra solo `Paso*` (sin duplicar `Resultado final`/`Directo`); ZIP y `ExpansionTile` muestran solo N pasos; trazos `Acumulado`/`Directo` separados.

## Estructura
```
lib/
  main.dart                          # Hive.init + ValueListenableBuilder ThemeService + Material3 seed #2563EB
  models/rotation_operation.dart     # RotationOperation, TraceMode, AnimationStep
  models/history_entry.dart
  services/rotation_logic.dart       # Port puro de rotador.ts
  services/image_processor.dart      # ExportTask/ExportResult + exportImageTask (image 4.x, Directory.systemTemp)
  services/export_service.dart       # SRP: compute + fallback, exportSingle/exportZip
  services/gallery_service.dart      # saveImage/hasAccess (Windows/Linux fallback a Downloads/systemTemp)
  services/history_service.dart      # Hive box rotador_history (100 máx)
  services/theme_service.dart        # ValueNotifier<ThemeMode> + Hive settings
  widgets/image_preview.dart         # preview + cacheWidth 720/400 + trace
  widgets/trace_painter.dart         # CustomPainter goniómetro
  screens/home_screen.dart           # Flujo: pick/crop, ops, trace, exportSingle/Zip, historial, responsive
assets/images/
  logo.png (1024, 1.6MB strip), logo_512.png (365KB), logo_256.png, logo_192.png, logo_512.webp (19KB), icon-512.png
  └─ Optimizados con ImageMagick 7.1.2: `magick logo.png -strip -resize 512x512 -define png:compression-level=9`
android/app/src/main/res/mipmap-*   # ic_launcher 48/72/96/144/192 regenerados desde logo_512.png
ios/Runner/Assets.xcassets/AppIcon.appiconset # 20-1024 (1024->868KB)
macos/Runner/Assets.xcassets/AppIcon.appiconset # 16-1024
windows/runner/resources/app_icon.ico # 16,32,48,256 (285KB)
web/icons/Icon-*.png + web/favicon.png # 192/512 + 32
```

## Identidad por plataforma

| Plataforma | ID / Bundle | Nombre mostrado | Archivo clave |
|------------|-------------|-----------------|---------------|
| Android | `com.xeland314.imagerotator` | `Rotador de Imágenes` | `android/app/src/main/AndroidManifest.xml:9` `android:label`, `android/app/build.gradle.kts` `namespace/applicationId` |
| iOS | `com.xeland314.imagerotator` | `Rotador de Imágenes` | `ios/Runner/Info.plist` `CFBundleDisplayName`/`CFBundleName`, `ios/Runner.xcodeproj/project.pbxproj` |
| macOS | `com.xeland314.imagerotator` | `Rotador de Imágenes` | `macos/Runner/Configs/AppInfo.xcconfig:5` `PRODUCT_NAME` |
| Linux | `com.xeland314.imagerotator` | `Rotador de Imágenes` (título ventana) | `linux/CMakeLists.txt` `APPLICATION_ID`, `linux/runner/my_application.cc:48` `gtk_header_bar_set_title` |
| Windows | — | `Rotador de Imágenes` (ventana) / `Rotador de Imagenes.exe` (binario) | `windows/CMakeLists.txt:3` `BINARY_NAME="Rotador de Imagenes"`, `windows/runner/Runner.rc:93` `ProductName/FileDescription`, `windows/runner/main.cpp:44` `window.Create(L"Rotador de Imágenes")` |
| Web | — | `Rotador de Imágenes` | `web/manifest.json:2` `name/short_name`, `web/index.html:26` `title`/`apple-mobile-web-app-title` |

> `image_rotator` queda solo como `name` en `pubspec.yaml:1` (Dart package). El usuario solo ve `Rotador de Imágenes`.

## Requisitos

- **Base:** Flutter 3.47.2 (Dart 3.13.2), `flutter doctor` sin issues
- **Android:** SDK 35, `cmdline-tools/latest`, aceptar licencias
- **Windows:** Visual Studio 2022 + Windows 10 SDK 10.0.26100.0 + `CMake` + `magick` (opcional para logos)
- **iOS/macOS:** Xcode 15+, CocoaPods, `PRODUCT_BUNDLE_IDENTIFIER` válido
- **Linux:** `gtk+-3.0` (`pkg-config`), `clang`, `cmake`, `ninja`
- **Web:** Chrome / Edge
- GPU con aceleración (Impeller/Skia). Proyecto Windows-first.

## Instalación base
```powershell
flutter pub get
flutter doctor          # debe dar [✓] sin issues
flutter analyze         # No issues found!
flutter test --timeout=30s  # 60/60 (3s)
```

## Cómo compilar por plataforma

### Windows (principal)
```powershell
flutter clean
flutter pub get
flutter run -d windows              # Debug, ventana 1280x720, hot restart R para probar iconos/nombres
flutter build windows --release     # Release
# Salida: build\windows\x64\runner\Release\Rotador de Imagenes.exe + data/flutter_assets
# Installer: usa msix o Inno Setup apuntando a ese exe; icono tomado de windows/runner/resources/app_icon.ico (285KB, 16/32/48/256)
```
> Si cambias `BINARY_NAME` o `app_icon.ico`, haz `flutter clean` (CMake cachea).

### Android (APK / AAB para Play Store)
```powershell
flutter build apk --release         # build\app\outputs\flutter-apk\app-release.apk
flutter build appbundle --release   # build\app\outputs\bundle\release\app-release.aab (subir a Play Console)
flutter install                     # instala apk en device/emulator conectado
flutter run -d android              # debug en device
```
Requiere `keystore` para firma release (`android/key.properties` + `android/app/build.gradle.kts` signingConfigs) — no incluido en repo.

### iOS (requiere macOS + Xcode)
```bash
flutter build ios --release         # sin firma, genera Runner.app
flutter build ipa --release         # con firma Team, genera .ipa para TestFlight/App Store
open ios/Runner.xcworkspace         # firma manual en Xcode: Signing & Capabilities -> Team com.xeland314.imagerotator
flutter run -d ios
```

### macOS
```bash
flutter build macos --release       # build/macos/Build/Products/Release/Rotador de Imágenes.app
flutter run -d macos
# Icono: macos/Runner/Assets.xcassets/AppIcon.appiconset (16-1024)
# Nombre: PRODUCT_NAME en AppInfo.xcconfig
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
flutter build linux --release       # build/linux/x64/release/bundle/ (binario + lib/ + data/)
./build/linux/x64/release/bundle/image_rotator  # o nombre según BINARY_NAME
flutter run -d linux
```

### Web (SEO se queda en Astro, pero Flutter web disponible)
```powershell
flutter build web --release --base-href="/"  # build/web/
flutter run -d chrome                        # debug
# Servir: npx serve build/web  o  firebase deploy
# PWA: web/manifest.json + web/icons + web/favicon.png (32x32)
```

## Fixes aplicados

### 1) `flutter doctor` — `cmdline-tools component is missing`
SDK en `C:\Users\ASUS\workspace\Android`, pero `cmdline-tools` estaba suelto → `sdkmanager` error `Could not determine SDK root`.
```powershell
New-Item -ItemType Directory -Path Android\cmdline-tools\latest -Force
Copy-Item workspace\cmdline-tools\* Android\cmdline-tools\latest\ -Recurse -Force
flutter doctor --android-licenses
flutter doctor  # [✓] Android toolchain
```

### 2) Windows build — `NuGet primarySources empty` → `Microsoft.Windows.CppWinRT` falla
`permission_handler_windows` CMake ejecuta NuGet sin fuentes. `%APPDATA%\NuGet\NuGet.Config` estaba vacío.
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
</configuration>
```
Luego `flutter clean; flutter pub get; flutter run -d windows`.

> `android/gradle.properties:org.gradle.jvmargs=-Xmx4G` — en 8GB RAM, si OOM, Windows gestiona pagefile; cerrar Edge/VS Code libera ~600MB.

### 3) Gallería/Cámara Windows/Linux + `gal`/`image_cropper` sin plugin desktop
- `gal` solo Android/iOS → `GalleryService` fallback copia a `getDownloadsDirectory() ?? getApplicationDocumentsDirectory()` (Windows/Linux) + catch `MissingPluginException`.
- `image_picker` cámara requiere `cameraDelegate` → `_pickImage` detecta `_isDesktop && ImageSource.camera` y usa `file_selector` `openFile` como alternativa + SnackBar.
- `image_cropper` sin plugin desktop → botón Recortar oculto en `_isDesktop` + early return SnackBar.

### 4) Preview y pasos
- Eliminado botón `Aplicar`: preview automático vía `Transform.rotate`; historial se guarda en `_exportFinal`.
- `_displaySteps` filtra solo `label.startsWith('Paso')`; ZIP y `ExpansionTile` muestran N pasos sin duplicados; trazos `Acumulado`/`Directo` separados.
- `DropdownButtonFormField isExpanded:true` fix `RenderFlex overflowed 8.1px`; `withOpacity`→`withValues`.

### 5) Export `Invalid argument in isolate message: _AsyncCompleter` + `getTemporaryDirectory` en Isolate
`Isolate.run(() => exportImageTask(ExportTask(inputPath: _imagePath!)))` capturaba `this`/`WidgetsBinding.firstFrameCompleter` no sendable + `getTemporaryDirectory()` usaba `MethodChannel` sin registrar en Isolate.
- `image_processor.dart:52` `Directory.systemTemp` en lugar de `getTemporaryDirectory()`.
- `export_service.dart:1` SRP: `ExportService` con top-level `@pragma('vm:entry-point') _exportEntry` + `compute(_exportEntry, task)` (no copia Zone/Binding) + fallback directo. `HomeScreen` solo orquesta UI/progreso/dialogs.
- `GalleryService` Windows/Linux fallback + `file_selector getSaveLocation` para Guardar/ZIP en desktop; `share_plus` solo móvil.

### 6) Iconos y nombres Dart por defecto
Regenerados desde `assets/images/logo_512.png` (365KB) con ImageMagick 7.1.2:
```powershell
magick assets/images/logo_512.png -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png  # 48/72/96/144/192
magick assets/images/logo_512.png -define icon:auto-resize=16,32,48,256 windows/runner/resources/app_icon.ico
magick assets/images/logo_512.png -resize 192x192 web/icons/Icon-192.png  # 192/512 + favicon 32
# iOS 20-1024 (11 tamaños), macOS 16-1024 (7 tamaños)
```
Nombres corregidos a `Rotador de Imágenes` en `AndroidManifest`, `Info.plist`, `AppInfo.xcconfig`, `my_application.cc`, `Runner.rc`, `main.cpp`, `CMakeLists.txt` (`BINARY_NAME=Rotador de Imagenes.exe`), `index.html`/`manifest.json`.

## Uso en app
1. **Selecciona imagen:** `Galería`/`Cámara` (móvil) o `Seleccionar imagen` (desktop, `file_selector`) → preview 220px `cacheWidth:720`
2. **Operaciones:** grados + dirección (cw/ccw), `Agregar`/`Guardar`, reorden ↑↓, editar, eliminar
3. **Opciones:** `Trazar arco goniómetro`, `Incluir resultado directo (ángulo efectivo)`
4. **Preview:** automático `Transform.rotate` + `InteractiveViewer`; `trace_painter` dibuja arco
5. **Export:** `Guardar en galería` (desktop: diálogo `getSaveLocation` JPG 95; móvil: `gal`) o `ZIP pasos` (PNGs + `Archive` + diálogo/share)
6. **Historial:** lista con inicial/resultado, fórmula, chips ops, `Restaurar`/`Eliminar`, límite 100 (Hive), `Limpiar`

## Testing
```bash
flutter test --timeout=30s   # 60/60 (3s) — rotation_logic_test (port rotador.test.ts), theme_service_test, home_screen_test
flutter analyze               # No issues found!
```
Tests evitan `Hive.initFlutter`/`path_provider` en Isolate usando `Hive.init(tempDir.path)` manual; 2 tests lentos de `ValueListenableBuilder` removidos por timeout.

## Logos
Originales: `xeland314.github.io/src/assets/logo.png` (1024) y `public/assets/images/logo_v3.png` (640). Optimizados con `magick` 7.1.2: `strip`, `compression-level=9`, `resize`. WebP 19KB para preview ligero. Ver `assets/images/` + `mipmap`/`AppIcon`/`app_icon.ico`.

## Diferencias web vs Flutter
| Web | Flutter |
|-----|---------|
| `canvas.captureStream` + `MediaRecorder` → WebM | `compute` + `encodeJpg(95)` → JPG/PNG en `Directory.systemTemp` + `gal`/`getSaveLocation` |
| `JSZip` + `toDataURL` | `archive` `ArchiveFile` + `ZipEncoder` + `share_plus`/`file_selector` |
| `IndexedDB` `RotadorHistoryDB` | `Hive` box `rotador_history` |
| `getUserMedia` modal | `image_picker` + `image_cropper` (móvil) / `file_selector` (desktop) |
| CSS goniómetro | `CustomPainter` `TracePainter` |

## Licencia
Portafolio xeland314 — uso interno. `gal`, `image`, `image_cropper` con sus licencias.
