import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/tracking_model.dart';
import '../../services/tracking_database_service.dart';
import 'track_details_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KwandweTheme.background,
      appBar: AppBar(
        title: const Text('Tracks'),
        backgroundColor: KwandweTheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No tracks recorded or imported yet.', style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final isImported = session.activityType == ActivityType.imported;
                    
                    return Card(
                      color: KwandweTheme.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => TrackDetailsScreen(session: session),
                            ),
                          );
                          // If track was deleted, result will be true
                          if (result == true) {
                            _loadSessions();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isImported ? Colors.orangeAccent.withOpacity(0.2) : KwandweTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isImported ? Icons.download : Icons.route,
                                color: isImported ? Colors.orangeAccent : KwandweTheme.accent,
                              ),
                            ),
                            title: Text(
                              session.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: Colors.white54),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(session.startTime),
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.straighten, size: 14, color: Colors.white54),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(session.distanceMeters / 1000).toStringAsFixed(1)} km',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
