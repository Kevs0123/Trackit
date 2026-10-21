import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../state/auth_state.dart';
import '../../utils.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/stat_grid.dart';
import '../../widgets/status_chip.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _d;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<AuthState>().api.get('/dashboard');
      if (mounted) {
        setState(() {
          _d = Map<String, dynamic>.from(d);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _d == null) return Center(child: Text(_error!));
    final d = _d;
    if (d == null) return const Center(child: CircularProgressIndicator());

    final byStatus =
        Map<String, dynamic>.from(d['by_status'] is Map ? d['by_status'] : {});

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StatGrid(
            children: [
              StatCard(
                  icon: Icons.inventory_2,
                  label: 'Total parcels',
                  value: '${d['total']}'),
              StatCard(
                  icon: Icons.add_box,
                  label: 'Booked today',
                  value: '${d['booked_today']}',
                  color: Colors.indigo),
              StatCard(
                icon: Icons.hourglass_top,
                label: 'Awaiting rider',
                value: '${d['awaiting_assignment']}',
                color: Colors.deepOrange,
              ),
              StatCard(
                  icon: Icons.local_shipping,
                  label: 'On the road',
                  value: '${d['active']}',
                  color: Colors.blue),
              StatCard(
                icon: Icons.check_circle,
                label: 'Delivered today',
                value: '${d['delivered_today']}',
                color: Colors.green,
              ),
              StatCard(
                  icon: Icons.two_wheeler,
                  label: 'Active riders',
                  value: '${d['riders']}',
                  color: Colors.teal),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Parcels by status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final s in statusLabels.keys)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  StatusChip(s),
                  const SizedBox(width: 6),
                  Text('${byStatus[s] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
            ],
          ),
          const SizedBox(height: 12),
          Text('Refreshes automatically every 15 seconds.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}
