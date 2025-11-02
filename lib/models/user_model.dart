class AppUser {
  final String uid; // Firebase UID
  final String email;
  final String username;
  final String role; // "guide" or "student"

  AppUser({
    required this.uid,
    required this.email,
    required this.username,
    required this.role,
  });

  // Convert to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'role': role,
      'createdAt': DateTime.now(),
    };
  }

  // Convert from Firebase
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'],
      email: json['email'],
      username: json['username'],
      role: json['role'],
    );
  }
}
