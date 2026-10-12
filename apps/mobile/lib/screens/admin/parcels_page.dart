import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../state/auth_state.dart';
import '../../utils.dart';
import '../../widgets/assign_dialog.dart';
import '../../widgets/parcel_form.dart';
import '../../widgets/status_chip.dart';

class ParcelsPage extends StatefulWidget {
  const ParcelsPage({super.key});

  @override
  State<ParcelsPage> createState() => _ParcelsPageState();
}

class _ParcelsPageState extends State<ParcelsPage> {
  final _search = TextEditingController();
  String _status = '';
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  List<Parcel> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await context.read<AuthState>().api.get('/parcels', query: {
        'page': '$_page',
        if (_status.isNotEmpty) 'status': _status,
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _items = parseParcels(d['data']);
        _lastPage = (d['last_page'] as num?)?.toInt() ?? 1;
        _total = (d['total'] as num?)?.toInt() ?? 0;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    _page = 1;
    _load();
  }

  Future<void> _newParcel() async {
    final created = await showDialog<Parcel>(
      context: context,
      builder: (_) => const ParcelFormDialog(isStaff: true),
    );
    if (created != null && mounted) {
      showSnack(context, 'Parcel booked. Tracking number: ${created.trackingNumber}');
      _applyFilters();
    }
  }

  Future<void> _assign(Parcel p) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AssignRiderDialog(parcel: p));
    if (ok == true && mounted) {
      showSnack(context, 'Rider assigned and customer notified.');
      _load();
    }
  }

  Future<void> _cancel(Parcel p) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel parcel?'),
        content: Text('${p.trackingNumber} will be marked as cancelled and the customer will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel parcel')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await context.read<AuthState>().api.post('/parcels/${p.id}/status', {'status': 'cancelled', 'note': 'Cancelled by staff.'});
      if (mounted) _load();
    } catch (e) {
      if (mounted) showSnack(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newParcel,
        icon: const Icon(Icons.add),
        label: const Text('New parcel'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'Search tracking no. or name',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _applyFilters),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    isDense: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Status'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All statuses')),
                      for (final e in statusLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) {
                      _status = v ?? '';
                      _applyFilters();
                    },
                  ),
                ),
                Text('$_total parcels'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? const Center(child: Text('No parcels found.'))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                            children: [for (final p in _items) _row(p)],
                          ),
          ),
          if (_lastPage > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _page > 1 ? () { _page--; _load(); } : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page $_page of $_lastPage'),
                  IconButton(
                    onPressed: _page < _lastPage ? () { _page++; _load(); } : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(Parcel p) {
    final canAssign = p.status == 'booked' || p.status == 'assigned' || p.status == 'failed';
    return Card(
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, '/track/${p.trackingNumber}'),
        title: Row(children: [
          Flexible(child: Text(p.trackingNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          StatusChip(p.status),
        ]),
        subtitle: Text(
          '${p.senderName}  →  ${p.receiverName}\n${p.deliveryAddress}\n'
          'Rider: ${p.riderName ?? 'not assigned'}  •  ${money(p.fee)}  •  ${fmtDate(p.createdAt)}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'track') Navigator.pushNamed(context, '/track/${p.trackingNumber}');
            if (v == 'assign') _assign(p);
            if (v == 'cancel') _cancel(p);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'track', child: Text('View tracking')),
            if (canAssign) PopupMenuItem(value: 'assign', child: Text(p.riderName == null ? 'Assign rider' : 'Reassign rider')),
            if (!p.isFinal) const PopupMenuItem(value: 'cancel', child: Text('Cancel parcel')),
          ],
        ),
      ),
    );
  }
}
