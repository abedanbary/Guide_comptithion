import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/AuthWrapper.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/map_screen_add.dart';
import 'screens/StudentHomeScreen.dart';
import 'screens/GuideHomeScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
