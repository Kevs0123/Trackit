import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../state/auth_state.dart';
import '../../utils.dart';
import '../../widgets/parcel_form.dart';
import '../../widgets/status_chip.dart';

/// Customer area: my parcels, book a new parcel, notifications.
class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  List<Parcel> _parcels = [];
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  String? _error;
  final _track = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthState>().api;
    try {
      final parcels = await api.get('/parcels/mine');
      final notes = await api.get('/notifications');
      if (!mounted) return;
      setState(() {
        _parcels = parseParcels(parcels);
        _notes = (notes as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    final created = await showDialog<Parcel>(
      context: context,
      builder: (_) => const ParcelFormDialog(isStaff: false),
    );
    if (created != null && mounted) {
      showSnack(context, 'Parcel booked! Tracking number: ${created.trackingNumber}');
      _load();
    }
  }

  Future<void> _cancel(Parcel p) async {
    try {
      await context.read<AuthState>().api.post('/parcels/${p.id}/cancel');
      if (mounted) {
        showSnack(context, 'Parcel cancelled.');
        _load();
      }
    } catch (e) {
      if (mounted) showSnack(context, errText(e), error: true);
    }
  }

  Future<void> _markRead() async {
    try {
      await context.read<AuthState>().api.post('/notifications/read');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final unread = _notes.where((n) => n['read_at'] == null).length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('TrackIt  -  ${auth.user?.name ?? ''}'),
          actions: [
            IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
            IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => auth.logout()),
          ],
          bottom: TabBar(tabs: [
            const Tab(icon: Icon(Icons.inventory_2_outlined), text: 'My parcels'),
            Tab(
              icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
              text: 'Notifications',
            ),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _book,
          icon: const Icon(Icons.add),
          label: const Text('Book parcel'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : TabBarView(children: [_parcelsTab(), _notesTab()]),
      ),
    );
  }

  Widget _parcelsTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            TextField(
              controller: _track,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.pushNamed(context, '/track/${v.trim().toUpperCase()}'),
              decoration: const InputDecoration(
                hintText: 'Track any parcel by number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_parcels.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('You have no parcels yet. Tap "Book parcel" to send one.')),
              ),
            for (final p in _parcels)
              Card(
                child: ListTile(
                  onTap: () => Navigator.pushNamed(context, '/track/${p.trackingNumber}'),
                  title: Row(children: [
                    Flexible(child: Text(p.trackingNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    StatusChip(p.status),
                  ]),
                  subtitle: Text('To ${p.receiverName}\n${p.deliveryAddress}\n${money(p.fee)}  •  ${fmtDate(p.createdAt)}'),
                  isThreeLine: true,
                  trailing: p.status == 'booked'
                      ? TextButton(onPressed: () => _cancel(p), child: const Text('Cancel'))
                      : const Icon(Icons.chevron_right),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _notesTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_notes.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _markRead, child: const Text('Mark all as read')),
              ),
            if (_notes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No notifications yet. You are notified every time a parcel changes status.')),
              ),
            for (final n in _notes)
              Card(
                color: n['read_at'] == null ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4) : null,
                child: ListTile(
                  leading: Icon(n['read_at'] == null ? Icons.notifications_active : Icons.notifications_none),
                  title: Text('${n['message']}'),
                  subtitle: Text(fmtDate(DateTime.tryParse('${n['created_at']}')?.toLocal())),
                  onTap: () {
                    final tn = (n['parcel'] is Map) ? n['parcel']['tracking_number'] : null;
                    if (tn != null) Navigator.pushNamed(context, '/track/$tn');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
