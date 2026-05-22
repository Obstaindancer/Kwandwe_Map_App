import 'package:latlong2/latlong.dart';

/// Parses GPS coordinate strings from rhino collar alerts and manual entry.
/// Supports:
///   - Decimal degrees:  -33.1234, 26.5678
///   - DMS:              33°07'24.2"S 26°34'04.1"E
///   - Signed decimal:   -33.1234 26.5678  (space separated)
class CoordinateParser {
  /// Returns a LatLng if parsing succeeds, null if the input is unrecognisable.
  static LatLng? parse(String input) {
    final cleaned = input.trim();

    // Try decimal degrees first (most common from collar systems)
    final decimalResult = _tryDecimal(cleaned);
    if (decimalResult != null) return decimalResult;

    // Try DMS format
    final dmsResult = _tryDMS(cleaned);
    if (dmsResult != null) return dmsResult;

    return null;
  }

  // ── Decimal degrees ───────────────────────────────────────────────────────
  // Handles:  -33.1234, 26.5678  or  -33.1234 26.5678
  static LatLng? _tryDecimal(String input) {
    final pattern = RegExp(
      r'^([+-]?\d{1,3}(?:\.\d+)?)[,\s]+([+-]?\d{1,3}(?:\.\d+)?)$',
    );
    final match = pattern.firstMatch(input);
    if (match == null) return null;

    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    if (!_validLatLng(lat, lng)) return null;

    return LatLng(lat, lng);
  }

  // ── Degrees Minutes Seconds ───────────────────────────────────────────────
  // Handles:  33°07'24.2"S 26°34'04.1"E
  static LatLng? _tryDMS(String input) {
    final pattern = RegExp(
      r'''(\d{1,3})[°\s](\d{1,2})['\s](\d{1,2}(?:\.\d+)?)["″\s]?([NSns])\s+'''
      r'''(\d{1,3})[°\s](\d{1,2})['\s](\d{1,2}(?:\.\d+)?)["″\s]?([EWew])''',
    );
    final match = pattern.firstMatch(input);
    if (match == null) return null;

    final lat = _dmsToDecimal(
      double.parse(match.group(1)!),
      double.parse(match.group(2)!),
      double.parse(match.group(3)!),
      match.group(4)!.toUpperCase(),
    );
    final lng = _dmsToDecimal(
      double.parse(match.group(5)!),
      double.parse(match.group(6)!),
      double.parse(match.group(7)!),
      match.group(8)!.toUpperCase(),
    );

    if (!_validLatLng(lat, lng)) return null;
    return LatLng(lat, lng);
  }

  static double _dmsToDecimal(
      double degrees, double minutes, double seconds, String direction) {
    double decimal = degrees + (minutes / 60) + (seconds / 3600);
    if (direction == 'S' || direction == 'W') decimal = -decimal;
    return decimal;
  }

  static bool _validLatLng(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Formats a LatLng back to a clean readable string for display.
  static String format(double lat, double lng) {
    final latStr =
        '${lat.abs().toStringAsFixed(6)}°${lat >= 0 ? 'N' : 'S'}';
    final lngStr =
        '${lng.abs().toStringAsFixed(6)}°${lng >= 0 ? 'E' : 'W'}';
    return '$latStr  $lngStr';
  }
}
