import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../../models/pin_model.dart';
import '../coordinates/coordinate_input_sheet.dart';
import '../pins/pin_selection_sheet.dart';
import '../pins/pins_provider.dart';
import 'map_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission denied. Cannot show GPS position.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location permanently denied. Please enable in settings.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => Geolocator.openAppSettings(),
          ),
        ),
      );
      return;
    }

    ref.read(mapProvider.notifier).startTracking();
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    if (ref.read(mapProvider).isMeasuring) {
      ref.read(mapProvider.notifier).addMeasurePoint(point);
    }
  }

  void _onLongPress(TapPosition tapPosition, LatLng point) async {
    if (ref.read(mapProvider).isMeasuring) return; // Disable pins while measuring

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const PinSelectionSheet(),
    );

    if (result != null) {
      ref.read(pinsProvider.notifier).addPin(
            position: point,
            label: result['label'] as String,
            type: result['type'] as PinType,
          );
    }
  }

  void _openCoordinateSheet() async {
    final result = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const CoordinateInputSheet(),
    );

    if (result != null) {
      _mapController.move(result, 15.0);
      
      if (!mounted) return;
      final pinInfo = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF2C2C2C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => const PinSelectionSheet(),
      );

      if (pinInfo != null) {
        ref.read(pinsProvider.notifier).addPin(
              position: result,
              label: pinInfo['label'] as String,
              type: pinInfo['type'] as PinType,
            );
      }
    }
  }

  void _centreOnGps() {
    final position = ref.read(mapProvider).currentPosition;
    if (position != null) {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
    }
  }

  void _showPinDetail(MapPin pin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(pin.icon, color: pin.colour),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(pin.label,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    ref.read(pinsProvider.notifier).removePin(pin.id);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(pin.typeLabel,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${pin.position.latitude.toStringAsFixed(6)}, '
                    '${pin.position.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                        color: Color(0xFFD4A843),
                        fontFamily: 'monospace',
                        fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                  onPressed: () {
                    final coords = '${pin.position.latitude.toStringAsFixed(6)}, ${pin.position.longitude.toStringAsFixed(6)}';
                    Clipboard.setData(ClipboardData(text: coords));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coordinates copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Dropped: ${_formatTime(pin.createdAt)}',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.navigation),
                label: const Text('Navigate to Pin'),
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(mapProvider.notifier).startNavigation(pin);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getBearingString(double bearing) {
    if (bearing < 0) bearing += 360;
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) % 360) / 45;
    return directions[index.floor()];
  }

  // ── Loading screen shown only on first launch while tile extracts ─────────
  Widget _buildLoadingScreen(double progress) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png',
                  width: 80,
                  errorBuilder: (_, __, ___) => const Icon(
                        Icons.terrain,
                        size: 80,
                        color: Color(0xFFD4A843),
                      )),
              const SizedBox(height: 32),
              const Text(
                'Kwandwe Map',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Preparing map for first use...',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF3A3A3A),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFD4A843)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                progress > 0
                    ? '${(progress * 100).toStringAsFixed(0)}%'
                    : 'Loading...',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'This only happens once',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error screen if MBTiles file is missing from APK ─────────────────────
  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Map file not found',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'Place kwandwe_2024.mbtiles in:\n'
                'android/app/src/main/assets/tiles/',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error,
                  style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    final pins = ref.watch(pinsProvider);

    // Show loading screen on first launch tile extraction
    if (mapState.tileStatus == TileLoadStatus.loading) {
      return _buildLoadingScreen(mapState.tileLoadProgress);
    }

    // Show error screen if MBTiles file is missing
    if (mapState.tileStatus == TileLoadStatus.error) {
      return _buildErrorScreen(mapState.tileError ?? 'Unknown error');
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kwandwe Map', style: TextStyle(fontSize: 18)),
            if (mapState.currentPosition != null)
              Row(
                children: [
                  Text(
                    '${mapState.currentPosition!.latitude.toStringAsFixed(5)}, ${mapState.currentPosition!.longitude.toStringAsFixed(5)} • ±${mapState.currentPosition!.accuracy.toStringAsFixed(0)}m',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final coords = '${mapState.currentPosition!.latitude.toStringAsFixed(5)}, ${mapState.currentPosition!.longitude.toStringAsFixed(5)}';
                      Clipboard.setData(ClipboardData(text: coords));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Your coordinates copied to clipboard')),
                      );
                    },
                    child: const Icon(Icons.copy, size: 14, color: Colors.blue),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          if (pins.isNotEmpty)
            TextButton.icon(
              onPressed: () =>
                  ref.read(pinsProvider.notifier).clearAll(),
              icon: const Icon(Icons.clear_all, color: Colors.white70),
              label: const Text('Clear pins',
                  style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                AppConstants.reserveLat,
                AppConstants.reserveLng,
              ),
              initialZoom: AppConstants.initialZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(AppConstants.boundsSouthWestLat, AppConstants.boundsSouthWestLng),
                  const LatLng(AppConstants.boundsNorthEastLat, AppConstants.boundsNorthEastLng),
                ),
              ),
              onTap: _onTap,
              onLongPress: _onLongPress,
            ),
            children: [
              // Kwandwe MBTiles base layer — bundled in APK
              if (mapState.tilePath != null)
                MbTilesLayer(mbTilesPath: mapState.tilePath!),

              // GPS accuracy circle
              if (mapState.currentPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(
                        mapState.currentPosition!.latitude,
                        mapState.currentPosition!.longitude,
                      ),
                      radius: mapState.currentPosition!.accuracy,
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.15),
                      borderColor: Colors.blue.withOpacity(0.4),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),

              // Navigation Line
              if (mapState.activeNavPin != null && mapState.currentPosition != null)
                PolylineLayer(
                  polylines: <Polyline<Object>>[
                    Polyline<Object>(
                      points: [
                        LatLng(
                          mapState.currentPosition!.latitude,
                          mapState.currentPosition!.longitude,
                        ),
                        mapState.activeNavPin!.position,
                      ],
                      color: Colors.blue,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),

              // Route Tracing (Drive Track)
              if (mapState.driveTrack.isNotEmpty)
                PolylineLayer(
                  polylines: <Polyline<Object>>[
                    Polyline<Object>(
                      points: mapState.driveTrack,
                      color: Colors.green.withOpacity(0.8),
                      strokeWidth: 5.0,
                    ),
                  ],
                ),

              // Distance Measurement Tool
              if (mapState.isMeasuring && mapState.measurePoints.isNotEmpty)
                PolylineLayer(
                  polylines: <Polyline<Object>>[
                    Polyline<Object>(
                      points: mapState.measurePoints,
                      color: Colors.orangeAccent,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),


              // Markers layer
              MarkerLayer(
                markers: [
                  // GPS blue dot
                  if (mapState.currentPosition != null)
                    Marker(
                      point: LatLng(
                        mapState.currentPosition!.latitude,
                        mapState.currentPosition!.longitude,
                      ),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.blue.withOpacity(0.4),
                                blurRadius: 6)
                          ],
                        ),
                      ),
                    ),

                  // User pins
                  ...pins.map(
                    (pin) => Marker(
                      point: pin.position,
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () {
                          if (!mapState.isMeasuring) _showPinDetail(pin);
                        },
                        child: Icon(
                          pin.icon,
                          color: pin.colour,
                          size: 36,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black54)
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Measurement Points Nodes
                  if (mapState.isMeasuring)
                    ...mapState.measurePoints.map(
                      (point) => Marker(
                        point: point,
                        width: 12,
                        height: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              // Scale Bar
              const Scalebar(
                alignment: Alignment.topRight,
                padding: EdgeInsets.only(right: 16, top: 72),
                textStyle: TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                lineColor: Colors.white,
              ),
            ],
          ),
          
          // North Arrow
          Positioned(
            top: 16,
            right: 16,
            child: StreamBuilder<MapEvent>(
              stream: _mapController.mapEventStream,
              builder: (context, snapshot) {
                final rotation = _mapController.camera.rotation;
                if (rotation == 0.0) return const SizedBox.shrink();
                
                return FloatingActionButton.small(
                  heroTag: 'north_arrow',
                  onPressed: () {
                    _mapController.rotate(0.0);
                  },
                  backgroundColor: const Color(0xFF2C2C2C),
                  child: Transform.rotate(
                    angle: -rotation * (math.pi / 180),
                    child: const Icon(Icons.arrow_upward, color: Colors.red),
                  ),
                );
              },
            ),
          ),





          // Navigation HUD
          if (mapState.activeNavPin != null && mapState.currentPosition != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Builder(
                builder: (context) {
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

                  return Card(
                    color: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.navigation, color: mapState.activeNavPin!.colour, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                },
              ),
            ),

          // Measurement HUD
          if (mapState.isMeasuring)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Builder(
                builder: (context) {
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

                  return Card(
                    color: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten, color: Colors.orangeAccent, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                },
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (mapState.currentPosition != null && mapState.currentPosition!.heading > 0) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2C),
                shape: BoxShape.circle,
              ),
              child: Transform.rotate(
                angle: mapState.currentPosition!.heading * (math.pi / 180),
                child: const Icon(Icons.navigation, color: Colors.blue, size: 28),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.small(
            heroTag: 'gps',
            onPressed: _centreOnGps,
            backgroundColor: const Color(0xFF2C2C2C),
            child: Icon(
              mapState.isTracking
                  ? Icons.my_location
                  : Icons.location_searching,
              color: mapState.isTracking
                  ? Colors.blue
                  : Colors.white54,
            ),
          ),
          const SizedBox(height: 12),
          if (mapState.driveTrack.isNotEmpty && !mapState.isRecordingDrive) ...[
            SizedBox(
              height: 44,
              child: FloatingActionButton.extended(
                heroTag: 'clear_track',
                onPressed: () => ref.read(mapProvider.notifier).clearDriveTrack(),
                icon: const Icon(Icons.delete_sweep, color: Colors.white, size: 20),
                label: const Text('Clear Track', style: TextStyle(color: Colors.white, fontSize: 13)),
                backgroundColor: Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 44,
            child: FloatingActionButton.extended(
              heroTag: 'measure_toggle',
              onPressed: () => ref.read(mapProvider.notifier).toggleMeasuring(),
              icon: Icon(
                mapState.isMeasuring ? Icons.close : Icons.straighten,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                mapState.isMeasuring ? 'Stop Measuring' : 'Measure Distance',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              backgroundColor: mapState.isMeasuring ? Colors.grey.shade700 : Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FloatingActionButton.extended(
              heroTag: 'track_toggle',
              onPressed: () => ref.read(mapProvider.notifier).toggleDriveRecording(),
              icon: Icon(
                mapState.isRecordingDrive ? Icons.stop : Icons.directions_walk,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                mapState.isRecordingDrive ? 'Stop Tracking' : 'Track Drive/Walk',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              backgroundColor: mapState.isRecordingDrive ? Colors.red : Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FloatingActionButton.extended(
              heroTag: 'go_to_coords',
              onPressed: _openCoordinateSheet,
              icon: const Icon(Icons.gps_fixed, size: 20),
              label: const Text('Go to Coordinates', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class MbTilesLayer extends StatefulWidget {
  final String mbTilesPath;
  const MbTilesLayer({super.key, required this.mbTilesPath});

  @override
  State<MbTilesLayer> createState() => _MbTilesLayerState();
}

class _MbTilesLayerState extends State<MbTilesLayer> {
  late final MbTilesTileProvider _tileProvider;

  @override
  void initState() {
    super.initState();
    _tileProvider = MbTilesTileProvider.fromPath(path: widget.mbTilesPath);
  }

  @override
  void dispose() {
    _tileProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      tileProvider: _tileProvider,
      maxNativeZoom: 16, // Maximum zoom level physically in the MBTiles file
      maxZoom: 22,       // Allows stretching the level 16 tiles to look closer
    );
  }
}
