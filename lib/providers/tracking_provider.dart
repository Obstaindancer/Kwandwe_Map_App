import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tracking_model.dart';
import '../services/tracking_database_service.dart';
import '../services/background_location_service.dart';

enum TrackingStatus { stopped, recording, paused }

class TrackingState {
  final TrackingStatus status;
  final TrackSession? activeSession;
  final double currentSpeed;
  final List<TrackPoint> currentPoints;

  TrackingState({
    this.status = TrackingStatus.stopped,
    this.activeSession,
    this.currentSpeed = 0.0,
    this.currentPoints = const [],
  });

  TrackingState copyWith({
    TrackingStatus? status,
    TrackSession? activeSession,
    double? currentSpeed,
    List<TrackPoint>? currentPoints,
  }) {
    return TrackingState(
      status: status ?? this.status,
      activeSession: activeSession ?? this.activeSession,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentPoints: currentPoints ?? this.currentPoints,
    );
  }
}

class TrackingNotifier extends Notifier<TrackingState> {
  @override
  TrackingState build() {
    Future.microtask(_init);
    return TrackingState();
  }

  final _dbService = TrackingDatabaseService();
  final _bgService = BackgroundLocationService();
  StreamSubscription? _serviceSubscription;
  Timer? _pointsRefreshTimer;

  Future<void> _init() async {
    await _bgService.initializeService();
    
    // Check if there was an active session before app closed
    final prefs = await SharedPreferences.getInstance();
    final trackId = prefs.getString('active_track_id');
    final isPaused = prefs.getBool('is_tracking_paused') ?? false;

    if (trackId != null) {
      final session = await _dbService.getTrackSession(trackId);
      if (session != null) {
        final points = await _dbService.getPointsForTrack(trackId);
        state = state.copyWith(
          status: isPaused ? TrackingStatus.paused : TrackingStatus.recording,
          activeSession: session,
          currentPoints: points,
        );
        _listenToService();
        _startPointsRefreshTimer();
      }
    }
  }

  void _listenToService() {
    _serviceSubscription?.cancel();
    _serviceSubscription = _bgService.serviceDataStream.listen((data) {
      if (data == null) return;
      if (state.activeSession != null) {
        state = state.copyWith(
          activeSession: state.activeSession!.copyWith(
            distanceMeters: (data['distance_meters'] as num?)?.toDouble(),
            durationSeconds: data['duration_seconds'] as int?,
          ),
          currentSpeed: (data['current_speed'] as num?)?.toDouble() ?? 0.0,
        );
      }
    });
  }
  
  void _startPointsRefreshTimer() {
    _pointsRefreshTimer?.cancel();
    _pointsRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
       if (state.activeSession != null) {
         final points = await _dbService.getPointsForTrack(state.activeSession!.id);
         state = state.copyWith(currentPoints: points);
       }
    });
  }

  Future<void> startNewSession(ActivityType type, String name) async {
    final session = TrackSession.create(name: name, activityType: type);
    await _dbService.insertTrackSession(session);
    
    state = state.copyWith(
      status: TrackingStatus.recording,
      activeSession: session,
      currentPoints: [],
      currentSpeed: 0.0,
    );

    await _bgService.startTracking(session.id);
    _listenToService();
    _startPointsRefreshTimer();
  }

  Future<void> pauseSession() async {
    await _bgService.pauseTracking();
    state = state.copyWith(status: TrackingStatus.paused);
  }

  Future<void> resumeSession() async {
    await _bgService.resumeTracking();
    state = state.copyWith(status: TrackingStatus.recording);
  }

  Future<void> stopSession() async {
    await _bgService.stopTracking();
    _serviceSubscription?.cancel();
    _pointsRefreshTimer?.cancel();
    
    if (state.activeSession != null) {
      // Final update to db
      final finalSession = state.activeSession!.copyWith(endTime: DateTime.now());
      await _dbService.updateTrackSession(finalSession);
    }
    
    state = TrackingState();
  }
}

final trackingProvider = NotifierProvider<TrackingNotifier, TrackingState>(
  TrackingNotifier.new,
);
