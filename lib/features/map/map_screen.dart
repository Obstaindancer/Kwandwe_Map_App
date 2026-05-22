import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
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

  void _onLongPress(TapPosition tapPosition, LatLng point) async {
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
                Icon(Icons.location_on, color: pin.colour),
                const SizedBox(width: 8),
                Text(pin.label,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Spacer(),
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
            Text(
              '${pin.position.latitude.toStringAsFixed(6)}, '
              '${pin.position.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                  color: Color(0xFFD4A843),
                  fontFamily: 'monospace',
                  fontSize: 13),
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
        title: const Text('Kwandwe Map'),
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
                        onTap: () => _showPinDetail(pin),
                        child: Icon(
                          Icons.location_on,
                          color: pin.colour,
                          size: 36,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black54)
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // GPS recenter button
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton.small(
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCoordinateSheet,
        icon: const Icon(Icons.gps_fixed),
        label: const Text('Go to Coordinates'),
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
    );
  }
}
