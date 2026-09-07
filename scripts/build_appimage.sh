#!/bin/bash
# build_appimage.sh — Genera .AppImage para Rotador de Imágenes (image_rotator)
# Basado en chat_analyzer_ui/appimage.sh, adaptado y corregido.
# Uso en Linux (otra PC):
#   flutter build linux --release
#   ./scripts/build_appimage.sh          # requiere appimagetool en PATH
#   # o: bash scripts/build_appimage.sh --version 1.0.0
# Salida: RotadorImagenes-1.0.0-x86_64.AppImage (via appimagetool)
set -e

APP_NAME="RotadorImagenes"
EXECUTABLE_NAME="image_rotator"
BUILD_DIR="build/linux/x64/release/bundle"
APPDIR="$APP_NAME.AppDir"
ICONS_DIR="linux/icons"
ICON_BASE_NAME="com.xeland314.imagerotator"
ICON_SOURCE_FILE="com.xeland314.imagerotator.png"
VERSION="${1:-1.0.0}"
# Permite --version 1.0.0
if [[ "$1" == "--version" && -n "$2" ]]; then
  VERSION="$2"
fi

echo "==> Rotador de Imágenes — AppImage build v$VERSION"

if [ ! -d "$BUILD_DIR" ]; then
  echo "ERROR: No existe $BUILD_DIR"
  echo "Ejecuta primero: flutter build linux --release"
  exit 1
fi
if [ ! -f "$BUILD_DIR/$EXECUTABLE_NAME" ]; then
  echo "ERROR: No se encontró $BUILD_DIR/$EXECUTABLE_NAME"
  exit 1
fi
if ! command -v appimagetool >/dev/null 2>&1; then
  echo "ERROR: appimagetool no está instalado."
  echo "Instala: wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O /usr/local/bin/appimagetool && chmod +x /usr/local/bin/appimagetool"
  exit 1
fi

# 1) Preparar estructura
echo "==> Preparando $APPDIR"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share/icons/hicolor"

# 2) Copiar bundle Flutter (binario + data/ + lib/)
echo "==> Copiando bundle $BUILD_DIR -> $APPDIR/usr/bin/"
cp -r "$BUILD_DIR/"* "$APPDIR/usr/bin/"

# libstdc++ compat (opcional, para glibc antiguos)
LIBSTDCXX_PATH="/usr/lib/x86_64-linux-gnu/libstdc++.so.6"
if [ -f "$LIBSTDCXX_PATH" ]; then
  echo "==> Copiando libstdc++.so.6 para compatibilidad"
  cp "$LIBSTDCXX_PATH" "$APPDIR/usr/lib/" || true
fi

# 3) Iconos hicolor
echo "==> Instalando iconos desde $ICONS_DIR"
if [ -d "$ICONS_DIR" ]; then
  find "$ICONS_DIR" -type d -name '*x*' | while read SIZE_DIR; do
    SIZE=$(basename "$SIZE_DIR")
    TARGET_DIR="$APPDIR/usr/share/icons/hicolor/$SIZE/apps"
    mkdir -p "$TARGET_DIR"
    if [ -f "$SIZE_DIR/$ICON_SOURCE_FILE" ]; then
      cp "$SIZE_DIR/$ICON_SOURCE_FILE" "$TARGET_DIR/$ICON_BASE_NAME.png"
    fi
  done
  if [ -f "$ICONS_DIR/256x256/$ICON_SOURCE_FILE" ]; then
    cp "$ICONS_DIR/256x256/$ICON_SOURCE_FILE" "$APPDIR/$ICON_BASE_NAME.png"
    cp "$ICONS_DIR/256x256/$ICON_SOURCE_FILE" "$APPDIR/.DirIcon"
  fi
else
  echo "WARN: $ICONS_DIR no existe, usando assets/images/logo_512.png como fallback"
  mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
  cp "assets/images/logo_512.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$ICON_BASE_NAME.png" || true
  cp "assets/images/logo_512.png" "$APPDIR/$ICON_BASE_NAME.png" || true
fi

# 4) AppRun con fallback llvmpipe para GPUs antiguas (fix chat_analyzer_ui: zenity/kdialog no bloqueante)
cat >"$APPDIR/AppRun" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\${0}")")"
export LD_LIBRARY_PATH="\$HERE/usr/lib:\$HERE/usr/bin:\$LD_LIBRARY_PATH"
# Intento con aceleración HW, fallback a software si falla ( evita crash en VMs / Intel HD antiguas )
if "\$HERE/usr/bin/$EXECUTABLE_NAME" "\$@"; then
    exit 0
else
    EXIT_CODE=\$?
    echo "Fallo GPU (\$EXIT_CODE), reintentando con llvmpipe..." >&2
    export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
    export GALLIUM_DRIVER=llvmpipe
    export MESA_GL_VERSION_OVERRIDE=3.3
    export MESA_GLSL_VERSION_OVERRIDE=330
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Rotador de Imágenes" "Iniciando en modo compatibilidad (software)" -i "$ICON_BASE_NAME" || true
    fi
    if command -v zenity >/dev/null 2>&1; then
        zenity --info --title="Rotador de Imágenes - Modo Compatibilidad" --text="Tu GPU no soporta OpenGL 3.3 nativo.\nIniciando con render por software (CPU)..." --timeout=8 --no-wrap & || true
    fi
    exec "\$HERE/usr/bin/$EXECUTABLE_NAME" "\$@"
fi
EOF
chmod +x "$APPDIR/AppRun"

# 5) Desktop file dentro del AppDir
cat >"$APPDIR/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Rotador de Imágenes
GenericName=Rotador de Imagenes
Comment=Herramienta educativa de razonamiento abstracto - rotaciones multi-giro
Exec=$EXECUTABLE_NAME
Icon=$ICON_BASE_NAME
Categories=Education;Graphics;Utility;
Terminal=false
StartupWMClass=Rotador de Imágenes
X-AppImage-Version=$VERSION
EOF

# Copiar desktop del repo si existe y es más completo
if [ -f "com.xeland314.imagerotator.desktop" ]; then
  cp "com.xeland314.imagerotator.desktop" "$APPDIR/com.xeland314.imagerotator.desktop" || true
fi

echo "==> Generando AppImage con appimagetool..."
# appimagetool genera nombre basado en desktop + AppRun; forzamos nombre explícito si soporta -n
OUTPUT="RotadorImagenes-${VERSION}-x86_64.AppImage"
ARCH=x86_64 appimagetool "$APPDIR" "$OUTPUT"
echo "==> OK: $OUTPUT"
ls -lh "$OUTPUT"
echo "Prueba: chmod +x $OUTPUT && ./$OUTPUT"
