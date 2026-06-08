import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:uuid/uuid.dart';
import '../../core/tile_loader_service.dart';
import '../../models/pin_model.dart';
import '../../models/weather_model.dart';
import '../../core/weather_service.dart';

enum TileLoadStatus { idle, loading, ready, error }

class MapTrack {
  final String id;
  final String name;
  final List<LatLng> points;
  final Color color;

  MapTrack({
    required this.id,
    required this.name,
    required this.points,
    required this.color,
  });
}

class MapState {
  final Position? currentPosition;
  final bool isTracking;
  final TileLoadStatus tileStatus;
  final double tileLoadProgress;   // 0.0 to 1.0
  final String? tilePath;          // path to extracted MBTiles file
  final String? tileError;
  final MapPin? activeNavPin;
  final List<LatLng> driveTrack;
  final bool isRecordingDrive;
  final bool isMeasuring;
  final List<LatLng> measurePoints;
  final WeatherModel? weather;
  final List<MapTrack> importedTracks;

  const MapState({
    this.currentPosition,
    this.isTracking = false,
    this.tileStatus = TileLoadStatus.idle,
    this.tileLoadProgress = 0.0,
    this.tilePath,
    this.tileError,
    this.activeNavPin,
    this.driveTrack = const [],
    this.isRecordingDrive = false,
    this.isMeasuring = false,
    this.measurePoints = const [],
    this.weather,
    this.importedTracks = const [],
  });

  MapState copyWith({
    Position? currentPosition,
    bool? isTracking,
    TileLoadStatus? tileStatus,
    double? tileLoadProgress,
    String? tilePath,
    String? tileError,
    MapPin? activeNavPin,
    List<LatLng>? driveTrack,
    bool? isRecordingDrive,
    bool? isMeasuring,
    List<LatLng>? measurePoints,
    WeatherModel? weather,
    List<MapTrack>? importedTracks,
  }) {
    return MapState(
      currentPosition: currentPosition ?? this.currentPosition,
      isTracking: isTracking ?? this.isTracking,
      tileStatus: tileStatus ?? this.tileStatus,
      tileLoadProgress: tileLoadProgress ?? this.tileLoadProgress,
      tilePath: tilePath ?? this.tilePath,
      tileError: tileError,
      activeNavPin: activeNavPin ?? this.activeNavPin,
      driveTrack: driveTrack ?? this.driveTrack,
      isRecordingDrive: isRecordingDrive ?? this.isRecordingDrive,
      isMeasuring: isMeasuring ?? this.isMeasuring,
      measurePoints: measurePoints ?? this.measurePoints,
      weather: weather ?? this.weather,
      importedTracks: importedTracks ?? this.importedTracks,
    );
  }

  MapState clearNavPin() {
    return MapState(
      currentPosition: currentPosition,
      isTracking: isTracking,
      tileStatus: tileStatus,
      tileLoadProgress: tileLoadProgress,
      tilePath: tilePath,
      tileError: tileError,
      activeNavPin: null,
      driveTrack: driveTrack,
      isRecordingDrive: isRecordingDrive,
      isMeasuring: isMeasuring,
      measurePoints: measurePoints,
      weather: weather,
      importedTracks: importedTracks,
    );
  }
}

class MapNotifier extends Notifier<MapState> {
  StreamSubscription<Position>? _positionStream;

  @override
  MapState build() {
    // Start tile extraction immediately on provider creation, but wait until build is done
    Future.microtask(_extractTiles);
    return const MapState(tileStatus: TileLoadStatus.loading);
  }

  Future<void> _extractTiles() async {
    state = state.copyWith(
      tileStatus: TileLoadStatus.loading,
      tileLoadProgress: 0.0,
    );

    try {
      final path = await TileLoaderService.getOrExtractTilePath(
        onProgress: (progress) {
          state = state.copyWith(tileLoadProgress: progress);
        },
      );

      state = state.copyWith(
        tileStatus: TileLoadStatus.ready,
        tilePath: path,
        tileLoadProgress: 1.0,
      );
    } on TileLoadException catch (e) {
      state = state.copyWith(
        tileStatus: TileLoadStatus.error,
        tileError: e.message,
      );
    }
  }

