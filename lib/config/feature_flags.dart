// Feature flags compilables vía --dart-define
// Ej: flutter run --dart-define=ENABLE_CROP=false --dart-define=ENABLE_CAMERA=false
//     flutter build apk --dart-define=ENABLE_CROP=false
//     flutter build windows --dart-define=ENABLE_CAMERA=false
//
// Por defecto: crop DESACTIVADO (sospecha crash arranque Windows por image_cropper sin plugin desktop),
// camera ACTIVADA (móvil) pero con fallback file_selector en desktop.

class FeatureFlags {
  // Crop/recorte: image_cropper no tiene implementación Windows/Linux.
  // Aunque HomeScreen tenía guard `if (_isDesktop) return`, el import/registro del plugin
  // puede causar MissingPluginException / crash en arranque en algunos entornos.
  // Flag permite eliminar completamente el código de recorte del árbol de compilación lógico.
  static const bool enableCrop = bool.fromEnvironment('ENABLE_CROP', defaultValue: false);

  // Cámara: image_picker ImageSource.camera no funciona en Windows (UnimplementedError cameraDelegate).
  // En desktop ya hay fallback a file_selector, pero flag permite compilar variante "sin cámara"
  // para aislar permisos CAMERA / crash en arranque por <uses-permission>.
  static const bool enableCamera = bool.fromEnvironment('ENABLE_CAMERA', defaultValue: true);

  // Helper runtime: crop nunca disponible en desktop aunque flag true (no hay plugin)
  static bool get isCropAvailableOnPlatform {
    if (!enableCrop) return false;
    // Nota: Platform no se puede usar en const; el caller debe hacer `!kIsWeb && (Platform.isWindows||isLinux)` adicional.
    return true;
  }
}
