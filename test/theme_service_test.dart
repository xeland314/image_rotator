import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_rotator/services/theme_service.dart';

void main() {
  group('ThemeService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_theme_test');
      Hive.init(tempDir.path);
      if (!Hive.isBoxOpen('settings')) await Hive.openBox<String>('settings');
      ThemeService.themeModeNotifier.value = ThemeMode.system;
    });

    tearDown(() async {
      if (Hive.isBoxOpen('settings')) await Hive.box<String>('settings').clear();
      await Hive.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      ThemeService.themeModeNotifier.value = ThemeMode.system;
    });

    test('init defaults to system', () {
      expect(ThemeService.themeModeNotifier.value, ThemeMode.system);
      expect(ThemeService.label, 'Sistema');
      expect(ThemeService.icon, Icons.brightness_auto);
    });

    test('setThemeMode light', () async {
      await ThemeService.setThemeMode(ThemeMode.light);
      expect(ThemeService.themeModeNotifier.value, ThemeMode.light);
      expect(ThemeService.label, 'Claro');
      expect(ThemeService.icon, Icons.light_mode);
      expect(Hive.box<String>('settings').get('themeMode'), 'light');
    });

    test('setThemeMode dark', () async {
      await ThemeService.setThemeMode(ThemeMode.dark);
      expect(ThemeService.themeModeNotifier.value, ThemeMode.dark);
      expect(ThemeService.label, 'Oscuro');
      expect(ThemeService.icon, Icons.dark_mode);
    });

    test('cycleTheme system->light->dark->system', () async {
      await ThemeService.setThemeMode(ThemeMode.system);
      await ThemeService.cycleTheme();
      expect(ThemeService.themeModeNotifier.value, ThemeMode.light);
      await ThemeService.cycleTheme();
      expect(ThemeService.themeModeNotifier.value, ThemeMode.dark);
      await ThemeService.cycleTheme();
      expect(ThemeService.themeModeNotifier.value, ThemeMode.system);
    });
  });
}
