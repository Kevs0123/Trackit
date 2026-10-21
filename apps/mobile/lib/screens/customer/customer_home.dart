import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../state/auth_state.dart';
import '../../utils.dart';
import '../../widgets/parcel_form.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/account_menu.dart';

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
        _notes =
            (notes as List).map((e) => Map<String, dynamic>.from(e)).toList();
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
      showSnack(
        context,
        'Parcel booked! Tracking number: ${created.trackingNumber}',
        actionLabel: 'COPY',
        onAction: () => copyTrackingNumber(context, created.trackingNumber),
      );
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
          title: const Text('My parcels'),
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
          bottom: TabBar(tabs: [
            const Tab(
                icon: Icon(Icons.inventory_2_outlined), text: 'My parcels'),
            Tab(
              icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined)),
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
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 48),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
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
              onSubmitted: (v) => v.trim().isEmpty
                  ? null
                  : Navigator.pushNamed(
                      context, '/track/${v.trim().toUpperCase()}'),
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
                child: Center(
                    child: Text(
                        'You have no parcels yet. Tap "Book parcel" to send one.')),
              ),
            for (final p in _parcels)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pushNamed(
                      context, '/track/${p.trackingNumber}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(
                                  p.trackingNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  tooltip: 'Copy tracking number',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () => copyTrackingNumber(
                                      context, p.trackingNumber),
                                ),
                              ],
                            ),
                            StatusChip(p.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Delivering to ${p.receiverName}'),
                        Text(p.deliveryAddress,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${money(p.fee)}  •  ${fmtDate(p.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall),
                        if (p.status == 'booked')
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _cancel(p),
                              child: const Text('Cancel parcel'),
                            ),
                          ),
                      ],
                    ),
                  ),
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
                child: TextButton(
                    onPressed: _markRead,
                    child: const Text('Mark all as read')),
              ),
            if (_notes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: Text(
                        'No notifications yet. You are notified every time a parcel changes status.')),
              ),
            for (final n in _notes)
              Card(
                color: n['read_at'] == null
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.4)
                    : null,
                child: ListTile(
                  leading: Icon(n['read_at'] == null
                      ? Icons.notifications_active
                      : Icons.notifications_none),
                  title: Text('${n['message']}'),
                  subtitle: Text(fmtDate(
                      DateTime.tryParse('${n['created_at']}')?.toLocal())),
                  onTap: () {
                    final tn = (n['parcel'] is Map)
                        ? n['parcel']['tracking_number']
                        : null;
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
