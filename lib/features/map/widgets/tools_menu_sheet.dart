import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../map_provider.dart';

class ToolsMenuSheet extends ConsumerWidget {
  const ToolsMenuSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.straighten, color: Colors.orangeAccent),
              title: const Text('Measure Distance', style: TextStyle(color: Colors.white, fontSize: 16)),
              subtitle: const Text('Tap on the map to measure distances', style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                ref.read(mapProvider.notifier).toggleMeasuring();
              },
            ),
            ListTile(
              leading: Icon(
                mapState.isRecordingDrive ? Icons.stop : Icons.directions_walk,
                color: mapState.isRecordingDrive ? Colors.red : Colors.green.shade400,
              ),
              title: Text(mapState.isRecordingDrive ? 'Stop Tracking' : 'Track Drive/Walk', style: const TextStyle(color: Colors.white, fontSize: 16)),
              subtitle: const Text('Record your path on the map', style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                ref.read(mapProvider.notifier).toggleDriveRecording();
              },
            ),
            if (mapState.driveTrack.isNotEmpty && !mapState.isRecordingDrive)
              ListTile(
                leading: Icon(Icons.delete_sweep, color: Colors.red.shade400),
                title: const Text('Clear Track', style: TextStyle(color: Colors.white, fontSize: 16)),
                subtitle: const Text('Remove the recorded path from the map', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(mapProvider.notifier).clearDriveTrack();
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
