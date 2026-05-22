import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/tile_loader_service.dart';

enum TileLoadStatus { idle, loading, ready, error }

class MapState {
  final Position? currentPosition;
  final bool isTracking;
  final TileLoadStatus tileStatus;
  final double tileLoadProgress;   // 0.0 to 1.0
  final String? tilePath;          // path to extracted MBTiles file
  final String? tileError;

  const MapState({
    this.currentPosition,
    this.isTracking = false,
    this.tileStatus = TileLoadStatus.idle,
    this.tileLoadProgress = 0.0,
    this.tilePath,
    this.tileError,
  });

  MapState copyWith({
    Position? currentPosition,
    bool? isTracking,
    TileLoadStatus? tileStatus,
    double? tileLoadProgress,
    String? tilePath,
    String? tileError,
  }) {
    return MapState(
      currentPosition: currentPosition ?? this.currentPosition,
      isTracking: isTracking ?? this.isTracking,
      tileStatus: tileStatus ?? this.tileStatus,
      tileLoadProgress: tileLoadProgress ?? this.tileLoadProgress,
      tilePath: tilePath ?? this.tilePath,
      tileError: tileError,
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
      state = state.copyWith(currentPosition: position);
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    state = state.copyWith(isTracking: false);
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(
  MapNotifier.new,
);
