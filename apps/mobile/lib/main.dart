import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/admin/admin_home.dart';
import 'screens/customer/customer_home.dart';
import 'screens/email_verification_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/rider/rider_home.dart';
import 'screens/track_screen.dart';
import 'state/auth_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthState()..init(),
      child: const TrackItApp(),
    ),
  );
}

class TrackItApp extends StatelessWidget {
  const TrackItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00796B),
      ),
      // Supports links like  http://localhost:8080/#/track/TRK261011ABC123
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'track') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => TrackScreen(trackingNumber: uri.pathSegments[1]),
          );
        }
        if (uri.pathSegments.length == 1 &&
            uri.pathSegments.first == 'verify-email') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => EmailVerificationScreen(
              verified: uri.queryParameters['status'] == 'success',
            ),
          );
        }
        if (uri.pathSegments.length == 1 &&
            uri.pathSegments.first == 'reset-password') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => PasswordResetScreen(
              token: uri.queryParameters['token'] ?? '',
              email: uri.queryParameters['email'] ?? '',
            ),
          );
        }
        return MaterialPageRoute(settings: settings, builder: (_) => const RootGate());
      },
    );
  }
}

/// Shows the right home screen for the signed-in role.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (!auth.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    switch (auth.user?.role) {
      case 'admin':
        return const AdminHome();
      case 'rider':
        return const RiderHome();
      case 'customer':
        return const CustomerHome();
      default:
        return const LandingScreen();
    }
  }
}
