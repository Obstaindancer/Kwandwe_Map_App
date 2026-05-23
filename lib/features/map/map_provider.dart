import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/tile_loader_service.dart';
import '../../models/pin_model.dart';

enum TileLoadStatus { idle, loading, ready, error }

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
    ).listen((position) {
      final newPos = LatLng(position.latitude, position.longitude);
      List<LatLng> newTrack = state.driveTrack;

      if (state.isRecordingDrive) {
        newTrack = List.from(state.driveTrack)..add(newPos);
      }

      state = state.copyWith(
        currentPosition: position,
        driveTrack: newTrack,
      );
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
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(
  MapNotifier.new,
);
