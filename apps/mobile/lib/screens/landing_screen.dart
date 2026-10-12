import 'package:flutter/material.dart';
import 'login_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _number = TextEditingController();

  void _track() {
    final n = _number.text.trim().toUpperCase();
    if (n.isEmpty) return;
    Navigator.pushNamed(context, '/track/$n');
  }

  void _openLogin(bool register) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(startAsRegister: register)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.local_shipping), SizedBox(width: 8), Text('TrackIt')]),
        actions: [
          TextButton(onPressed: () => _openLogin(false), child: const Text('Sign in')),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: () => _openLogin(true), child: const Text('Create account')),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2, size: 72, color: scheme.primary),
                const SizedBox(height: 16),
                const Text('Track your parcel', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Enter your tracking number to see where your parcel is right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _number,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _track(),
                  decoration: InputDecoration(
                    hintText: 'e.g. TRK261011ABC123',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(onPressed: _track, icon: const Icon(Icons.arrow_forward)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _track,
                    child: const Padding(padding: EdgeInsets.all(12), child: Text('Track parcel')),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Courier staff, riders and customers: sign in to book, deliver and manage parcels.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
