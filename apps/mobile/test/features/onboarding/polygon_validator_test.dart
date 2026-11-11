import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:cropnet_mobile/core/utils/polygon_validator.dart';

void main() {
  group('PolygonValidator Tests', () {
    test('Valid convex rectangle passes validation and calculates area', () {
      // 0.001 degree square approx 110m x 110m ~ 1.2 hectares ~ 3 acres near equator/tropics
      final points = [
        const LatLng(18.1800, 74.5300),
        const LatLng(18.1800, 74.5310),
        const LatLng(18.1810, 74.5310),
        const LatLng(18.1810, 74.5300),
      ];

      final result = PolygonValidator.validatePolygon(points);
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.areaAcres, greaterThan(1.0));
      expect(result.areaAcres, lessThan(5.0));
    });

    test('Self-intersecting bowtie / hourglass polygon is detected and rejected', () {
      // Crossing lines: (0,0) -> (1,1) and (1,0) -> (0,1)
      final points = [
        const LatLng(18.1800, 74.5300),
        const LatLng(18.1810, 74.5310),
        const LatLng(18.1800, 74.5310),
        const LatLng(18.1810, 74.5300),
      ];

      final hasCross = PolygonValidator.hasSelfIntersection(points);
      expect(hasCross, isTrue);

      final result = PolygonValidator.validatePolygon(points);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Boundary lines cannot cross'));
    });

    test('Fewer than 3 points is rejected', () {
      final points = [
        const LatLng(18.1800, 74.5300),
        const LatLng(18.1810, 74.5310),
      ];
      final result = PolygonValidator.validatePolygon(points);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('at least 3 points'));
    });

    test('toClosedGeoJsonRing ensures [longitude, latitude] and closed loop', () {
      final points = [
        const LatLng(18.1800, 74.5300),
        const LatLng(18.1800, 74.5310),
        const LatLng(18.1810, 74.5310),
      ];

      final ring = PolygonValidator.toClosedGeoJsonRing(points);
      expect(ring.length, equals(4)); // 3 points + 1 closure
      expect(ring.first, equals(ring.last)); // Closed
      // Longitude first, then latitude
      expect(ring[0][0], equals(74.53));
      expect(ring[0][1], equals(18.18));
    });
  });
}
