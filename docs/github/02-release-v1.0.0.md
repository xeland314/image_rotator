# Release v1.0.0 — Rotador de Imagenes (Español)

> Pega este texto en: GitHub → Releases → Draft a new release → Tag `v1.0.0` → Title `v1.0.0 — Rotador de Imagenes` → Description

---

## Rotador de Imagenes v1.0.0 — Primera release estable

Herramienta educativa de **razonamiento abstracto y vision espacial** migrada de la web `rotador-imagenes` (Astro/TS) a **Flutter nativo**. Carga una imagen y aplica **multiples rotaciones concatenadas** con preview liviano y trazo goniometro.

**Web original (SEO):** https://xeland314.github.io/rotador-imagenes/  
**Portafolio:** https://xeland314.github.io  
**Licencia:** GPL-3.0 — ver `LICENSE`

### Que hace

- Suma con signos: `Horario (+) / Antihorario (-)` → `Total → Normalizado [0,360)` (ej. `900° + 770° = 1670° → 230° efectivos`)
- Preview automatico `Transform.rotate` + `InteractiveViewer` + `TracePainter` (acumulado/directo)
- Export en `Isolate`/`compute` calidad 95 sin congelar UI
- Guia interna `Aprende el Metodo` — 5 secciones: circulo unitario, multiplos de 360, modulo, sentidos, caso repetitivo `90°×5/×6` con demo visual
- Historial local 100 (Hive) + ZIP de pasos

### Descargas (3 artefactos)

| Plataforma | Archivo | Como instalar |
|---|---|---|
| **Android** | `app-release.apk` | Descarga en movil → permite origenes desconocidos → instala. O `adb install app-release.apk` |
| **Windows 10/11 x64** | `RotadorImagenes-Setup-v1.0.0.exe` (NSIS, ~13.5 MB) | Doble clic → Siguiente → Instalar (requiere admin). Crea acceso en Menu Inicio y Escritorio. Desinstalar desde Panel de Control. |
| **Linux x64** | `RotadorImagenes-1.0.0-x86_64.AppImage` | `chmod +x RotadorImagenes-1.0.0-x86_64.AppImage && ./RotadorImagenes-1.0.0-x86_64.AppImage` — Auto fallback a `llvmpipe` si tu GPU no soporta OpenGL 3.3 (zenity/kdialog + notify). |

> **Nota Linux:** Compilado en otra PC con `flutter build linux --release && ./scripts/build_appimage.sh --version 1.0.0` (requiere `appimagetool`). Iconos `hicolor` incluidos.

### Instalacion rapida

**Android:**
```bash
adb install app-release.apk
# o copia el APK al telefono y toca para instalar
```

**Windows (PowerShell admin no requerido, el instalador pide elevacion):**
```powershell
.\RotadorImagenes-Setup-v1.0.0.exe
# o silencioso: .\RotadorImagenes-Setup-v1.0.0.exe /S
```

**Linux:**
```bash
chmod +x RotadorImagenes-1.0.0-x86_64.AppImage
./RotadorImagenes-1.0.0-x86_64.AppImage
# Si falla GPU:
MESA_LOADER_DRIVER_OVERRIDE=llvmpipe ./RotadorImagenes-1.0.0-x86_64.AppImage
```

### Novedades v1.0.0

- Migracion completa `rotador.ts` → `rotation_logic.dart` + `trace_painter.dart` + `export_service.dart` (SRP + `compute`)
- `image_picker` + `gal` + `image_cropper` (movil) / `file_selector` fallback desktop + `permission_handler`
- `BINARY_NAME image_rotator`, `APPLICATION_ID com.xeland314.imagerotator`, nombres `Rotador de Imagenes`
- Iconos regenerados desde `logo.png` 1024 → `logo_512.png`, `mipmap`, `AppIcon`, `app_icon.ico` con `magick`
- `ThemeService` Hive, guia, footer `Version Web`, packaging `scripts/build_appimage.sh` + `installer.nsi` + `scripts/build_windows.ps1`

### Requisitos

- Android 6.0+ (Scoped Storage), Windows 10/11 x64, Linux Ubuntu 20.04+/Fedora con `gtk+-3.0`, GPU con OpenGL 3.3 (o llvmpipe)
- Flutter 3.47.2 / Dart 3.13.2 para compilar desde fuente

### Verificacion

```bash
flutter analyze  # No issues
flutter test --timeout=30s  # 60/60
# NSIS 3.12 verificado, AppImage con AppRun llvmpipe + zenity/kdialog/notify
```

### Creditos

- Autor: Christopher Villamarin (@xeland314)
- Web original: `xeland314.github.io/src/components/tools/rotador-imagenes`
- Licencia: GPL-3.0 — ve `LICENSE` y https://www.gnu.org/licenses/gpl-3.0.html

---

**Tag:** `v1.0.0`  
**Title:** `v1.0.0 — Rotador de Imagenes`  
**Prerelease:** ☐ No  
**Set as latest:** ☑ Si  
**Archivos a adjuntar:** `app-release.apk` + `RotadorImagenes-Setup-v1.0.0.exe` + `RotadorImagenes-1.0.0-x86_64.AppImage`
