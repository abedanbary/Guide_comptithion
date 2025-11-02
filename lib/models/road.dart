import 'point.dart';
import 'route_result.dart';

class Road {
  final String roadName;
  final List<Point> points;
  final RouteResult? route; // المسار الواقعي من OSRM (اختياري)

  Road({required this.roadName, required this.points, this.route});

  Map<String, dynamic> toJson() => {
    'roadName': roadName,
    'points': points.map((p) => p.toJson()).toList(),
    'route': route?.toJson(),
  };

  factory Road.fromJson(Map<String, dynamic> json) => Road(
    roadName: json['roadName'],
    points: (json['points'] as List).map((p) => Point.fromJson(p)).toList(),
    route: json['route'] != null ? RouteResult.fromJson(json['route']) : null,
  );
}
