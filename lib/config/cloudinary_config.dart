// Cloudinary Configuration
// TODO: Replace with your actual Cloudinary credentials
// Get them from: https://console.cloudinary.com/

class CloudinaryConfig {
  // Your Cloudinary Cloud Name
  static const String cloudName = 'YOUR_CLOUD_NAME'; // مثل: 'dxxxxxxx'

  // Upload Preset for profile photos (must be set to "Unsigned" in Cloudinary dashboard)
  static const String profileUploadPreset = 'YOUR_PROFILE_PRESET'; // مثل: 'profile_photos'

  // Upload Preset for route images (must be set to "Unsigned" in Cloudinary dashboard)
  static const String routeUploadPreset = 'YOUR_ROUTE_PRESET'; // مثل: 'route_photos'

  // Validation helper
  static bool get isConfigured {
    return cloudName != 'YOUR_CLOUD_NAME' &&
           profileUploadPreset != 'YOUR_PROFILE_PRESET' &&
           routeUploadPreset != 'YOUR_ROUTE_PRESET';
  }

  static String get configurationError {
    if (!isConfigured) {
      return 'Please configure Cloudinary credentials in lib/config/cloudinary_config.dart';
    }
    return '';
  }
}
