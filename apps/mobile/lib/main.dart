import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/admin/admin_home.dart';
import 'screens/customer/customer_home.dart';
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
    final fragment = Uri.base.fragment;
    final initialRoute = fragment.startsWith('/') ? fragment : '/';

    return MaterialApp(
      title: 'TrackIt',
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00796B),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        cardTheme: CardThemeData(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.14)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF00796B).withValues(alpha: 0.12),
        ),
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
            uri.pathSegments.first == 'reset-password') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => PasswordResetScreen(
              token: uri.queryParameters['token'] ?? '',
              email: uri.queryParameters['email'] ?? '',
            ),
          );
        }
        return MaterialPageRoute(
            settings: settings, builder: (_) => const RootGate());
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
