import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models.dart';
import '../state/auth_state.dart';
import '../utils.dart';
import '../widgets/parcel_map.dart';
import '../widgets/status_chip.dart';

/// Public tracking page (no login needed). Refreshes automatically.
class TrackScreen extends StatefulWidget {
  final String trackingNumber;
  const TrackScreen({super.key, required this.trackingNumber});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  Parcel? _parcel;
  String? _error;
  bool _loading = true;
  Timer? _timer;
  int _rating = 0;
  bool _sending = false;
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: AppConfig.pollSeconds), (_) {
      final p = _parcel;
      if (p != null && p.isFinal) return; // nothing more will change
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final api = context.read<AuthState>().api;
    try {
      final d = await api.get('/track/${Uri.encodeComponent(widget.trackingNumber)}');
      if (!mounted) return;
      setState(() {
        _parcel = Parcel.fromJson(Map<String, dynamic>.from(d));
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent || _parcel == null) {
        setState(() {
          _error = errText(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendFeedback() async {
    if (_rating == 0) {
      showSnack(context, 'Please choose a star rating first.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<AuthState>().api.post(
        '/track/${Uri.encodeComponent(widget.trackingNumber)}/feedback',
        {'rating': _rating, if (_comment.text.trim().isNotEmpty) 'feedback': _comment.text.trim()},
      );
      if (mounted) showSnack(context, 'Thank you for your feedback!');
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  LatLng? _ll(double? a, double? b) => (a == null || b == null) ? null : LatLng(a, b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track ${widget.trackingNumber.toUpperCase()}'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: () => _load(), icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade500),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: () => Navigator.maybePop(context), child: const Text('Back')),
                      ],
                    ),
                  ),
                )
              : _body(_parcel!),
    );
  }

  Widget _body(Parcel p) {
    final riderPoint = _ll(p.riderLat, p.riderLng);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            p.trackingNumber,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        StatusChip(p.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _progress(p),
                    const Divider(height: 28),
                    _info(Icons.location_on_outlined, 'From', '${p.senderName} - ${p.pickupAddress}'),
                    _info(Icons.flag_outlined, 'To', '${p.receiverName} - ${p.deliveryAddress}'),
                    if ((p.description ?? '').isNotEmpty) _info(Icons.inventory_2_outlined, 'Contents', p.description!),
                    _info(Icons.scale_outlined, 'Details',
                        '${p.weightKg} kg, ${p.serviceType == 'express' ? 'Express' : 'Standard'} service'),
                    if (p.riderName != null)
                      _info(Icons.two_wheeler, 'Rider',
                          '${p.riderName}${(p.riderPhone ?? '').isNotEmpty ? '  •  ${p.riderPhone}' : ''}'),
                    if (p.deliveredAt != null) _info(Icons.check_circle_outline, 'Delivered', fmtDate(p.deliveredAt)),
                  ],
                ),
              ),
            ),
            if (_ll(p.pickupLat, p.pickupLng) != null || _ll(p.dropLat, p.dropLng) != null || riderPoint != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Live map', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        riderPoint != null
                            ? 'Blue = rider (updated ${fmtDate(p.riderUpdated)}), green = pickup, red = destination'
                            : 'Green = pickup, red = destination. The rider appears once the parcel is on the road.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      ParcelMap(
                        pickup: _ll(p.pickupLat, p.pickupLng),
                        drop: _ll(p.dropLat, p.dropLng),
                        rider: riderPoint,
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tracking history', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    for (final e in p.events.reversed)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.circle, size: 14, color: statusColor(e.status)),
                        title: Text(e.statusLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text([
                          if ((e.note ?? '').isNotEmpty) e.note!,
                          fmtDate(e.createdAt),
                        ].join('\n')),
                      ),
                  ],
                ),
              ),
            ),
            if (p.status == 'delivered') _feedbackCard(p),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Widget _progress(Parcel p) {
    if (p.status == 'cancelled' || p.status == 'failed') {
      final c = statusColor(p.status);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(
          p.status == 'failed'
              ? 'The delivery attempt failed. The courier will contact you or try again.'
              : 'This parcel was cancelled.',
          style: TextStyle(color: c),
        ),
      );
    }

    final idx = progressSteps.indexOf(p.status);
    final color = statusColor(p.status);
    final last = progressSteps.length - 1;
    return Row(
      children: [
        for (var i = 0; i < progressSteps.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        thickness: 2,
                        color: i == 0 ? Colors.transparent : (i <= idx ? color : Colors.grey.shade300),
                      ),
                    ),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: i <= idx ? color : Colors.grey.shade300,
                      child: i <= idx ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                    Expanded(
                      child: Divider(
                        thickness: 2,
                        color: i == last ? Colors.transparent : (i < idx ? color : Colors.grey.shade300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabels[progressSteps[i]]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: i == idx ? FontWeight.bold : FontWeight.normal),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _feedbackCard(Parcel p) {
    if (p.rating != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.star, color: Colors.amber),
          title: Text('You rated this delivery ${p.rating} / 5'),
          subtitle: (p.feedback ?? '').isEmpty ? null : Text(p.feedback!),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How was your delivery?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(i <= _rating ? Icons.star : Icons.star_border, color: Colors.amber.shade700, size: 32),
                  ),
              ],
            ),
            TextField(
              controller: _comment,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Comments (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _sending ? null : _sendFeedback,
              child: const Text('Submit feedback'),
            ),
          ],
        ),
      ),
    );
  }
}
