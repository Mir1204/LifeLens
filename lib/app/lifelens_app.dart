import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import 'theme.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class LifeLensApp extends StatelessWidget {
  const LifeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'LifeLens',
          debugShowCheckedModeBanner: false,
          theme: buildLifeLensTheme(),
          darkTheme: buildLifeLensDarkTheme(),
          themeMode: mode,
          home: const AuthGate(),
        );
      },
    );
  }
}
