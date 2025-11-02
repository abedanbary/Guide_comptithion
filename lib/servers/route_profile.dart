enum RouteProfile {
  driving, // سيارة
  walking, // مشي
  cycling, // دراجة
}

extension RouteProfileX on RouteProfile {
  String get osrm {
    switch (this) {
      case RouteProfile.driving:
        return 'driving';
      case RouteProfile.walking:
        return 'foot'; // اسم OSRM للمشي
      case RouteProfile.cycling:
        return 'bike'; // اسم OSRM للدراجة
    }
  }
}
