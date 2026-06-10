import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../core/constants.dart';
import '../../models/pin_model.dart';
import '../coordinates/coordinate_input_sheet.dart';
import '../pins/pin_selection_sheet.dart';
import '../pins/pins_provider.dart';
import 'map_provider.dart';
import 'widgets/navigation_hud.dart';
import 'widgets/measurement_hud.dart';
import 'widgets/tools_menu_sheet.dart';
import 'widgets/weather_dashboard.dart';
import '../tracking/tracking_dashboard_screen.dart';
import '../../providers/tracking_provider.dart';
import '../../services/tracking_database_service.dart';
import '../tracking/track_details_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _isRotationLocked = true;
  bool _showWeather = false;
  StreamSubscription? _intentDataStreamSubscription;

  List<LatLng> _getScentConePoints(LatLng center, int windDirectionDeg) {
    double windGoingTo = (windDirectionDeg + 180) % 360;
    double coneLengthMeters = 500;
    double coneAngleSpread = 60;
    
    const distanceCalc = Distance();
    LatLng leftEdge = distanceCalc.offset(center, coneLengthMeters, windGoingTo - (coneAngleSpread / 2));
    LatLng rightEdge = distanceCalc.offset(center, coneLengthMeters, windGoingTo + (coneAngleSpread / 2));
    
    return [center, leftEdge, rightEdge];
  }

  final LayerHitNotifier<MapTrack> _hitNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();

    _hitNotifier.addListener(() async {
      final hit = _hitNotifier.value;
      if (hit != null && hit.hitValues.isNotEmpty) {
        final tappedTrack = hit.hitValues.first;
        await _openTrackDetails(tappedTrack);
        _hitNotifier.value = null; // Reset
      }
    });

    // Listen to media sharing incoming files when the app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // Get the media sharing incoming files when the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
      ReceiveSharingIntent.instance.reset();
    });
  }

  Future<void> _openTrackDetails(MapTrack track) async {
    final session = await TrackingDatabaseService().getTrackSession(track.id);
    if (session != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => TrackDetailsScreen(session: session),
        ),
      );
    }
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    for (var file in files) {
      if (file.path.toLowerCase().endsWith('.gpx')) {
        ref.read(mapProvider.notifier).handleSharedGpxFile(file.path);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported GPX: ${file.path.split('/').last}')));
      }
    }
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

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
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

  void _showToolsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ToolsMenuSheet(),
    );
  }

  void _centreOnGps() {
    final position = ref.read(mapProvider).currentPosition;
    if (position != null) {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom < 15.0 ? 15.0 : _mapController.camera.zoom,
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
    // Listen for transitions from Global Satellite to Offline Map to reset camera
    ref.listen<bool>(
      mapProvider.select((state) => state.useGlobalSatellite),
      (previous, current) {
        if (previous == true && current == false) {
          _mapController.move(
            const LatLng(AppConstants.reserveLat, AppConstants.reserveLng),
            AppConstants.initialZoom,
          );
        }
      },
    );

    // Follow Me: automatically move camera when position updates
    ref.listen<Position?>(
      mapProvider.select((state) => state.currentPosition),
      (previous, current) {
        final state = ref.read(mapProvider);
        if (state.isFollowMe && current != null) {
          _mapController.move(
            LatLng(current.latitude, current.longitude),
            _mapController.camera.zoom, // keep current zoom level
          );
        }
      },
    );

    final mapState = ref.watch(mapProvider);
    final pins = ref.watch(pinsProvider);
    final trackingState = ref.watch(trackingProvider);

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
              minZoom: mapState.useGlobalSatellite ? 2.0 : AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~(_isRotationLocked ? InteractiveFlag.rotate : InteractiveFlag.none),
              ),
              cameraConstraint: mapState.useGlobalSatellite
                  ? const CameraConstraint.unconstrained()
                  : CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(AppConstants.boundsSouthWestLat, AppConstants.boundsSouthWestLng),
                        const LatLng(AppConstants.boundsNorthEastLat, AppConstants.boundsNorthEastLng),
                      ),
                    ),
              onTap: _onTap,
              onLongPress: _onLongPress,
              onPositionChanged: (MapCamera position, bool hasGesture) {
                if (hasGesture && mapState.isFollowMe) {
                  // User manually panned the map, so break "Follow Me" mode
                  ref.read(mapProvider.notifier).setFollowMe(false);
                }
              },
            ),
            children: [
              // Map Base Layer (Always render offline layer to maintain database connection)
              if (mapState.tilePath != null)
                MbTilesLayer(mbTilesPath: mapState.tilePath!),

              // Global Satellite Overlay (Rendered on top of offline map)
              if (mapState.useGlobalSatellite)
                TileLayer(
                  urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'za.co.kwandwe.kwandwe_map',
                ),

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

              // Active Background Track
              if (trackingState.currentPoints.isNotEmpty)
                PolylineLayer(
                  polylines: <Polyline<Object>>[
                    Polyline<Object>(
                      points: trackingState.currentPoints
                          .map((p) => LatLng(p.latitude, p.longitude))
                          .toList(),
                      color: Colors.cyanAccent.withOpacity(0.8),
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

              // Imported Tracks
              if (mapState.importedTracks.isNotEmpty)
                PolylineLayer<MapTrack>(
                  hitNotifier: _hitNotifier,
                  polylines: mapState.importedTracks.map((track) {
                    return Polyline<MapTrack>(
                      points: track.points,
                      color: track.color,
                      strokeWidth: 10.0, // Increased stroke width so it's easier to tap
                      hitValue: track,
                    );
                  }).toList(),
                ),

              // Distance Measurement Tool
              if (mapState.isMeasuring && mapState.measurePoints.isNotEmpty) ...[
                PolylineLayer(
                  polylines: <Polyline<Object>>[
                    Polyline<Object>(
                      points: mapState.measurePoints,
                      color: Colors.orangeAccent,
                      strokeWidth: 4.0,
                      pattern: StrokePattern.dashed(segments: const [10.0, 10.0]),
                    ),
                  ],
                ),
                CircleLayer(
                  circles: mapState.measurePoints.map((p) => CircleMarker(
                    point: p,
                    color: Colors.white,
                    borderColor: Colors.orangeAccent,
                    borderStrokeWidth: 2,
                    radius: 5,
                  )).toList(),
                ),
              ],

              // Wind Scent Cone
              if (_showWeather && mapState.weather != null && mapState.currentPosition != null)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _getScentConePoints(
                        LatLng(mapState.currentPosition!.latitude, mapState.currentPosition!.longitude),
                        mapState.weather!.windDirection,
                      ),
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderColor: Colors.blueAccent.withValues(alpha: 0.5),
                      borderStrokeWidth: 1.0,
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
              Scalebar(
                alignment: Alignment.bottomLeft,
                padding: EdgeInsets.only(left: 16, bottom: 24 + MediaQuery.of(context).padding.bottom),
                textStyle: const TextStyle(
                  color: Colors.white, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
                lineColor: Colors.white,
              ),
            ],
          ),
          // Safe Area for Overlays
          SafeArea(
            child: Stack(
              children: [
                // North Arrow
                Positioned(
                  top: 16,
                  right: 16,
                  child: StreamBuilder<MapEvent>(
                    stream: _mapController.mapEventStream,
                    builder: (context, snapshot) {
                      final rotation = _mapController.camera.rotation;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_isRotationLocked) {
                              _isRotationLocked = false;
                            } else {
                              _mapController.rotate(0.0);
                              _isRotationLocked = true;
                            }
                          });
                        },
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2C).withValues(alpha: 0.8),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Transform.rotate(
                                    angle: -rotation * (math.pi / 180),
                                    child: CustomPaint(
                                      size: const Size(14, 28),
                                      painter: CompassNeedlePainter(),
                                    ),
                                  ),
                                  if (_isRotationLocked)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white24, width: 1),
                                        ),
                                        child: const Icon(Icons.lock, color: Colors.white, size: 10),
                                      ),
                                    )
                                  else
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white24, width: 1),
                                        ),
                                        child: const Icon(Icons.lock_open, color: Colors.white70, size: 10),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // HUD Overlays
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, -0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: mapState.isMeasuring 
                            ? const MeasurementHUD(key: ValueKey('MeasurementHUD'))
                            : (mapState.activeNavPin != null && mapState.currentPosition != null)
                                ? const NavigationHUD(key: ValueKey('NavigationHUD'))
                                : const SizedBox.shrink(key: ValueKey('EmptyHUD')),
                      ),
                      if (_showWeather) ...[
                        const SizedBox(height: 16),
                        const WeatherDashboard(),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: SafeArea(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (mapState.currentPosition != null && mapState.currentPosition!.heading > 0) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C).withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                ],
              ),
              child: Transform.rotate(
                angle: mapState.currentPosition!.heading * (math.pi / 180),
                child: const Icon(Icons.navigation, color: Colors.blue, size: 28),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.small(
            heroTag: 'weather_toggle',
            onPressed: () {
              setState(() {
                _showWeather = !_showWeather;
              });
            },
            backgroundColor: const Color(0xFF2C2C2C).withValues(alpha: 0.9),
            elevation: 4,
            child: Icon(
              _showWeather ? Icons.cloud_off : Icons.cloud,
              color: _showWeather ? Colors.blue : Colors.white54,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'gps',
            onPressed: _centreOnGps,
            backgroundColor: const Color(0xFF2C2C2C).withValues(alpha: 0.9),
            elevation: 4,
            child: Icon(
              mapState.isFollowMe
                  ? Icons.explore
                  : (mapState.isTracking ? Icons.my_location : Icons.location_searching),
              color: mapState.isFollowMe
                  ? Colors.greenAccent
                  : (mapState.isTracking ? Colors.blue : Colors.white54),
            ),
          ),

          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'tools_menu',
            onPressed: _showToolsMenu,
            backgroundColor: const Color(0xFF2C2C2C).withValues(alpha: 0.9),
            elevation: 4,
            icon: Icon(
              mapState.isMeasuring || mapState.isRecordingDrive 
                  ? Icons.build_circle 
                  : Icons.build, 
              color: mapState.isMeasuring || mapState.isRecordingDrive 
                  ? Colors.blueAccent 
                  : Colors.white
            ),
            label: const Text('Tools', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'tracking_dashboard',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingDashboardScreen()));
            },
            backgroundColor: const Color(0xFF2C2C2C).withValues(alpha: 0.9),
            elevation: 4,
            icon: Icon(
              trackingState.status != TrackingStatus.stopped 
                  ? Icons.track_changes 
                  : Icons.directions_walk,
              color: trackingState.status == TrackingStatus.recording
                  ? Colors.greenAccent
                  : trackingState.status == TrackingStatus.paused
                      ? Colors.orangeAccent
                      : Colors.white,
            ),
            label: const Text('Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'go_to_coords',
            onPressed: _openCoordinateSheet,
            backgroundColor: const Color(0xFF2C2C2C).withValues(alpha: 0.9),
            elevation: 4,
            icon: const Icon(Icons.gps_fixed, color: Colors.blueAccent, size: 20),
            label: const Text('Coordinates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      )),
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

class CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // North (Red) triangle
    final northPath = Path()
      ..moveTo(center.dx, 0)
      ..lineTo(center.dx + 6, center.dy)
      ..lineTo(center.dx - 6, center.dy)
      ..close();
    canvas.drawPath(northPath, Paint()..color = Colors.red.shade600);

    // South (White/Grey) triangle
    final southPath = Path()
      ..moveTo(center.dx, size.height)
      ..lineTo(center.dx + 6, center.dy)
      ..lineTo(center.dx - 6, center.dy)
      ..close();
    canvas.drawPath(southPath, Paint()..color = Colors.white70);

    // Center pivot
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
    canvas.drawCircle(center, 1, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
