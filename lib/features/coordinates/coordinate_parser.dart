import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

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

    // Try DDM format (Degrees Decimal Minutes)
    final ddmResult = _tryDDM(cleaned);
    if (ddmResult != null) return ddmResult;

    // Try MGRS
    final mgrsResult = _tryMGRS(cleaned);
    if (mgrsResult != null) return mgrsResult;

    return null;
  }

  // ── MGRS (Military Grid Reference System) ─────────────────────────────────
  // Handles strings like: 35H LC 1234 5678 or 35HLC12345678
  static LatLng? _tryMGRS(String input) {
    try {
      final cleaned = input.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      if (cleaned.length >= 5 && RegExp(r'^\d{1,2}[C-X][A-Z]{2}\d+$').hasMatch(cleaned)) {
        final point = Mgrs.toPoint(cleaned);
        // point is [longitude, latitude]
        if (_validLatLng(point[1], point[0])) {
          return LatLng(point[1], point[0]);
        }
      }
    } catch (e) {
      // Return null on failure
    }
    return null;
  }

  // ── Decimal degrees ───────────────────────────────────────────────────────
  // Handles:  -33.1234, 26.5678  |  -33.1234 26.5678  |  33.1234°S, 26.5678°E  |  S33.1234 E026.5678
  static LatLng? _tryDecimal(String input) {
    // Pattern matches optional direction at start or end, and optional degree symbol
    final pattern = RegExp(
      r'^([NSns]?)\s*([+-]?\d{1,3}(?:\.\d+)?)[°\s]*([NSns]?)[,\s]+'
      r'([EWew]?)\s*([+-]?\d{1,3}(?:\.\d+)?)[°\s]*([EWew]?)$',
    );
    final match = pattern.firstMatch(input);
    if (match == null) return null;

    final latDir1 = match.group(1)?.toUpperCase() ?? '';
    final latVal = double.tryParse(match.group(2)!);
    final latDir2 = match.group(3)?.toUpperCase() ?? '';
    
    final lngDir1 = match.group(4)?.toUpperCase() ?? '';
    final lngVal = double.tryParse(match.group(5)!);
    final lngDir2 = match.group(6)?.toUpperCase() ?? '';

    if (latVal == null || lngVal == null) return null;

    double lat = latVal;
    if (latDir1 == 'S' || latDir2 == 'S') lat = -lat.abs();
    else if (latDir1 == 'N' || latDir2 == 'N') lat = lat.abs();

    double lng = lngVal;
    if (lngDir1 == 'W' || lngDir2 == 'W') lng = -lng.abs();
    else if (lngDir1 == 'E' || lngDir2 == 'E') lng = lng.abs();

    if (!_validLatLng(lat, lng)) return null;

    return LatLng(lat, lng);
  }

  // ── Degrees Decimal Minutes (DDM) ─────────────────────────────────────────
  // Handles:  S 33° 07.242' E 026° 34.041'  or  33° 07.242'S 026° 34.041'E
  static LatLng? _tryDDM(String input) {
    final pattern = RegExp(
      r"^([NSns]?)\s*(\d{1,3})[°\s]+(\d{1,2}(?:\.\d+)?)[′'\s]*([NSns]?)[,\s]+"
      r"([EWew]?)\s*(\d{1,3})[°\s]+(\d{1,2}(?:\.\d+)?)[′'\s]*([EWew]?)$",
    );
    final match = pattern.firstMatch(input);
    if (match == null) return null;

    final latDir1 = match.group(1)?.toUpperCase() ?? '';
    final latDeg = double.tryParse(match.group(2)!) ?? 0;
    final latMin = double.tryParse(match.group(3)!) ?? 0;
    final latDir2 = match.group(4)?.toUpperCase() ?? '';

    final lngDir1 = match.group(5)?.toUpperCase() ?? '';
    final lngDeg = double.tryParse(match.group(6)!) ?? 0;
    final lngMin = double.tryParse(match.group(7)!) ?? 0;
    final lngDir2 = match.group(8)?.toUpperCase() ?? '';

    final latDir = (latDir1.isNotEmpty ? latDir1 : latDir2).padRight(1, 'N');
    final lngDir = (lngDir1.isNotEmpty ? lngDir1 : lngDir2).padRight(1, 'E');

    final lat = _dmsToDecimal(latDeg, latMin, 0, latDir);
    final lng = _dmsToDecimal(lngDeg, lngMin, 0, lngDir);

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
    final latStr = '${lat.abs().toStringAsFixed(5)}°${lat >= 0 ? 'N' : 'S'}';
    final lngStr = '${lng.abs().toStringAsFixed(5)}°${lng >= 0 ? 'E' : 'W'}';
    
    String mgrsStr = '';
    try {
      mgrsStr = Mgrs.forward([lng, lat], 5);
      // Format 35HLC1234567890 to 35H LC 12345 67890
      if (mgrsStr.length == 15) {
        mgrsStr = '${mgrsStr.substring(0, 3)} ${mgrsStr.substring(3, 5)} ${mgrsStr.substring(5, 10)} ${mgrsStr.substring(10)}';
      }
    } catch (_) {}

    return '$latStr  $lngStr${mgrsStr.isNotEmpty ? '\nMGRS: $mgrsStr' : ''}';
  }
}
