import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import 'theme.dart';

class LifeLensApp extends StatelessWidget {
  const LifeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeLens',
      debugShowCheckedModeBanner: false,
      theme: buildLifeLensTheme(),
      home: const AuthGate(),
    );
  }
}
