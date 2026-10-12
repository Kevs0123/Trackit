import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models.dart';
import '../../state/auth_state.dart';
import '../../utils.dart';
import '../../widgets/route_dialog.dart';
import '../../widgets/status_chip.dart';

/// Rider app: my deliveries in route order, status updates, live location sharing.
class RiderHome extends StatefulWidget {
  const RiderHome({super.key});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  List<Parcel> _active = [];
  List<Parcel> _history = [];
  bool _loading = true;
  String? _error;
  bool _sharing = false;
  Position? _pos;
  Timer? _locTimer;
  Timer? _refreshTimer;

  // current status -> [next status, button label]
  static const _next = {
    'assigned': ['picked_up', 'Mark picked up'],
    'picked_up': ['in_transit', 'Mark in transit'],
    'in_transit': ['out_for_delivery', 'Out for delivery'],
    'out_for_delivery': ['delivered', 'Mark delivered'],
  };

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final d = await context.read<AuthState>().api.get('/rider/parcels');
      if (!mounted) return;
      setState(() {
        _active = parseParcels(d['active']);
        _history = parseParcels(d['history']);
        _error = null;
      });
    } catch (e) {
      if (mounted && !silent) setState(() => _error = errText(e));
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<Position?> _getPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pushLocation() async {
    final pos = await _getPosition();
    if (pos == null) {
      if (mounted) {
        showSnack(context, 'Could not get your location. Allow location access in the browser (needs localhost or https).', error: true);
        setState(() => _sharing = false);
        _locTimer?.cancel();
      }
      return;
    }
    _pos = pos;
    try {
      await context.read<AuthState>().api.post('/rider/location', {'lat': pos.latitude, 'lng': pos.longitude});
    } catch (_) {}
  }

  Future<void> _toggleSharing(bool on) async {
    setState(() => _sharing = on);
    _locTimer?.cancel();
    if (on) {
      await _pushLocation();
      if (_sharing) _locTimer = Timer.periodic(const Duration(seconds: 15), (_) => _pushLocation());
    }
  }

  Future<void> _update(Parcel p, String status, {String? note}) async {
    try {
      await context.read<AuthState>().api.post('/parcels/${p.id}/status', {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
        if (_pos != null) 'lat': _pos!.latitude,
        if (_pos != null) 'lng': _pos!.longitude,
      });
      if (mounted) showSnack(context, 'Updated - customer notified.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, errText(e), error: true);
    }
  }

  Future<void> _fail(Parcel p) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delivery failed'),
        content: TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Reason (e.g. receiver not home)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark failed')),
        ],
      ),
    );
    if (ok == true) _update(p, 'failed', note: note.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      appBar: AppBar(
        title: Text('TrackIt Rider  -  ${auth.user?.name ?? ''}'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => auth.logout()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: SwitchListTile(
                        secondary: const Icon(Icons.my_location),
                        title: const Text('Share my live location'),
                        subtitle: const Text('Customers see you on the map while their parcel is on the road.'),
                        value: _sharing,
                        onChanged: _toggleSharing,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text('My deliveries (${_active.length})',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        FilledButton.icon(
                          onPressed: _active.isEmpty
                              ? null
                              : () async {
                                  await showRouteDialog(context, riderId: auth.user!.id);
                                  _load();
                                },
                          icon: const Icon(Icons.route),
                          label: const Text('Optimize route'),
                        ),
                      ],
                    ),
                    if (_error != null) Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                    if (_active.isEmpty && _error == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No active deliveries. New assignments appear here automatically.')),
                      ),
                    for (final p in _active) _card(p),
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Recent', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      for (final p in _history)
                        ListTile(
                          dense: true,
                          title: Text('${p.trackingNumber}  â€¢  ${p.receiverName}'),
                          subtitle: Text(p.deliveryAddress),
                          trailing: StatusChip(p.status),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _card(Parcel p) {
    final next = _next[p.status];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (p.routeOrder != null) ...[
                  CircleAvatar(radius: 13, child: Text('${p.routeOrder}', style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(p.trackingNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                StatusChip(p.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Deliver to: ${p.receiverName}  â€¢  ${p.receiverPhone}'),
            Text(p.deliveryAddress),
            if ((p.description ?? '').isNotEmpty) Text('Contents: ${p.description}  (${p.weightKg} kg)'),
            if (p.routeDistanceKm != null) Text('Next leg: ${p.routeDistanceKm} km'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (next != null) FilledButton(onPressed: () => _update(p, next[0]), child: Text(next[1])),
                if (p.status == 'out_for_delivery')
                  OutlinedButton(onPressed: () => _fail(p), child: const Text('Failed')),
                OutlinedButton.icon(
                  onPressed: p.mapsUrl == null
                      ? null
                      : () => launchUrl(Uri.parse(p.mapsUrl!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate'),
                ),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${p.receiverPhone}')),
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

