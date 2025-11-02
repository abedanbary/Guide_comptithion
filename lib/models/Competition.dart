import 'user_model.dart';

class Competition {
  final int id;
  final String adminId; // من نوع AppUser لكن نحفظ الـ uid فقط
  final int roadId;
  final String title;
  final DateTime createdAt;
  final List<AppUser> participants; // 🔹 الطلاب المشاركون
  final Map<String, int> scores; // 🔹 النقاط لكل مستخدم حسب الـ uid

  Competition({
    required this.id,
    required this.adminId,
    required this.roadId,
    required this.title,
    required this.createdAt,
    required this.participants,
    required this.scores,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'adminId': adminId,
    'roadId': roadId,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'participants': participants.map((u) => u.toJson()).toList(),
    'scores': scores,
  };

  static Competition fromJson(Map<String, dynamic> json) => Competition(
    id: json['id'],
    adminId: json['adminId'],
    roadId: json['roadId'],
    title: json['title'],
    createdAt: DateTime.parse(json['createdAt']),
    participants: (json['participants'] as List)
        .map((u) => AppUser.fromJson(u))
        .toList(),
    scores: Map<String, int>.from(json['scores']),
  );
}
