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

            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.file_upload, color: Colors.blueAccent),
              title: const Text('Import GPX Track', style: TextStyle(color: Colors.white, fontSize: 16)),
              subtitle: const Text('Load external tracks onto the map', style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                ref.read(mapProvider.notifier).importGpxFile();
              },
            ),
            if (mapState.importedTracks.isNotEmpty)
              ListTile(
                leading: Icon(Icons.layers_clear, color: Colors.orangeAccent.shade400),
                title: const Text('Clear Imported Tracks', style: TextStyle(color: Colors.white, fontSize: 16)),
                subtitle: const Text('Remove all imported GPX tracks', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(mapProvider.notifier).clearImportedTracks();
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
