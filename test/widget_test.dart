import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelens_mobile/features/auth/login_screen.dart';
import 'package:lifelens_mobile/models/app_user.dart';

void main() {
  testWidgets('LifeLens login opens when signed out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onAuthenticated: (AppUser user) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('New here? Create account'), findsOneWidget);
  });
}
