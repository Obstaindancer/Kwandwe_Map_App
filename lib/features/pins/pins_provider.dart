import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/pin_model.dart';

const _prefsKey = 'kwandwe_map_pins';
const _uuid = Uuid();

class PinsNotifier extends Notifier<List<MapPin>> {
  @override
  List<MapPin> build() {
    Future.microtask(_loadPins);
    return [];
  }

  Future<void> _loadPins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? pinsJson = prefs.getString(_prefsKey);
      if (pinsJson != null) {
        final List<dynamic> decoded = jsonDecode(pinsJson);
        state = decoded.map((e) => MapPin.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading pins: $e');
    }
  }

  Future<void> _savePins(List<MapPin> pins) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(pins.map((p) => p.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('Error saving pins: $e');
    }
  }

  void addPin({
    required LatLng position,
    required String label,
    required PinType type,
    String? rawCoordinates,
  }) {
    final newState = [
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
    state = newState;
    _savePins(newState);
  }

  void removePin(String id) {
    final newState = state.where((p) => p.id != id).toList();
    state = newState;
    _savePins(newState);
  }

  void clearAll() {
    state = [];
    _savePins([]);
  }
}

final pinsProvider = NotifierProvider<PinsNotifier, List<MapPin>>(
  PinsNotifier.new,
);
