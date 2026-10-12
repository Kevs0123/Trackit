import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/auth_state.dart';
import '../utils.dart';

/// Booking form used by courier staff (walk-in customers) and by customers.
/// Pops with the created [Parcel].
class ParcelFormDialog extends StatefulWidget {
  final bool isStaff;
  const ParcelFormDialog({super.key, required this.isStaff});

  @override
  State<ParcelFormDialog> createState() => _ParcelFormDialogState();
}

class _ParcelFormDialogState extends State<ParcelFormDialog> {
  static const _fields = [
    'sender_name', 'sender_phone', 'sender_email', 'pickup_address',
    'receiver_name', 'receiver_phone', 'receiver_email', 'delivery_address',
    'description', 'weight_kg', 'pickup_lat', 'pickup_lng', 'drop_lat', 'drop_lng',
  ];

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {for (final f in _fields) f: TextEditingController()};
  String _service = 'standard';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _c['weight_kg']!.text = '1';
    if (!widget.isStaff) {
      final u = context.read<AuthState>().user;
      if (u != null) {
        _c['sender_name']!.text = u.name;
        _c['sender_email']!.text = u.email;
        _c['sender_phone']!.text = u.phone ?? '';
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _fee {
    final w = double.tryParse(_c['weight_kg']!.text) ?? 0;
    var fee = 60 + max(0, w.ceil() - 1) * 20;
    if (_service == 'express') fee += 60;
    return fee.toDouble();
  }

  Widget _f(String key, String label, {bool required = true, TextInputType? type, double width = 270}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: _c[key],
        keyboardType: type,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        onChanged: key == 'weight_kg' ? (_) => setState(() {}) : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final body = <String, dynamic>{'service_type': _service};
    for (final f in _fields) {
      final v = _c[f]!.text.trim();
      if (v.isEmpty) continue;
      final numeric = f == 'weight_kg' || f.endsWith('_lat') || f.endsWith('_lng');
      body[f] = numeric ? (double.tryParse(v) ?? v) : v;
    }

    try {
      final d = await context.read<AuthState>().api.post('/parcels', body);
      if (!mounted) return;
      Navigator.pop(context, Parcel.fromJson(Map<String, dynamic>.from(d)));
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Book a parcel'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sender / pickup', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _f('sender_name', 'Sender name'),
                  _f('sender_phone', 'Sender phone', type: TextInputType.phone),
                  _f('sender_email', 'Sender email', required: false, type: TextInputType.emailAddress),
                  _f('pickup_address', 'Pickup address', width: 552),
                ]),
                const SizedBox(height: 16),
                const Text('Receiver / delivery', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _f('receiver_name', 'Receiver name'),
                  _f('receiver_phone', 'Receiver phone', type: TextInputType.phone),
                  _f('receiver_email', 'Receiver email (for updates)', required: false, type: TextInputType.emailAddress),
                  _f('delivery_address', 'Delivery address', width: 552),
                ]),
                const SizedBox(height: 16),
                const Text('Parcel', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _f('description', 'Contents', required: false),
                  _f('weight_kg', 'Weight (kg)', type: const TextInputType.numberWithOptions(decimal: true), width: 130),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      value: _service,
                      decoration: const InputDecoration(labelText: 'Service', border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'standard', child: Text('Standard')),
                        DropdownMenuItem(value: 'express', child: Text('Express')),
                      ],
                      onChanged: (v) => setState(() => _service = v ?? 'standard'),
                    ),
                  ),
                ]),
                if (widget.isStaff)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Map coordinates (optional - detected from the addresses)'),
                    children: [
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        _f('pickup_lat', 'Pickup latitude', required: false, width: 130),
                        _f('pickup_lng', 'Pickup longitude', required: false, width: 130),
                        _f('drop_lat', 'Drop-off latitude', required: false, width: 130),
                        _f('drop_lng', 'Drop-off longitude', required: false, width: 130),
                      ]),
                      const SizedBox(height: 8),
                    ],
                  ),
                const SizedBox(height: 12),
                Text('Estimated fee: ${money(_fee)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Book parcel'),
        ),
      ],
    );
  }
}
