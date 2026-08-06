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
    userFuture = authService.currentUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Text(
                'L',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'LifeLens',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
