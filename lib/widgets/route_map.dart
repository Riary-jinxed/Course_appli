import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/run.dart';

/// Carte OpenStreetMap avec le tracé et les checkpoints.
class RouteMap extends StatelessWidget {
  final List<TrackPoint> points;
  final List<Checkpoint> checkpoints;
  final bool follow;
  final MapController? controller;

  const RouteMap({
    super.key,
    required this.points,
    this.checkpoints = const [],
    this.follow = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final line = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final color = Theme.of(context).colorScheme.primary;
    final options = line.length >= 2 && !follow
        ? MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: line,
              padding: const EdgeInsets.all(32),
            ),
          )
        : MapOptions(
            initialCenter: line.isEmpty ? const LatLng(46.6, 2.4) : line.last,
            initialZoom: line.isEmpty ? 5 : 16,
          );
    return FlutterMap(
      mapController: controller,
      options: options,
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.riaryjinxed.course_appli',
        ),
        if (line.length >= 2)
          PolylineLayer(polylines: [Polyline(points: line, strokeWidth: 5, color: color)]),
        MarkerLayer(markers: [
          for (final (i, c) in checkpoints.indexed)
            Marker(
              point: LatLng(c.lat, c.lng),
              width: 28,
              height: 28,
              child: CircleAvatar(
                backgroundColor: Colors.amber,
                child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.black)),
              ),
            ),
          if (line.isNotEmpty)
            Marker(
              point: line.last,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
        ]),
        const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }
}