  void startTracking() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    state = state.copyWith(isTracking: true);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((position) async {
      final newPos = LatLng(position.latitude, position.longitude);
      List<LatLng> newTrack = state.driveTrack;

      if (state.isRecordingDrive) {
        newTrack = List.from(state.driveTrack)..add(newPos);
      }

      state = state.copyWith(
        currentPosition: position,
        driveTrack: newTrack,
      );

      // Fetch weather if we haven't yet
      if (state.weather == null) {
        final weather = await WeatherService.fetchWeather(position.latitude, position.longitude);
        if (weather != null) {
          state = state.copyWith(weather: weather);
        }
      }
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    state = state.copyWith(isTracking: false);
  }

  void startNavigation(MapPin pin) {
    state = state.copyWith(activeNavPin: pin);
  }

  void stopNavigation() {
    state = state.clearNavPin();
  }

  void toggleDriveRecording() {
    state = state.copyWith(isRecordingDrive: !state.isRecordingDrive);
  }

  void clearDriveTrack() {
    state = state.copyWith(driveTrack: [], isRecordingDrive: false);
  }

  void toggleMeasuring() {
    state = state.copyWith(
      isMeasuring: !state.isMeasuring,
      measurePoints: [], // Clear points when toggling
    );
  }

  void addMeasurePoint(LatLng point) {
    if (!state.isMeasuring) return;
    state = state.copyWith(
      measurePoints: List.from(state.measurePoints)..add(point),
    );
  }

  void clearMeasurePoints() {
    state = state.copyWith(measurePoints: []);
  }

  void addImportedTrack(MapTrack track) {
    state = state.copyWith(
      importedTracks: List.from(state.importedTracks)..add(track),
    );
  }

  void removeImportedTrack(String id) {
    state = state.copyWith(
      importedTracks: state.importedTracks.where((t) => t.id != id).toList(),
    );
  }

  void clearImportedTracks() {
    state = state.copyWith(importedTracks: []);
  }

  Future<void> importGpxFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (!file.path.toLowerCase().endsWith('.gpx')) return;
      
      final gpxString = await file.readAsString();
      try {
        final gpx = GpxReader().fromString(gpxString);
        final List<LatLng> points = [];
        
        if (gpx.trks.isNotEmpty) {
          for (var seg in gpx.trks.first.trksegs) {
            for (var pt in seg.trkpts) {
              if (pt.lat != null && pt.lon != null) {
                points.add(LatLng(pt.lat!, pt.lon!));
              }
            }
          }
        } else if (gpx.wpts.isNotEmpty) {
          for (var pt in gpx.wpts) {
            if (pt.lat != null && pt.lon != null) {
              points.add(LatLng(pt.lat!, pt.lon!));
            }
          }
        }

        if (points.isNotEmpty) {
          final track = MapTrack(
            id: const Uuid().v4(),
            name: result.files.single.name,
            points: points,
            color: Colors.orangeAccent,
          );
          addImportedTrack(track);
        }
      } catch (e) {
        debugPrint('Error parsing GPX: $e');
      }
    }
  }

  Future<void> handleSharedGpxFile(String path) async {
    final file = File(path);
    if (!file.path.toLowerCase().endsWith('.gpx')) return;
    
    final gpxString = await file.readAsString();
    try {
      final gpx = GpxReader().fromString(gpxString);
      final List<LatLng> points = [];
      
      if (gpx.trks.isNotEmpty) {
        for (var seg in gpx.trks.first.trksegs) {
          for (var pt in seg.trkpts) {
            if (pt.lat != null && pt.lon != null) {
              points.add(LatLng(pt.lat!, pt.lon!));
            }
          }
        }
      } else if (gpx.wpts.isNotEmpty) {
        for (var pt in gpx.wpts) {
          if (pt.lat != null && pt.lon != null) {
            points.add(LatLng(pt.lat!, pt.lon!));
          }
        }
      }

      if (points.isNotEmpty) {
        final track = MapTrack(
          id: const Uuid().v4(),
          name: file.path.split('/').last,
          points: points,
          color: Colors.orangeAccent,
        );
        addImportedTrack(track);
      }
    } catch (e) {
      debugPrint('Error parsing shared GPX: $e');
    }
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(
  MapNotifier.new,
);
