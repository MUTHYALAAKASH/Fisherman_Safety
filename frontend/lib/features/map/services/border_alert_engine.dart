import 'dart:math';
import 'package:latlong2/latlong.dart';

class BorderAlertEngine {
  // Preconfigured International Boundary Line (IBL) polygon (e.g., India-Sri Lanka waters region)
  static final List<LatLng> boundaryPolygon = [
    const LatLng(9.00, 79.50),
    const LatLng(9.20, 79.70),
    const LatLng(9.30, 79.90),
    const LatLng(9.50, 80.10),
    const LatLng(9.70, 80.30),
    const LatLng(9.80, 80.10),
    const LatLng(9.50, 79.80),
    const LatLng(9.20, 79.40),
  ];

  /**
   * Ray-casting algorithm to determine if the point is inside the restricted boundary polygon.
   */
  static bool isInsidePolygon(LatLng point) {
    int i, j = boundaryPolygon.length - 1;
    bool oddNodes = false;
    double x = point.longitude;
    double y = point.latitude;

    for (i = 0; i < boundaryPolygon.length; i++) {
      double xi = boundaryPolygon[i].longitude;
      double yi = boundaryPolygon[i].latitude;
      double xj = boundaryPolygon[j].longitude;
      double yj = boundaryPolygon[j].latitude;

      if ((yi < y && yj >= y || yj < y && yi >= y) && (xi <= x || xj <= x)) {
        if (xi + (y - yi) / (yj - yi) * (xj - xi) < x) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }

    return oddNodes;
  }

  /**
   * Calculates the shortest distance in kilometers from the point to any edge of the boundary polygon.
   */
  static double getDistanceToBorder(LatLng point) {
    double minDistance = double.infinity;

    for (int i = 0; i < boundaryPolygon.length; i++) {
      LatLng p1 = boundaryPolygon[i];
      LatLng p2 = boundaryPolygon[(i + 1) % boundaryPolygon.length];
      
      double distance = _distanceToSegment(point, p1, p2);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  // Calculates distance from a point to a line segment
  static double _distanceToSegment(LatLng p, LatLng p1, LatLng p2) {
    double x = p.longitude;
    double y = p.latitude;
    double x1 = p1.longitude;
    double y1 = p1.latitude;
    double x2 = p2.longitude;
    double y2 = p2.latitude;

    double doubleArea = ((x2 - x1) * (y1 - y) - (x1 - x) * (y2 - y1)).abs();
    double segmentLength = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));

    if (segmentLength == 0) return _haversineDistance(p, p1);

    // Closest point calculation along the infinite line
    double u = ((x - x1) * (x2 - x1) + (y - y1) * (y2 - y1)) / pow(segmentLength, 2);

    if (u < 0.0) {
      return _haversineDistance(p, p1);
    } else if (u > 1.0) {
      return _haversineDistance(p, p2);
    }

    // Intersection lies on the segment
    LatLng intersection = LatLng(
      y1 + u * (y2 - y1),
      x1 + u * (x2 - x1),
    );

    return _haversineDistance(p, intersection);
  }

  // Haversine Distance helper
  static double _haversineDistance(LatLng p1, LatLng p2) {
    const double r = 6371.0; // Earth's radius in KM
    double dLat = _toRadians(p2.latitude - p1.latitude);
    double dLon = _toRadians(p2.longitude - p1.longitude);

    double a = sin(dLat / 2) * sin(dLat / 2) +
               cos(_toRadians(p1.latitude)) * cos(_toRadians(p2.latitude)) *
               sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180.0;
  }
}
