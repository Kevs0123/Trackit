import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/auth_state.dart';
import '../utils.dart';

/// Staff picks a rider for a parcel. Pops `true` when assigned.
class AssignRiderDialog extends StatefulWidget {
  final Parcel parcel;
  const AssignRiderDialog({super.key, required this.parcel});

  @override
  State<AssignRiderDialog> createState() => _AssignRiderDialogState();
}

class _AssignRiderDialogState extends State<AssignRiderDialog> {
  List<AppUser> _riders = [];
  int? _selected;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<AuthState>().api.get('/riders');
      final riders = (d as List)
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.isActive)
          .toList();
      if (mounted) setState(() => _riders = riders);
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().api.post('/parcels/${widget.parcel.id}/assign', {'rider_id': _selected});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign ${widget.parcel.trackingNumber}'),
      content: SizedBox(
        width: 380,
        child: _loading
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('To: ${widget.parcel.deliveryAddress}'),
                  const SizedBox(height: 12),
                  if (_riders.isEmpty)
                    const Text('No active riders yet. Add one in the Riders tab.')
                  else
                    DropdownButtonFormField<int>(
                      value: _selected,
                      decoration: const InputDecoration(labelText: 'Rider', border: OutlineInputBorder()),
                      items: [
                        for (final r in _riders)
                          DropdownMenuItem(value: r.id, child: Text('${r.name}  (${r.activeParcels} active)')),
                      ],
                      onChanged: (v) => setState(() => _selected = v),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: (_selected == null || _busy) ? null : _assign, child: const Text('Assign')),
      ],
    );
  }
}
