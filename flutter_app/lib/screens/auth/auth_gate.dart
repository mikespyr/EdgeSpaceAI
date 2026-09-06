import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../welcome_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // ============================================================
  // DEVELOPMENT ONLY
  // true  = μπαίνει μέσα χωρίς login
  // false = κανονικό Firebase / Google authentication
  // ============================================================

  static const bool devBypassAuth = true;

  @override
  Widget build(BuildContext context) {
    // Temporary development bypass
    if (devBypassAuth) {
      return const WelcomeScreen();
    }

    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF06151E),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return const WelcomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
