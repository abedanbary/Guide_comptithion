import 'package:latlong2/latlong.dart';

/// Model representing a waypoint on a route with quiz data
class Waypoint {
  final String name;
  final LatLng location;
  final String question;
  final List<String> options;
  final int correctIndex;

  Waypoint({
    required this.name,
    required this.location,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  /// Convert waypoint to map for Firestore
  Map<String, dynamic> toMap({int? id}) {
    return {
      if (id != null) 'id': id,
      'name': name,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
    };
  }

  /// Create waypoint from map
  factory Waypoint.fromMap(Map<String, dynamic> map) {
    return Waypoint(
      name: map['name'] ?? '',
      location: LatLng(
        map['latitude'] ?? 0.0,
        map['longitude'] ?? 0.0,
      ),
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctIndex: map['correctIndex'] ?? 0,
    );
  }
}
