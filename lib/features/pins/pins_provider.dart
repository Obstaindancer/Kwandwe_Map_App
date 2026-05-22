import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../models/pin_model.dart';

const _uuid = Uuid();

class PinsNotifier extends Notifier<List<MapPin>> {
  @override
  List<MapPin> build() => [];

  void addPin({
    required LatLng position,
    required String label,
    required PinType type,
    String? rawCoordinates,
  }) {
    state = [
      ...state,
      MapPin(
        id: _uuid.v4(),
        position: position,
        label: label,
        type: type,
        createdAt: DateTime.now(),
        rawCoordinates: rawCoordinates,
      ),
    ];
  }

  void removePin(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}

final pinsProvider = NotifierProvider<PinsNotifier, List<MapPin>>(
  PinsNotifier.new,
);
