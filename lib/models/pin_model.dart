import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum PinType {
  rhinoRed,
  rhinoAmber,
  rhinoGray,
  camera,
  spoorSnare,
  waypoint,
  sighting,
  roadIssue,
  maintenance,
  staffTeam,
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
        return const Color(0xFFD32F2F); // Red
      case PinType.rhinoAmber:
        return const Color(0xFFFFA000); // Amber
      case PinType.rhinoGray:
        return const Color(0xFF9E9E9E); // Gray
      case PinType.camera:
        return const Color(0xFF673AB7); // Deep Purple
      case PinType.spoorSnare:
        return const Color(0xFF795548); // Brown
      case PinType.waypoint:
        return const Color(0xFF2196F3); // Blue
      case PinType.sighting:
        return const Color(0xFF009688); // Teal
      case PinType.roadIssue:
        return const Color(0xFFFF5722); // Deep Orange
      case PinType.maintenance:
        return const Color(0xFFFFEB3B); // Yellow
      case PinType.staffTeam:
        return const Color(0xFF8BC34A); // Light Green
    }
  }

  String get typeLabel {
    switch (type) {
      case PinType.rhinoRed: return 'Rhino (Red)';
      case PinType.rhinoAmber: return 'Rhino (Amber)';
      case PinType.rhinoGray: return 'Rhino (Gray)';
      case PinType.camera: return 'Camera';
      case PinType.spoorSnare: return 'Spoor / Snare Found';
      case PinType.waypoint: return 'Waypoint';
      case PinType.sighting: return 'Animal Sighting';
      case PinType.roadIssue: return 'Damaged/Blocked Road';
      case PinType.maintenance: return 'Maintenance';
      case PinType.staffTeam: return 'Field Staff Team';
    }
  }

  IconData get icon {
    switch (type) {
      case PinType.rhinoRed:
      case PinType.rhinoAmber:
      case PinType.rhinoGray:
        return Icons.pets;
      case PinType.camera:
        return Icons.camera_alt;
      case PinType.spoorSnare:
        return Icons.dangerous;
      case PinType.waypoint:
        return Icons.flag;
      case PinType.sighting:
        return Icons.visibility;
      case PinType.roadIssue:
        return Icons.remove_road;
      case PinType.maintenance:
        return Icons.build;
      case PinType.staffTeam:
        return Icons.groups;
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
