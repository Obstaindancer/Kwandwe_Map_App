import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum PinType { rhinoAlert, manual, waypoint }

class MapPin {
  final String id;
  final LatLng position;
  final String label;
  final PinType type;
  final DateTime createdAt;
  final String? rawCoordinates; // original pasted string, if any

  const MapPin({
    required this.id,
    required this.position,
    required this.label,
    required this.type,
    required this.createdAt,
    this.rawCoordinates,
  });

  Color get colour {
    switch (type) {
      case PinType.rhinoAlert:
        return const Color(0xFFD32F2F); // red — urgent
      case PinType.manual:
        return const Color(0xFF5C4A1E); // brown — manual drop
      case PinType.waypoint:
        return const Color(0xFFD4A843); // amber — waypoint
    }
  }

  String get typeLabel {
    switch (type) {
      case PinType.rhinoAlert:
        return 'Rhino Alert';
      case PinType.manual:
        return 'Manual Pin';
      case PinType.waypoint:
        return 'Waypoint';
    }
  }

  MapPin copyWith({String? label, PinType? type}) {
    return MapPin(
      id: id,
      position: position,
      label: label ?? this.label,
      type: type ?? this.type,
      createdAt: createdAt,
      rawCoordinates: rawCoordinates,
    );
  }
}
