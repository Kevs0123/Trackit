import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap view (free, no API key): pickup (green), destination (red), rider (blue).
class ParcelMap extends StatelessWidget {
  final LatLng? pickup;
  final LatLng? drop;
  final LatLng? rider;
  final double height;

  const ParcelMap({super.key, this.pickup, this.drop, this.rider, this.height = 300});

  Marker _marker(LatLng point, IconData icon, Color color) => Marker(
        point: point,
        width: 44,
        height: 44,
        child: Icon(icon, color: color, size: 38),
      );

  @override
  Widget build(BuildContext context) {
    final p = pickup, d = drop, r = rider;
    final points = <LatLng>[if (p != null) p, if (d != null) d, if (r != null) r];
    if (points.isEmpty) return const SizedBox.shrink();

    final options = points.length > 1
        ? MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(48),
              maxZoom: 16,
            ),
          )
        : MapOptions(initialCenter: points.first, initialZoom: 14);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: options,
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.trackit_app',
            ),
            MarkerLayer(markers: [
              if (p != null) _marker(p, Icons.location_on, Colors.green.shade700),
              if (d != null) _marker(d, Icons.flag, Colors.red.shade700),
              if (r != null) _marker(r, Icons.two_wheeler, Colors.blue.shade800),
            ]),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
    );
  }
}
