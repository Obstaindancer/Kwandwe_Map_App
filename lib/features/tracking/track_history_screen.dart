import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../models/tracking_model.dart';
import '../../services/tracking_database_service.dart';
import '../map/map_provider.dart';
import 'gpx_exporter.dart';

class TrackHistoryScreen extends ConsumerStatefulWidget {
  const TrackHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TrackHistoryScreen> createState() => _TrackHistoryScreenState();
}

class _TrackHistoryScreenState extends ConsumerState<TrackHistoryScreen> {
  final TrackingDatabaseService _dbService = TrackingDatabaseService();
  List<TrackSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    _sessions = await _dbService.getAllTrackSessions();
    setState(() => _isLoading = false);
  }

  Future<void> _deleteSession(String id) async {
    await _dbService.deleteTrackSession(id);
    _loadSessions();
  }

  Future<void> _exportSession(TrackSession session) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing GPX export...')));
    final points = await _dbService.getPointsForTrack(session.id);
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No GPS data found for this track.')));
      return;
    }
    await GpxExporter.exportAndShare(session, points);
  }

  Future<void> _viewOnMap(TrackSession session) async {
    final points = await _dbService.getPointsForTrack(session.id);
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No GPS data found for this track.')));
      return;
    }
    
    final latLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final track = MapTrack(
      id: session.id,
      name: session.name,
      points: latLngs,
      color: Colors.purpleAccent, // Distinct color for historical tracks
    );
    
    ref.read(mapProvider.notifier).addImportedTrack(track);
    Navigator.of(context).popUntil((route) => route.isFirst); // Return to map
  }


  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    }
    return "${d.inMinutes}m ${d.inSeconds.remainder(60)}s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KwandweTheme.background,
      appBar: AppBar(
        title: const Text('Track History'),
        backgroundColor: KwandweTheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No tracks recorded yet.', style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return Card(
                      color: KwandweTheme.surface,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        iconColor: KwandweTheme.accent,
                        collapsedIconColor: Colors.white54,
                        title: Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: Text(
                          '${DateFormat('dd MMM yyyy, HH:mm').format(session.startTime)} • ${session.activityType.displayName}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStat('Distance', '${(session.distanceMeters / 1000).toStringAsFixed(2)} km'),
                                    _buildStat('Duration', _formatDuration(session.durationSeconds)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  alignment: WrapAlignment.spaceEvenly,
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _viewOnMap(session),
                                      icon: const Icon(Icons.map, color: Colors.blueAccent),
                                      label: const Text('View', style: TextStyle(color: Colors.blueAccent)),
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blueAccent)),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _exportSession(session),
                                      icon: const Icon(Icons.share, color: KwandweTheme.accent),
                                      label: const Text('Export', style: TextStyle(color: KwandweTheme.accent)),
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: KwandweTheme.accent)),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _deleteSession(session.id),
                                      icon: const Icon(Icons.delete, color: KwandweTheme.danger),
                                      label: const Text('Delete', style: TextStyle(color: KwandweTheme.danger)),
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: KwandweTheme.danger)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
