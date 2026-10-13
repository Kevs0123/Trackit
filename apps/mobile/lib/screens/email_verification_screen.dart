import 'package:flutter/material.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatelessWidget {
  final bool verified;

  const EmailVerificationScreen({super.key, required this.verified});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email verification')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  verified ? Icons.mark_email_read_outlined : Icons.link_off,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  verified
                      ? 'Your email is verified. You can now sign in.'
                      : 'This verification link is invalid or expired. Sign in and request a new link.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    (_) => false,
                  ),
                  child: const Text('Go to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
