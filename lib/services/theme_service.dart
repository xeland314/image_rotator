import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AppThemeMode { light, dark, system }

class ThemeService {
  static const String boxName = 'settings';
  static const String keyTheme = 'themeMode';
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<String>(boxName);
    }
    final stored = Hive.box<String>(boxName).get(keyTheme);
    themeModeNotifier.value = _fromString(stored);
  }

  static ThemeMode _fromString(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static AppThemeMode get appMode {
    switch (themeModeNotifier.value) {
      case ThemeMode.light:
        return AppThemeMode.light;
      case ThemeMode.dark:
        return AppThemeMode.dark;
      case ThemeMode.system:
        return AppThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await Hive.box<String>(boxName).put(keyTheme, _toString(mode));
  }

  static Future<void> cycleTheme() async {
    final current = themeModeNotifier.value;
    ThemeMode next;
    if (current == ThemeMode.system) {
      next = ThemeMode.light;
    } else if (current == ThemeMode.light) {
      next = ThemeMode.dark;
    } else {
      next = ThemeMode.system;
    }
    await setThemeMode(next);
  }

  static String get label {
    switch (themeModeNotifier.value) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  static IconData get icon {
    switch (themeModeNotifier.value) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}
