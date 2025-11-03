import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'GuideHomeScreen.dart';
import 'StudentHomeScreen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Professional color palette
  static const Color primaryBlue = Color(0xFF3D5A80);
  static const Color accentGold = Color(0xFFE9C46A);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryBlue),
                  SizedBox(height: 20),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 16,
                      color: primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // No user logged in - show login screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // User is logged in - check their role
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                ),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User data not found - logout and show login
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final role = userData['role'] ?? '';

            // Navigate based on role
            if (role == 'guide') {
              return const GuideHomeScreen();
            } else if (role == 'student') {
              return const StudentHomeScreen();
            } else {
              // Unknown role - logout
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }
          },
        );
      },
    );
  }
}
