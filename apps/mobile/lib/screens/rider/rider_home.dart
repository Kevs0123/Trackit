import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models.dart';
import '../../services/api.dart';
import '../../state/auth_state.dart';
import '../../utils.dart';
import '../../widgets/route_dialog.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/account_menu.dart';

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
    'out_for_delivery': ['delivered', 'Add proof & deliver'],
  };

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
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
      if (mounted && !silent) {
        setState(() => _error = errText(e));
      }
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Position?> _getPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pushLocation() async {
    final pos = await _getPosition();
    if (pos == null) {
      if (mounted) {
        showSnack(context,
            'Could not get your location. Allow location access in the browser (needs localhost or https).',
            error: true);
        setState(() => _sharing = false);
        _locTimer?.cancel();
      }
      return;
    }
    if (!mounted) return;
    _pos = pos;
    try {
      await context
          .read<AuthState>()
          .api
          .post('/rider/location', {'lat': pos.latitude, 'lng': pos.longitude});
    } catch (_) {}
  }

  Future<void> _toggleSharing(bool on) async {
    setState(() => _sharing = on);
    _locTimer?.cancel();
    if (on) {
      await _pushLocation();
      if (_sharing) {
        _locTimer =
            Timer.periodic(const Duration(seconds: 15), (_) => _pushLocation());
      }
    }
  }

  Future<void> _update(Parcel p, String status, {String? note}) async {
    final api = context.read<AuthState>().api;
    if (status == 'delivered' && !p.hasProof) {
      final proof = await _deliveryProofDialog();
      if (proof == null || !mounted) return;

      try {
        await api.postMultipart(
          '/parcels/${p.id}/proof',
          fields: const {},
          fileField: 'photos',
          files: proof,
        );
      } catch (e) {
        if (mounted) {
          showSnack(
            context,
            'Proof photos could not be saved. Check the image types and sizes, then try again. ${errText(e)}',
            error: true,
          );
        }
        return;
      }
    }

    try {
      await api.post('/parcels/${p.id}/status', {
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

  Future<List<MultipartUploadFile>?> _deliveryProofDialog() async {
    final picker = ImagePicker();
    final photos = <MultipartUploadFile>[];
    String? error;

    return showDialog<List<MultipartUploadFile>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Confirm delivery'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'To complete delivery:\n'
                    '1. Add one or more proof photos.\n'
                    '2. Use JPG, PNG, WebP, GIF, BMP, or AVIF images (max 4 MB each; up to 10 photos).\n'
                    '3. Tap “Save proof & mark delivered”.',
                  ),
                  const SizedBox(height: 12),
                  if (photos.isEmpty)
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.photo_camera_outlined, size: 40),
                    )
                  else
                    SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                photos[index].bytes,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setDialogState(
                                    () => photos.removeAt(index)),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _pickProofPhotos(
                            picker,
                            ImageSource.camera,
                            photos,
                            (picked) => photos.addAll(picked),
                            (message) => error = message,
                          );
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Take photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _pickProofPhotos(
                            picker,
                            ImageSource.gallery,
                            photos,
                            (picked) => photos.addAll(picked),
                            (message) => error = message,
                          );
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose photo'),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: TextStyle(color: Colors.red.shade700)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (photos.isEmpty) {
                  setDialogState(() {
                    error = 'Add at least one proof photo.';
                  });
                  return;
                }
                Navigator.pop(dialogContext, List.of(photos));
              },
              child: const Text('Save proof & mark delivered'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProofPhotos(
    ImagePicker picker,
    ImageSource source,
    List<MultipartUploadFile> existing,
    void Function(List<MultipartUploadFile>) onPicked,
    void Function(String?) onError,
  ) async {
    try {
      final List<XFile> picked;
      if (source == ImageSource.gallery) {
        picked = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1800,
        );
      } else {
        final photo = await picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1800,
        );
        picked = photo == null ? [] : [photo];
      }
      if (picked.isEmpty) return;
      if (existing.length + picked.length > 10) {
        onError('You can upload up to 10 proof photos.');
        return;
      }
      final additions = <MultipartUploadFile>[];
      for (final photo in picked) {
        final bytes = await photo.readAsBytes();
        if (bytes.length > 4 * 1024 * 1024) {
          onError('Each proof photo must be 4 MB or smaller.');
          return;
        }
        additions.add(MultipartUploadFile(bytes: bytes, filename: photo.name));
      }
      onPicked(additions);
      onError(null);
    } catch (e) {
      onError('Could not load the selected photos: $e');
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
          decoration: const InputDecoration(
              labelText: 'Reason (e.g. receiver not home)',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mark failed')),
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
        title: const Text('My deliveries'),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _load),
          if (auth.user != null)
            AccountMenu(
              name: auth.user!.name,
              email: auth.user!.email,
              onSignOut: () => auth.logout(),
            ),
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
                        subtitle: const Text(
                            'Customers see you on the map while their parcel is on the road.'),
                        value: _sharing,
                        onChanged: _toggleSharing,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text('My deliveries (${_active.length})',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        FilledButton.icon(
                          onPressed: _active.isEmpty
                              ? null
                              : () async {
                                  await showRouteDialog(context,
                                      riderId: auth.user!.id);
                                  _load();
                                },
                          icon: const Icon(Icons.route),
                          label: const Text('Optimize route'),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(color: Colors.red.shade700)),
                    if (_active.isEmpty && _error == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text(
                                'No active deliveries. New assignments appear here automatically.')),
                      ),
                    for (final p in _active) _card(p),
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Recent',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      for (final p in _history)
                        ListTile(
                          dense: true,
                          title:
                              Text('${p.trackingNumber}  •  ${p.receiverName}'),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                if (p.routeOrder != null) ...[
                  CircleAvatar(
                      radius: 13,
                      child: Text('${p.routeOrder}',
                          style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                ],
                Expanded(
                    child: Text(p.trackingNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                StatusChip(p.status),
              ],
            ),
            if (p.status == 'out_for_delivery')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      p.hasProof ? Icons.verified_outlined : Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.hasProof
                            ? 'Proof saved. Tap “Add proof & deliver” to complete delivery.'
                            : 'Before delivery: add up to 10 supported image proofs (max 4 MB each).',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('Deliver to: ${p.receiverName}  â€¢  ${p.receiverPhone}'),
            Text(p.deliveryAddress),
            if ((p.description ?? '').isNotEmpty)
              Text('Contents: ${p.description}  (${p.weightKg} kg)'),
            if (p.routeDistanceKm != null)
              Text('Next leg: ${p.routeDistanceKm} km'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (next != null)
                  FilledButton(
                      onPressed: () => _update(p, next[0]),
                      child: Text(next[1])),
                if (p.status == 'out_for_delivery')
                  OutlinedButton(
                      onPressed: () => _fail(p), child: const Text('Failed')),
                OutlinedButton.icon(
                  onPressed: p.mapsUrl == null
                      ? null
                      : () => launchUrl(Uri.parse(p.mapsUrl!),
                          mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse('tel:${p.receiverPhone}')),
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
