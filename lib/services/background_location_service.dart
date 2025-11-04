import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

/// Background service for GPS tracking when app is not in foreground
class BackgroundLocationService {
  static const String channelId = 'route_recording_channel';
  static const String channelName = 'Route Recording';
  static const int notificationId = 888;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize the background service
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Configure notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'GPS route recording notification',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Initialize notifications
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Configure service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: channelId,
        initialNotificationTitle: 'تسجيل الطريق',
        initialNotificationContent: 'جاري تتبع موقعك...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the background service
  static Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  /// Stop the background service
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Update notification with current stats
  static Future<void> updateNotification({
    required double distance,
    required int time,
    required int pointsCount,
    bool isPaused = false,
  }) async {
    final service = FlutterBackgroundService();
    service.invoke('updateNotification', {
      'distance': distance,
      'time': time,
      'points': pointsCount,
      'isPaused': isPaused,
    });
  }

  /// Service entry point
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Listen for commands from main isolate
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    service.on('updateNotification').listen((event) async {
      if (event == null) return;

      final distance = event['distance'] as double? ?? 0.0;
      final time = event['time'] as int? ?? 0;
      final points = event['points'] as int? ?? 0;
      final isPaused = event['isPaused'] as bool? ?? false;

      await _showNotification(
        distance: distance,
        time: time,
        pointsCount: points,
        isPaused: isPaused,
      );
    });

    // Initial notification
    await _showNotification(distance: 0, time: 0, pointsCount: 0);

    // Keep service alive with periodic updates
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!await service.isRunning()) {
        timer.cancel();
      }
    });
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// Show or update foreground notification
  static Future<void> _showNotification({
    required double distance,
    required int time,
    required int pointsCount,
    bool isPaused = false,
  }) async {
    final distanceKm = (distance / 1000).toStringAsFixed(2);
    final hours = time ~/ 3600;
    final minutes = (time % 3600) ~/ 60;
    final seconds = time % 60;

    String timeStr;
    if (hours > 0) {
      timeStr = '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      timeStr = '${minutes}m ${seconds}s';
    } else {
      timeStr = '${seconds}s';
    }

    final title = isPaused ? '⏸️ التسجيل متوقف مؤقتاً' : '🔴 جاري تسجيل الطريق';
    final content = '$distanceKm كم • $timeStr • $pointsCount نقطة';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'GPS route recording notification',
      importance: Importance.low,
      priority: Priority.low,
      showWhen: false,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notificationId,
      title,
      content,
      details,
    );
  }

  /// Cancel notification
  static Future<void> cancelNotification() async {
    await _notifications.cancel(notificationId);
  }
}
