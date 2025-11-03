import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class RouteHelpers {
  /// Calculate total distance of a route in kilometers
  /// Takes a list of route polyline points
  static double calculateRouteDistance(List<dynamic> routePolyline) {
    if (routePolyline.isEmpty || routePolyline.length < 2) {
      return 0.0;
    }

    double totalDistance = 0.0;

    for (int i = 0; i < routePolyline.length - 1; i++) {
      final point1 = routePolyline[i];
      final point2 = routePolyline[i + 1];

      final lat1 = point1['latitude'] as double;
      final lon1 = point1['longitude'] as double;
      final lat2 = point2['latitude'] as double;
      final lon2 = point2['longitude'] as double;

      // Calculate distance between consecutive points in meters
      final distance = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
      totalDistance += distance;
    }

    // Convert meters to kilometers
    return totalDistance / 1000.0;
  }

  /// Calculate estimated time in minutes based on distance
  /// Assumes average walking speed of 5 km/h
  static int calculateEstimatedTime(double distanceKm) {
    const double averageWalkingSpeedKmh = 5.0;
    final hours = distanceKm / averageWalkingSpeedKmh;
    return (hours * 60).round(); // Convert to minutes
  }

  /// Format distance for display
  /// Returns string like "2.5 km" or "850 m"
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  /// Format time for display
  /// Returns string like "1h 30m" or "45m"
  static String formatTime(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      }
      return '${hours}h ${remainingMinutes}m';
    }
  }

  /// Calculate distance and time together
  /// Returns a map with distance (km) and time (minutes)
  static Map<String, dynamic> calculateRouteInfo(List<dynamic> routePolyline) {
    final distance = calculateRouteDistance(routePolyline);
    final time = calculateEstimatedTime(distance);

    return {
      'distanceKm': distance,
      'timeMinutes': time,
      'distanceFormatted': formatDistance(distance),
      'timeFormatted': formatTime(time),
    };
  }
}
