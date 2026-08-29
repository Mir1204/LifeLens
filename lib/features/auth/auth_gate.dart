import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../dashboard/dashboard_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final authService = AuthService();
  late Future<AppUser?> userFuture;

  @override
  void initState() {
    super.initState();
    // Do not show a second Flutter splash after Android's launch screen. Local
    // account lookup should be instant; fall back to Login after two seconds.
    userFuture = authService.currentUser().timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Visually continues the native launch screen rather than presenting
          // a separate, second Flutter splash page.
          return const Scaffold(body: SizedBox.expand());
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(onAuthenticated: _setUser);
        }

        return DashboardScreen(user: user, onSignOut: _signOut);
      },
    );
  }

  void _setUser(AppUser user) {
    setState(() {
      userFuture = Future.value(user);
    });
  }

  Future<void> _signOut() async {
    await authService.signOut();
    if (!mounted) return;
    setState(() {
      userFuture = Future.value(null);
    });
  }
}
