import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:kwandwe_map/features/coordinates/coordinate_parser.dart';

void main() {
  group('CoordinateParser Tests', () {
    test('parses decimal degrees correctly', () {
      final result1 = CoordinateParser.parse('-33.1234, 26.5678');
      expect(result1, isNotNull);
      expect(result1!.latitude, closeTo(-33.1234, 0.0001));
      expect(result1.longitude, closeTo(26.5678, 0.0001));

      final result2 = CoordinateParser.parse('-33.1234 26.5678');
      expect(result2, isNotNull);
      expect(result2!.latitude, closeTo(-33.1234, 0.0001));
      expect(result2.longitude, closeTo(26.5678, 0.0001));
    });

    test('parses DMS format correctly', () {
      final result = CoordinateParser.parse('33°07\'24.2"S 26°34\'04.1"E');
      expect(result, isNotNull);
      // 33 + 7/60 + 24.2/3600 = 33.123388... S = -
      // 26 + 34/60 + 4.1/3600 = 26.567805... E = +
      expect(result!.latitude, closeTo(-33.123388, 0.0001));
      expect(result.longitude, closeTo(26.567805, 0.0001));
    });

    test('returns null for invalid strings', () {
      expect(CoordinateParser.parse('invalid string'), isNull);
      expect(CoordinateParser.parse('200.0, 50.0'), isNull); // Invalid latitude
    });
  });
}
