import 'dart:math';
import 'package:latlong2/latlong.dart';

class PolygonValidationResult {
  final bool isValid;
  final String? errorMessage;
  final double areaHectares;
  final double areaAcres;
  final double areaSquareMeters;

  const PolygonValidationResult({
    required this.isValid,
    this.errorMessage,
    this.areaHectares = 0.0,
    this.areaAcres = 0.0,
    this.areaSquareMeters = 0.0,
  });
}

class PolygonValidator {
  static const double earthRadius = 6378137.0; // WGS84 radius in meters
  static const double epsilon = 1e-9;

  /// Calculate geodesic area in square meters on WGS84 ellipsoid
  static double calculateAreaSquareMeters(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final radLat1 = p1.latitude * pi / 180.0;
      final radLat2 = p2.latitude * pi / 180.0;
      final radLonDiff = (p2.longitude - p1.longitude) * pi / 180.0;
      area += radLonDiff * (2.0 + sin(radLat1) + sin(radLat2));
    }
    area = (area * earthRadius * earthRadius / 4.0).abs();
    return area;
  }

  static double calculateAreaHectares(List<LatLng> points) {
    return calculateAreaSquareMeters(points) / 10000.0;
  }

  static double calculateAreaAcres(List<LatLng> points) {
    return calculateAreaHectares(points) * 2.4710538;
  }

  /// Check if two line segments (p1-p2) and (p3-p4) intersect.
  /// If [allowEndpointTouch] is true, sharing a common endpoint does not count as intersection.
  static bool segmentsIntersect(
    LatLng p1,
    LatLng p2,
    LatLng p3,
    LatLng p4, {
    bool allowEndpointTouch = true,
  }) {
    // Check if segments share an endpoint
    final bool sharesEndpoint = _pointsEqual(p1, p3) ||
        _pointsEqual(p1, p4) ||
        _pointsEqual(p2, p3) ||
        _pointsEqual(p2, p4);

    if (sharesEndpoint && allowEndpointTouch) {
      // If they share an endpoint, check if they overlap collinear in the same or reverse direction
      // For adjacent segments in a polygon, reverse collinearity is a spike (self-overlap)
      if (_areCollinear(p1, p2, p3) && _areCollinear(p1, p2, p4)) {
        // Collinear sharing endpoint: check if the non-shared endpoints lie on each other's segment
        if (_pointsEqual(p2, p3)) {
          return _isPointOnSegment(p4, p1, p2) || _isPointOnSegment(p1, p3, p4);
        }
        if (_pointsEqual(p1, p4)) {
          return _isPointOnSegment(p3, p1, p2) || _isPointOnSegment(p2, p3, p4);
        }
      }
      return false;
    }

    final double d1 = _crossProduct(p3, p4, p1);
    final double d2 = _crossProduct(p3, p4, p2);
    final double d3 = _crossProduct(p1, p2, p3);
    final double d4 = _crossProduct(p1, p2, p4);

    // General intersection: straddles both lines
    if (((d1 > epsilon && d2 < -epsilon) || (d1 < -epsilon && d2 > epsilon)) &&
        ((d3 > epsilon && d4 < -epsilon) || (d3 < -epsilon && d4 > epsilon))) {
      return true;
    }

    // Collinear checks for point on segment
    if (d1.abs() <= epsilon && _isPointOnSegment(p1, p3, p4)) return true;
    if (d2.abs() <= epsilon && _isPointOnSegment(p2, p3, p4)) return true;
    if (d3.abs() <= epsilon && _isPointOnSegment(p3, p1, p2)) return true;
    if (d4.abs() <= epsilon && _isPointOnSegment(p4, p1, p2)) return true;

    return false;
  }

  static double _crossProduct(LatLng a, LatLng b, LatLng c) {
    // Vector AB x Vector AC in (lon, lat) plane
    final double abX = b.longitude - a.longitude;
    final double abY = b.latitude - a.latitude;
    final double acX = c.longitude - a.longitude;
    final double acY = c.latitude - a.latitude;
    return (abX * acY) - (abY * acX);
  }

  static bool _pointsEqual(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 1e-7 &&
        (a.longitude - b.longitude).abs() < 1e-7;
  }

  static bool _areCollinear(LatLng a, LatLng b, LatLng c) {
    return _crossProduct(a, b, c).abs() < 1e-10;
  }

  static bool _isPointOnSegment(LatLng p, LatLng a, LatLng b) {
    if (_crossProduct(a, b, p).abs() > 1e-7) return false;
    final minX = min(a.longitude, b.longitude) - 1e-7;
    final maxX = max(a.longitude, b.longitude) + 1e-7;
    final minY = min(a.latitude, b.latitude) - 1e-7;
    final maxY = max(a.latitude, b.latitude) + 1e-7;
    return p.longitude >= minX &&
        p.longitude <= maxX &&
        p.latitude >= minY &&
        p.latitude <= maxY;
  }

  /// Detects if the polygon formed by [points] has any self-intersecting boundary edges.
  static bool hasSelfIntersection(List<LatLng> points) {
    if (points.length < 4) return false;
    final int n = points.length;

    for (int i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];

      // Compare with all subsequent edges
      for (int j = i + 1; j < n; j++) {
        // Skip comparing the same edge
        if (i == j) continue;
        // Check if edges are adjacent
        final bool areAdjacent = (j == (i + 1) % n) || (i == (j + 1) % n);

        final p3 = points[j];
        final p4 = points[(j + 1) % n];

        if (segmentsIntersect(p1, p2, p3, p4, allowEndpointTouch: areAdjacent)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Full validation matching backend Shapely / GeoJSON specifications
  static PolygonValidationResult validatePolygon(List<LatLng> rawPoints) {
    if (rawPoints.isEmpty) {
      return const PolygonValidationResult(
        isValid: false,
        errorMessage: 'Please tap on the map to mark farm boundary points.',
      );
    }

    if (rawPoints.length < 3) {
      return PolygonValidationResult(
        isValid: false,
        errorMessage: 'A farm boundary needs at least 3 points. Currently you marked ${rawPoints.length}.',
      );
    }

    // Clean consecutive duplicates
    final cleanPoints = <LatLng>[];
    for (final pt in rawPoints) {
      if (cleanPoints.isEmpty || !_pointsEqual(cleanPoints.last, pt)) {
        cleanPoints.add(pt);
      }
    }
    if (cleanPoints.length > 2 && _pointsEqual(cleanPoints.first, cleanPoints.last)) {
      cleanPoints.removeLast();
    }

    if (cleanPoints.length < 3) {
      return const PolygonValidationResult(
        isValid: false,
        errorMessage: 'At least 3 distinct boundary points are required.',
      );
    }

    // Distinct points check
    final distinct = <String>{};
    for (final pt in cleanPoints) {
      distinct.add('${pt.latitude.toStringAsFixed(6)},${pt.longitude.toStringAsFixed(6)}');
    }
    if (distinct.length < 3) {
      return const PolygonValidationResult(
        isValid: false,
        errorMessage: 'Boundary points must not overlap in the same location.',
      );
    }

    // Self intersection check
    if (hasSelfIntersection(cleanPoints)) {
      return const PolygonValidationResult(
        isValid: false,
        errorMessage: 'Boundary lines cannot cross each other. Please tap "Undo Point" or "Reset Map" to redraw.',
      );
    }

    // Area check
    final areaSqM = calculateAreaSquareMeters(cleanPoints);
    final areaHa = areaSqM / 10000.0;
    final areaAcres = areaHa * 2.4710538;

    if (areaSqM < 1.0) {
      return const PolygonValidationResult(
        isValid: false,
        errorMessage: 'The marked area is too small. Please mark a wider boundary.',
      );
    }

    return PolygonValidationResult(
      isValid: true,
      areaSquareMeters: areaSqM,
      areaHectares: areaHa,
      areaAcres: areaAcres,
    );
  }

  /// Converts points to GeoJSON Polygon exterior ring [ [lon, lat], ... ]
  /// ensuring standard EPSG:4326 formatting and closure.
  static List<List<double>> toClosedGeoJsonRing(List<LatLng> points) {
    if (points.isEmpty) return [];

    // Deduplicate consecutive identical points
    final clean = <LatLng>[];
    for (final pt in points) {
      if (clean.isEmpty || !_pointsEqual(clean.last, pt)) {
        clean.add(pt);
      }
    }
    if (clean.length > 2 && _pointsEqual(clean.first, clean.last)) {
      clean.removeLast();
    }

    final ring = clean.map((p) => [
      double.parse(p.longitude.toStringAsFixed(7)),
      double.parse(p.latitude.toStringAsFixed(7)),
    ]).toList();

    // Ensure closed
    if (ring.isNotEmpty &&
        (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
      ring.add([ring.first[0], ring.first[1]]);
    }

    return ring;
  }
}
