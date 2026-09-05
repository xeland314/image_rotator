import 'package:flutter/material.dart';
import 'services/history_service.dart';
import 'services/theme_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HistoryService.init();
  await ThemeService.init();
  runApp(const RotadorApp());
}

class RotadorApp extends StatelessWidget {
  const RotadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Rotador de Imágenes',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB), brightness: Brightness.light),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: false),
            cardTheme: const CardThemeData(margin: EdgeInsets.zero),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB), brightness: Brightness.dark),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: false),
            cardTheme: const CardThemeData(margin: EdgeInsets.zero),
          ),
          themeMode: mode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
