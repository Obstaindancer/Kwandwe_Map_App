import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/tracking_model.dart';
import '../../services/tracking_database_service.dart';
import '../map/map_provider.dart';
import 'gpx_exporter.dart';

class TrackDetailsScreen extends ConsumerStatefulWidget {
  final TrackSession session;

  const TrackDetailsScreen({Key? key, required this.session}) : super(key: key);

  @override
  ConsumerState<TrackDetailsScreen> createState() => _TrackDetailsScreenState();
}

class _TrackDetailsScreenState extends ConsumerState<TrackDetailsScreen> {
  final TrackingDatabaseService _dbService = TrackingDatabaseService();
  List<TrackPoint> _points = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() => _isLoading = true);
    _points = await _dbService.getPointsForTrack(widget.session.id);
    setState(() => _isLoading = false);
  }

  Future<void> _deleteSession() async {
    await _dbService.deleteTrackSession(widget.session.id);
    if (mounted) {
      ref.read(mapProvider.notifier).removeImportedTrack(widget.session.id);
      Navigator.of(context).pop(true); // Return true to indicate deletion
    }
  }

  Future<void> _exportSession() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing GPX export...')));
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No GPS data found for this track.')));
      return;
    }
    await GpxExporter.exportAndShare(widget.session, _points);
  }

  bool get _isCurrentlyVisible {
    return ref.watch(mapProvider).importedTracks.any((t) => t.id == widget.session.id);
  }

  void _toggleVisibility() {
    final mapNotifier = ref.read(mapProvider.notifier);
    if (_isCurrentlyVisible) {
      mapNotifier.removeImportedTrack(widget.session.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track hidden from Main Map.')));
    } else {
      if (_points.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No GPS data found for this track.')));
        return;
      }
      
      final latLngs = _points.map((p) => LatLng(p.latitude, p.longitude)).toList();
      final track = MapTrack(
        id: widget.session.id,
        name: widget.session.name,
        points: latLngs,
        color: Colors.purpleAccent,
      );
      
      mapNotifier.addImportedTrack(track);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track shown on Main Map.')));
      Navigator.of(context).popUntil((route) => route.isFirst); // Return to map automatically when showing
    }
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    }
    return "${d.inMinutes}m ${d.inSeconds.remainder(60)}s";
  }

  LatLngBounds? _getBounds() {
    if (_points.isEmpty) return null;
    return LatLngBounds.fromPoints(
      _points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final latLngs = _points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final bounds = _getBounds();
    final isVisible = _isCurrentlyVisible;

    return Scaffold(
      backgroundColor: KwandweTheme.background,
      appBar: AppBar(
        title: const Text('Track Details'),
        backgroundColor: KwandweTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: KwandweTheme.accent),
            onPressed: _exportSession,
            tooltip: 'Export GPX',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: KwandweTheme.danger),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: KwandweTheme.surface,
                  title: const Text('Delete Track?', style: TextStyle(color: Colors.white)),
                  content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _deleteSession();
                      },
                      child: const Text('Delete', style: TextStyle(color: KwandweTheme.danger)),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Delete Track',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Mini Map Preview
                if (latLngs.isNotEmpty)
                  SizedBox(
                    height: 250,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: bounds!,
                          padding: const EdgeInsets.all(32.0),
                        ),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'za.co.kwandwe.kwandwe_map',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: latLngs,
                              strokeWidth: 4.0,
                              color: Colors.purpleAccent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                // Track Info Details
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      color: KwandweTheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: KwandweTheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                session.activityType.displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: KwandweTheme.accent,
                                ),
                              ),
                            ),
                            const Divider(color: Colors.white24, height: 32),
                            _buildInfoRow(Icons.calendar_today, 'Date', DateFormat('MMM d, yyyy').format(session.startTime)),
                            const SizedBox(height: 16),
                            _buildInfoRow(Icons.access_time, 'Start Time', DateFormat('h:mm a').format(session.startTime)),
                            if (session.endTime != null) ...[
                              const SizedBox(height: 16),
                              _buildInfoRow(Icons.timer_off, 'End Time', DateFormat('h:mm a').format(session.endTime!)),
                            ],
                            const SizedBox(height: 16),
                            _buildInfoRow(Icons.timer, 'Duration', _formatDuration(session.durationSeconds)),
                            const SizedBox(height: 16),
                            _buildInfoRow(Icons.straighten, 'Distance', '${(session.distanceMeters / 1000).toStringAsFixed(2)} km'),
                            const SizedBox(height: 16),
                            _buildInfoRow(Icons.place, 'Data Points', '${_points.length} GPS updates'),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _toggleVisibility,
                                icon: Icon(
                                  isVisible ? Icons.visibility_off : Icons.visibility, 
                                  color: Colors.white
                                ),
                                label: Text(
                                  isVisible ? 'Hide from Main Map' : 'Show on Main Map', 
                                  style: const TextStyle(fontSize: 16, color: Colors.white)
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isVisible ? KwandweTheme.danger : Colors.blueAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
