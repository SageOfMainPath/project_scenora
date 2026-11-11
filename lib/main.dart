import 'package:flutter/material.dart';

import 'core/google_auth.dart';
import 'core/scenora_theme.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeGoogleAuth();
  } on Object catch (error, stackTrace) {
    // Authentication is optional at startup. A platform-specific Supabase
    // initialization failure must not prevent the rest of SCENORA from
    // opening; the login flow will surface a useful message instead.
    debugPrint('Google Auth initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
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
