import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../state/auth_state.dart';
import '../utils.dart';

/// Runs route optimization for a rider and shows the ordered stops.
Future<void> showRouteDialog(BuildContext context, {required int riderId}) {
  final api = context.read<AuthState>().api;
  return showDialog(
    context: context,
    builder: (_) => _RouteDialog(future: api.post('/riders/$riderId/optimize-route')),
  );
}

class _RouteDialog extends StatelessWidget {
  final Future<dynamic> future;
  const _RouteDialog({required this.future});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Optimized delivery route'),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<dynamic>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return Text(errText(snap.error!), style: TextStyle(color: Colors.red.shade700));
            }
            final d = Map<String, dynamic>.from(snap.data);
            final stops = parseParcels(d['stops']);
            if (stops.isEmpty) return const Text('No active deliveries to route.');
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stops.length} stops  •  ${d['total_distance_km']} km  •  about ${d['estimated_minutes']} min',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nearest-stop-first ordering from the rider\'s last known location. '
                  'Distances are estimates (straight line x 1.3).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in stops)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(radius: 14, child: Text('${p.routeOrder ?? '-'}')),
                          title: Text(p.deliveryAddress),
                          subtitle: Text(
                            '${p.trackingNumber}  •  ${p.receiverName}'
                            '${p.routeDistanceKm != null ? '  •  +${p.routeDistanceKm} km' : '  •  no map location'}',
                          ),
                          trailing: p.mapsUrl == null
                              ? null
                              : IconButton(
                                  tooltip: 'Open in Google Maps',
                                  icon: const Icon(Icons.directions),
                                  onPressed: () => launchUrl(Uri.parse(p.mapsUrl!), mode: LaunchMode.externalApplication),
                                ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
