import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_rotator/screens/home_screen.dart';
import 'package:image_rotator/services/theme_service.dart';

void main() {
  group('HomeScreen widget', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_home_test');
      Hive.init(tempDir.path);
      // Evitar Hive.initFlutter (path_provider) en tests: abrir boxes manual
      if (!Hive.isBoxOpen('rotador_history')) await Hive.openBox<String>('rotador_history');
      if (!Hive.isBoxOpen('settings')) await Hive.openBox<String>('settings');
      // Inicializa notifier sin re-abrir
      ThemeService.themeModeNotifier.value = ThemeMode.system;
    });

    tearDown(() async {
      if (Hive.isBoxOpen('rotador_history')) await Hive.box<String>('rotador_history').clear();
      if (Hive.isBoxOpen('settings')) await Hive.box<String>('settings').clear();
      await Hive.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      ThemeService.themeModeNotifier.value = ThemeMode.system;
    });

    testWidgets('no lanza ListTile background error (DecoratedBox fix)', (tester) async {
      // Reproduce el error original: ListTile dentro de DecoratedBox con color
      // Después del fix, HomeScreen debe construirse sin excepción.
      final exception = await _captureFlutterError(() async {
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pump();
      });
      expect(exception, isNull, reason: 'No debe lanzar ListTile background error');
    });

    testWidgets('muestra toggle de tema en AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      // Debe existir botón con icono de tema (light/dark/auto) + delete
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
      // Alguno de los iconos de tema debe estar presente
      final hasThemeIcon = find.byIcon(Icons.brightness_auto).evaluate().isNotEmpty ||
          find.byIcon(Icons.light_mode).evaluate().isNotEmpty ||
          find.byIcon(Icons.dark_mode).evaluate().isNotEmpty;
      expect(hasThemeIcon, isTrue);
    });

    testWidgets('tap en Cámara en Windows/Linux usa fallback file_selector', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      expect(find.byType(OutlinedButton), findsWidgets);
      // Tap no debe lanzar MissingPluginException / StateError
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();
      if (Platform.isWindows || Platform.isLinux) {
        await tester.pump(const Duration(milliseconds: 500));
        // No debe crashear, fallback muestra SnackBar
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('operaciones vacías muestra mensaje y no crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      expect(find.textContaining('No hay operaciones'), findsOneWidget);
    });


  });
}

Future<Object?> _captureFlutterError(Future<void> Function() body) async {
  Object? captured;
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('ListTile background color')) {
      captured = details.exception;
    }
  };
  try {
    await body();
  } finally {
    FlutterError.onError = oldHandler;
  }
  return captured;
}
