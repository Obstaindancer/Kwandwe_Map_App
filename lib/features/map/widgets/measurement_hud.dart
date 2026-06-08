import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../map_provider.dart';

import 'dart:math' as math;

class MeasurementHUD extends ConsumerWidget {
  const MeasurementHUD({super.key});

  double _toRadians(double degree) => degree * math.pi / 180.0;

  double _calculatePolygonArea(List<LatLng> locations) {
    if (locations.length < 3) return 0;
    double area = 0;
    for (int i = 0; i < locations.length; i++) {
      int j = (i + 1) % locations.length;
      final p1 = locations[i];
      final p2 = locations[j];
      area += _toRadians(p2.longitude - p1.longitude) *
          (2 + math.sin(_toRadians(p1.latitude)) + math.sin(_toRadians(p2.latitude)));
    }
    area = area * 6378137.0 * 6378137.0 / 2.0;
    return area.abs(); // Area in square meters
  }

  String _getDirectionString(double bearing) {
    final b = (bearing + 360) % 360;
    final directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return directions[((b + 22.5) % 360 / 45).floor()];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);
    if (!mapState.isMeasuring) {
      return const SizedBox.shrink();
    }

    double totalMeters = 0;
    double lastSegmentMeters = 0;
    double lastBearing = 0;
    const distanceCalc = Distance();
    
    final points = mapState.measurePoints;

    for (int i = 0; i < points.length - 1; i++) {
      final dist = distanceCalc.as(LengthUnit.Meter, points[i], points[i + 1]);
      totalMeters += dist;
      if (i == points.length - 2) {
        lastSegmentMeters = dist;
        lastBearing = distanceCalc.bearing(points[i], points[i + 1]);
      }
    }
    
    // Check if shape is closed (last point close to first point, >= 3 points)
    bool isClosed = false;
    double areaHectares = 0;
    if (points.length >= 3) {
      final distToStart = distanceCalc.as(LengthUnit.Meter, points.last, points.first);
      if (distToStart < 50) { // Within 50m of start
        isClosed = true;
        areaHectares = _calculatePolygonArea(points) / 10000.0;
      }
    }

    final distStr = totalMeters > 1000
        ? '${(totalMeters / 1000).toStringAsFixed(2)} km'
        : '${totalMeters.toStringAsFixed(0)} m';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C).withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(isClosed ? Icons.architecture : Icons.straighten, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Measurement Mode',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  if (isClosed)
                    Text(
                      'Area: ${areaHectares.toStringAsFixed(2)} ha',
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    )
                  else ...[
                    Text(
                      'Total: $distStr',
                      style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (points.length > 1)
                      Text(
                        'Last: ${lastSegmentMeters.toStringAsFixed(0)}m @ ${_getDirectionString(lastBearing)} (${((lastBearing+360)%360).toStringAsFixed(0)}°)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.white54),
              onPressed: points.isNotEmpty
                  ? () => ref.read(mapProvider.notifier).undoMeasurePoint()
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => ref.read(mapProvider.notifier).toggleMeasuring(),
            ),
          ],
        ),
      ),
    );
  }
}
