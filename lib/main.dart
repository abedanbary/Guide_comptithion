import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/AuthWrapper.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/map_screen_add.dart';
import 'screens/StudentHomeScreen.dart';
import 'screens/GuideHomeScreen.dart';
import 'services/background_location_service.dart';
import 'services/local_storage_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize local storage for offline-first functionality
  await LocalStorageService.initialize();

  // Initialize background location service
  await BackgroundLocationService.initialize();

  // Initialize sync service for automatic cloud syncing
  await SyncService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guide Competition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(), // Auto-login wrapper
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/guideHome': (context) => const GuideHomeScreen(), // Guide Dashboard
        '/createRoad': (context) => const MapCreateScreen(), // Create Route
        '/studentHome': (context) => const StudentHomeScreen(), // Student
      },
    );
  }
}
