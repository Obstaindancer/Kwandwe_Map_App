import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tracking_model.dart';
import 'tracking_database_service.dart';

class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initializeService() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        initialNotificationTitle: 'Kwandwe Map Tracking',
        initialNotificationContent: 'Recording your route...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> startTracking(String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_track_id', trackId);
    await prefs.setBool('is_tracking_paused', false);
    
    await _service.startService();
  }

  Future<void> pauseTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_tracking_paused', true);
  }

  Future<void> resumeTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_tracking_paused', false);
  }

  Future<void> stopTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_track_id');
    _service.invoke('stopService');
  }

  Stream<Map<String, dynamic>?> get serviceDataStream => _service.on('update');
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  final prefs = await SharedPreferences.getInstance();
  final dbService = TrackingDatabaseService();
  
  StreamSubscription<Position>? positionStream;
  Position? lastPosition;
  double distanceSinceStart = 0.0;
  
  // Try to load existing session data if resuming
  String? trackId = prefs.getString('active_track_id');
  if (trackId != null) {
     final session = await dbService.getTrackSession(trackId);
     if (session != null) {
       distanceSinceStart = session.distanceMeters;
     }
  }

  const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // Receive updates only if moving at least 5 meters
  );

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Kwandwe Map Tracking",
          content: "Recording route...",
        );
      }
    }

    // Always keep trackId fresh
    trackId = prefs.getString('active_track_id');
    final isPaused = prefs.getBool('is_tracking_paused') ?? false;

    if (trackId == null) {
      positionStream?.cancel();
      service.stopSelf();
      return;
    }

    if (isPaused) {
      positionStream?.pause();
      return;
    } else {
      if (positionStream?.isPaused ?? false) {
        positionStream?.resume();
      }
      
      // Send periodic updates to UI so the timer ticks even when stationary
      final session = await dbService.getTrackSession(trackId!);
      if (session != null) {
        service.invoke('update', {
          'distance_meters': distanceSinceStart,
          'duration_seconds': DateTime.now().difference(session.startTime).inSeconds,
          'current_speed': lastPosition?.speed ?? 0.0,
        });
      }
    }

    // Start location stream if not already started
    if (positionStream == null) {
      positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) async {
          // Calculate distance
          if (lastPosition != null) {
            double distance = Geolocator.distanceBetween(
              lastPosition!.latitude, lastPosition!.longitude,
              position.latitude, position.longitude
            );
            distanceSinceStart += distance;
          }
          lastPosition = position;

          // Save point
          final point = TrackPoint(
            trackId: trackId!,
            latitude: position.latitude,
            longitude: position.longitude,
            altitude: position.altitude,
            speed: position.speed,
            timestamp: position.timestamp,
          );
          await dbService.insertTrackPoint(point);

          // Update session stats
          final session = await dbService.getTrackSession(trackId!);
          if (session != null) {
            final updatedSession = session.copyWith(
              distanceMeters: distanceSinceStart,
              durationSeconds: position.timestamp.difference(session.startTime).inSeconds,
            );
            await dbService.updateTrackSession(updatedSession);

            // Send data back to UI
            service.invoke('update', {
              'distance_meters': distanceSinceStart,
              'duration_seconds': updatedSession.durationSeconds,
              'current_speed': position.speed,
              'latitude': position.latitude,
              'longitude': position.longitude,
            });
          }
        }
      );
    }
  });
}
