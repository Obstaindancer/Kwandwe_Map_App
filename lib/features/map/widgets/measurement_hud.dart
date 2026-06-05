import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../map_provider.dart';

class MeasurementHUD extends ConsumerWidget {
  const MeasurementHUD({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);
    if (!mapState.isMeasuring) {
      return const SizedBox.shrink();
    }

    double totalMeters = 0;
    const distanceCalc = Distance();
    for (int i = 0; i < mapState.measurePoints.length - 1; i++) {
      totalMeters += distanceCalc.as(
        LengthUnit.Meter,
        mapState.measurePoints[i],
        mapState.measurePoints[i + 1],
      );
    }
    
    final distStr = totalMeters > 1000
        ? '${(totalMeters / 1000).toStringAsFixed(2)} km'
        : '${totalMeters.toStringAsFixed(0)} m';

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
            const Icon(Icons.straighten, color: Colors.orangeAccent, size: 28),
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
                  Text(
                    'Distance: $distStr',
                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.white54),
              onPressed: mapState.measurePoints.isNotEmpty
                  ? () => ref.read(mapProvider.notifier).clearMeasurePoints()
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
