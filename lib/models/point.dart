import 'quiz.dart';

class Point {
  final double latitude;
  final double longitude;
  final String name;
  final Quiz quiz;

  Point({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.quiz,
  });

  // تحويل إلى JSON (للتخزين أو الإرسال)
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'name': name,
    'quiz': quiz.toJson(),
  };

  // إنشاء كائن من JSON
  factory Point.fromJson(Map<String, dynamic> json) => Point(
    latitude: json['latitude'],
    longitude: json['longitude'],
    name: json['name'],
    quiz: Quiz.fromJson(json['quiz']),
  );
}
