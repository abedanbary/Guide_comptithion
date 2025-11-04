import 'package:latlong2/latlong.dart';
import 'waypoint.dart';

/// Model representing a recorded route with all its data
class RecordedRoute {
  final String roadName;
  final List<LatLng> routePolyline;
  final double totalDistance; // in meters
  final int totalTime; // in seconds
  final List<Waypoint> waypoints;
  final String? imageUrl;
  final DateTime createdAt;

  RecordedRoute({
    required this.roadName,
    required this.routePolyline,
    required this.totalDistance,
    required this.totalTime,
    required this.waypoints,
    this.imageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert route to map for Firestore
  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> routePolylineMap = routePolyline
        .map((point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            })
        .toList();

    final List<Map<String, dynamic>> waypointsMap = waypoints
        .asMap()
        .entries
        .map((entry) => entry.value.toMap(id: entry.key + 1))
        .toList();

    return {
      'id': createdAt.millisecondsSinceEpoch,
      'roadName': roadName,
      'createdAt': createdAt,
      'points': waypointsMap,
      'routePolyline': routePolylineMap,
      'recordedDistance': totalDistance,
      'recordedTime': totalTime,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  /// Check if route is valid for saving
  bool isValid() {
    return roadName.isNotEmpty &&
        routePolyline.length >= 2 &&
        waypoints.isNotEmpty;
  }

  /// Get distance in kilometers
  double get distanceKm => totalDistance / 1000.0;

  /// Get time in minutes
  int get timeMinutes => totalTime ~/ 60;
}
