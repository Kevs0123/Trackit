import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../utils.dart';
import '../../utils/download.dart';
import '../../widgets/stat_card.dart';

/// Delivery reports + efficiency (success rate, delivery time) and usability (customer ratings).
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 29));
  DateTime _to = DateTime.now();
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;

  final _fmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, String> get _query => {'from': _fmt.format(_from), 'to': _fmt.format(_to)};

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await context.read<AuthState>().api.get('/reports/deliveries', query: _query);
      if (mounted) setState(() {
        _d = Map<String, dynamic>.from(d);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
    _load();
  }

  Future<void> _export() async {
    try {
      final csv = await context.read<AuthState>().api.getText('/reports/export', query: _query);
      downloadTextFile('trackit-report-${_fmt.format(_from)}-to-${_fmt.format(_to)}.csv', csv);
    } catch (e) {
      if (mounted) showSnack(context, errText(e), error: true);
    }
  }

  String _pct(dynamic v) => v == null ? 'n/a' : '$v%';

  String _duration(dynamic minutes) {
    if (minutes == null) return 'n/a';
    final m = (minutes as num).toInt();
    return m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pick(true),
              icon: const Icon(Icons.date_range),
              label: Text('From ${_fmt.format(_from)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pick(false),
              icon: const Icon(Icons.date_range),
              label: Text('To ${_fmt.format(_to)}'),
            ),
            FilledButton.icon(onPressed: _export, icon: const Icon(Icons.download), label: const Text('Export CSV')),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading && d == null)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Text(_error!)
        else if (d != null) ...[
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              StatCard(icon: Icons.inventory_2, label: 'Parcels booked', value: '${d['total_booked']}'),
              StatCard(icon: Icons.check_circle, label: 'Delivered', value: '${d['delivered']}', color: Colors.green),
              StatCard(icon: Icons.error_outline, label: 'Failed', value: '${d['failed']}', color: Colors.red),
              StatCard(icon: Icons.cancel_outlined, label: 'Cancelled', value: '${d['cancelled']}', color: Colors.grey),
              StatCard(icon: Icons.percent, label: 'Delivery success rate', value: _pct(d['success_rate']), color: Colors.teal),
              StatCard(icon: Icons.timer_outlined, label: 'Avg. delivery time', value: _duration(d['avg_delivery_minutes']), color: Colors.indigo),
              StatCard(
                icon: Icons.star,
                label: 'Avg. customer rating (${d['ratings_count']})',
                value: d['avg_rating'] == null ? 'n/a' : '${d['avg_rating']} / 5',
                color: Colors.amber.shade800,
              ),
              StatCard(icon: Icons.notifications_active, label: 'Notifications sent', value: '${d['notifications_sent']}', color: Colors.deepPurple),
              StatCard(icon: Icons.payments_outlined, label: 'Total fees', value: money(d['total_fees'] as num?), color: Colors.green.shade800),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Performance by rider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Rider')),
                DataColumn(label: Text('Assigned'), numeric: true),
                DataColumn(label: Text('Delivered'), numeric: true),
                DataColumn(label: Text('Failed'), numeric: true),
                DataColumn(label: Text('Success rate'), numeric: true),
                DataColumn(label: Text('Avg. time'), numeric: true),
              ],
              rows: [
                for (final r in (d['by_rider'] as List))
                  DataRow(cells: [
                    DataCell(Text('${r['rider']}')),
                    DataCell(Text('${r['assigned']}')),
                    DataCell(Text('${r['delivered']}')),
                    DataCell(Text('${r['failed']}')),
                    DataCell(Text(_pct(r['success_rate']))),
                    DataCell(Text(_duration(r['avg_minutes']))),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Daily bookings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Booked'), numeric: true),
                DataColumn(label: Text('Delivered'), numeric: true),
              ],
              rows: [
                for (final r in (d['daily'] as List))
                  DataRow(cells: [
                    DataCell(Text('${r['date']}')),
                    DataCell(Text('${r['booked']}')),
                    DataCell(Text('${r['delivered']}')),
                  ]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
