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

        return _OnboardingGate(
          user: user,
          authService: authService,
          onSignOut: _signOut,
        );
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

class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate({
    required this.user,
    required this.authService,
    required this.onSignOut,
  });

  final AppUser user;
  final AuthService authService;
  final VoidCallback onSignOut;

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  late Future<bool> _completed = _readCompletion();

  Future<bool> _readCompletion() async =>
      await widget.authService.database.setting(
        'onboarding_${widget.user.userId}',
      ) ==
      'true';

  Future<void> _finish() async {
    await widget.authService.database.saveSetting(
      'onboarding_${widget.user.userId}',
      'true',
    );
    if (mounted) setState(() => _completed = Future.value(true));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _completed,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: SizedBox.expand());
      }
      return DashboardScreen(
        user: widget.user,
        onSignOut: widget.onSignOut,
        startFeatureTour: snapshot.data != true,
        onFeatureTourComplete: _finish,
      );
    },
  );
}
