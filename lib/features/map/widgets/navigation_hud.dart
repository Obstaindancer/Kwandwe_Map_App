import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../map_provider.dart';

class NavigationHUD extends ConsumerWidget {
  const NavigationHUD({super.key});

  String _getBearingString(double bearing) {
    if (bearing < 0) bearing += 360;
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) % 360) / 45;
    return directions[index.floor()];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);
    if (mapState.activeNavPin == null || mapState.currentPosition == null) {
      return const SizedBox.shrink();
    }

    final currentPos = LatLng(
      mapState.currentPosition!.latitude,
      mapState.currentPosition!.longitude,
    );
    final targetPos = mapState.activeNavPin!.position;
    const distanceCalc = Distance();
    final meters = distanceCalc.as(LengthUnit.Meter, currentPos, targetPos);
    final bearingDeg = distanceCalc.bearing(currentPos, targetPos);
    final bearingStr = _getBearingString(bearingDeg);
    
    final distStr = meters > 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '${meters.toStringAsFixed(0)} m';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.navigation, color: mapState.activeNavPin!.colour, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mapState.activeNavPin!.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        distStr,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Bearing: $bearingStr',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => ref.read(mapProvider.notifier).stopNavigation(),
            ),
          ],
        ),
      ),
    );
  }
}
