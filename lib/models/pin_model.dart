import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum PinType {
  rhinoRed,
  rhinoAmber,
  rhinoGray,
  sighting,
  maintenance,
  waypoint
}

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

  factory MapPin.fromJson(Map<String, dynamic> json) {
    return MapPin(
      id: json['id'] as String,
      position: LatLng(json['lat'] as double, json['lng'] as double),
      label: json['label'] as String,
      type: PinType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PinType.waypoint,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      rawCoordinates: json['rawCoordinates'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': position.latitude,
      'lng': position.longitude,
      'label': label,
      'type': type.toString(),
      'createdAt': createdAt.toIso8601String(),
      'rawCoordinates': rawCoordinates,
    };
  }

  Color get colour {
    switch (type) {
      case PinType.rhinoRed:
        return const Color(0xFFD32F2F); // Urgent
      case PinType.rhinoAmber:
        return const Color(0xFFFFA000); // Check needed
      case PinType.rhinoGray:
        return const Color(0xFF9E9E9E); // Normal
      case PinType.sighting:
        return const Color(0xFF8E24AA); // Purple for sightings
      case PinType.maintenance:
        return const Color(0xFF1976D2); // Blue for infrastructure
      case PinType.waypoint:
        return const Color(0xFFD4A843); // Standard gold
    }
  }

  String get typeLabel {
    switch (type) {
      case PinType.rhinoRed:
        return 'Rhino (Red)';
      case PinType.rhinoAmber:
        return 'Rhino (Amber)';
      case PinType.rhinoGray:
        return 'Rhino (Gray)';
      case PinType.sighting:
        return 'Sighting';
      case PinType.maintenance:
        return 'Maintenance';
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
