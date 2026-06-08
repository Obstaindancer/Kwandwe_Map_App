import 'package:uuid/uuid.dart';

enum ActivityType {
  patrol('Patrol'),
  walk('Nature Walk'),
  gameDrive('Game Drive'),
  imported('Imported GPX');

  final String displayName;
  const ActivityType(this.displayName);

  static ActivityType fromString(String type) {
    return ActivityType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => ActivityType.patrol,
    );
  }
}

class TrackSession {
  final String id;
  final String name;
  final ActivityType activityType;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceMeters;
  final int durationSeconds;

  TrackSession({
    required this.id,
    required this.name,
    required this.activityType,
    required this.startTime,
    this.endTime,
    this.distanceMeters = 0.0,
    this.durationSeconds = 0,
  });

  factory TrackSession.create({
    required String name,
    required ActivityType activityType,
  }) {
    return TrackSession(
      id: const Uuid().v4(),
      name: name,
      activityType: activityType,
      startTime: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'activity_type': activityType.name,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
    };
  }

  factory TrackSession.fromMap(Map<String, dynamic> map) {
    return TrackSession(
      id: map['id'],
      name: map['name'],
      activityType: ActivityType.fromString(map['activity_type']),
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time']),
      endTime: map['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time'])
          : null,
      distanceMeters: map['distance_meters']?.toDouble() ?? 0.0,
      durationSeconds: map['duration_seconds'] ?? 0,
    );
  }

  TrackSession copyWith({
    String? name,
    ActivityType? activityType,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceMeters,
    int? durationSeconds,
  }) {
    return TrackSession(
      id: id,
      name: name ?? this.name,
      activityType: activityType ?? this.activityType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

class TrackPoint {
  final int? id;
  final String trackId;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final DateTime timestamp;

  TrackPoint({
    this.id,
    required this.trackId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'track_id': trackId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory TrackPoint.fromMap(Map<String, dynamic> map) {
    return TrackPoint(
      id: map['id'],
      trackId: map['track_id'],
      latitude: map['latitude'].toDouble(),
      longitude: map['longitude'].toDouble(),
      altitude: map['altitude'].toDouble(),
      speed: map['speed'].toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}
