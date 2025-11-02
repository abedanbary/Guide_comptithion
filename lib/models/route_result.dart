import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
    'points': points
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList(),
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
  };

  factory RouteResult.fromJson(Map<String, dynamic> json) => RouteResult(
    points: (json['points'] as List)
        .map((m) => LatLng(m['lat'], m['lng']))
        .toList(),
    distanceMeters: json['distanceMeters'],
    durationSeconds: json['durationSeconds'],
  );
}
