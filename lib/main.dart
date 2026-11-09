import 'package:flutter/material.dart';

import 'core/scenora_theme.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScenoraApp());
}

class ScenoraApp extends StatefulWidget {
  const ScenoraApp({super.key});

  @override
  State<ScenoraApp> createState() => _ScenoraAppState();
}

class _ScenoraAppState extends State<ScenoraApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCENORA',
      debugShowCheckedModeBanner: false,
      theme: ScenoraTheme.light,
      darkTheme: ScenoraTheme.dark,
      themeMode: _themeMode,
      home: MainShell(
        themeMode: _themeMode,
        onThemeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
