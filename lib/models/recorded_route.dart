import 'package:latlong2/latlong.dart';
import 'waypoint.dart';

/// Model representing a recorded route with all its data
class RecordedRoute {
  final String? id; // Firestore document ID or local ID
  final String roadName;
  final List<LatLng> routePolyline;
  final double totalDistance; // in meters
  final int totalTime; // in seconds
  final List<Waypoint> waypoints;
  final String? imageUrl;
  final String createdBy; // User ID who created the route
  final DateTime createdAt;
  final bool isSynced; // Whether route is synced to Firestore

  RecordedRoute({
    this.id,
    required this.roadName,
    List<LatLng>? routePolyline,
    List<LatLng>? recordedPoints, // Alternative name for compatibility
    required this.totalDistance,
    required this.totalTime,
    required this.waypoints,
    this.imageUrl,
    required this.createdBy,
    DateTime? createdAt,
    this.isSynced = false,
  })  : routePolyline = routePolyline ?? recordedPoints ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// Alias for routePolyline (for compatibility)
  List<LatLng> get recordedPoints => routePolyline;

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
      'id': id ?? createdAt.millisecondsSinceEpoch,
      'roadName': roadName,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'points': waypointsMap,
      'routePolyline': routePolylineMap,
      'recordedDistance': totalDistance,
      'recordedTime': totalTime,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isSynced': isSynced,
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
