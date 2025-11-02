import 'point.dart';

class Road {
  final int id;
  final String roadName;
  final List<Point> points;

  Road({required this.id, required this.roadName, required this.points});

  factory Road.create({
    required String roadName,
    required List<Point> rawPoints,
  }) {
    // ✅ توليد معرف تلقائي للطريق + ترقيم النقاط تلقائيًا
    return Road(
      id: DateTime.now().millisecondsSinceEpoch,
      roadName: roadName,
      points: List.generate(
        rawPoints.length,
        (index) => Point(
          id: index + 1, // ترقيم النقطة داخل الطريق
          latitude: rawPoints[index].latitude,
          longitude: rawPoints[index].longitude,
          name: "Point ${index + 1}",
          quiz: rawPoints[index].quiz,
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roadName': roadName,
    'points': points.map((p) => p.toJson()).toList(),
  };

  factory Road.fromJson(Map<String, dynamic> json) {
    return Road(
      id: json['id'],
      roadName: json['roadName'],
      points: (json['points'] as List).map((p) => Point.fromJson(p)).toList(),
    );
  }
}
