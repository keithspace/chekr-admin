import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'home.dart';
import 'landing.dart';
import 'biometric_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final storage = const FlutterSecureStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _wakeUpServers(); // Wake up servers first
    _navigateToNextScreen(); // Then proceed with normal flow
  }

  // Function to wake up both servers
  Future<void> _wakeUpServers() async {
    try {
      // Wake up PayPal server
      final paypalResponse = await http.get(
        Uri.parse('https://paypalserver-ycch.onrender.com'),
      ).timeout(const Duration(seconds: 10)).catchError((e) {
        print('PayPal server wakeup error: $e');
        return http.Response('Error', 500);
      });

      // Wake up MPesa server
      final mpesaResponse = await http.get(
        Uri.parse('https://server-iz6n.onrender.com/test'),
      ).timeout(const Duration(seconds: 10)).catchError((e) {
        print('MPesa server wakeup error: $e');
        return http.Response('Error', 500);
      });

      print('PayPal server status: ${paypalResponse.statusCode}');
      print('MPesa server status: ${mpesaResponse.statusCode}');
    } catch (e) {
      print('Error waking up servers: $e');
    }
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      // Check if user has enabled biometric login
      final bool useBiometric = await storage.read(key: 'use_biometric') == 'true';
      final bool isBiometricAvailable = await BiometricAuth.isBiometricAvailable();

      // If biometric is enabled and available, try to authenticate
      if (useBiometric && isBiometricAvailable) {
        final bool isAuthenticated = await BiometricAuth.authenticate();
        if (!isAuthenticated) {
          // Biometric auth failed or was cancelled, go to login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
          return;
        }
      }
      // Check both Firebase auth state and stored token
      final user = _auth.currentUser;
      final token = await storage.read(key: 'auth_token');

      // If we have neither, go to landing page
      if (user == null && token == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
        return;
      }

      // If we have a Firebase user but no token (shouldn't happen), get a new token
      if (user != null && token == null) {
        final newToken = await user.getIdToken();
        await storage.write(key: 'auth_token', value: newToken);
      }

      // If we have a token but no Firebase user (session expired), clear and go to landing
      if (user == null && token != null) {
        await storage.delete(key: 'auth_token');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
        return;
      }

      // If we get here, we have both user and token - proceed to home
      final userData = await _fetchUserData(user!.uid);
      final username = userData?['name'] ?? 'Guest';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(username: username)),
      );
    } catch (e) {
      // If any error occurs, clear everything and go to landing
      await storage.delete(key: 'auth_token');
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LandingPage()),
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData(String? userId) async {
    if (userId == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .get();
      return doc.data();
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/images/logo2.png', width: 200, height: 200),
      ),
    );
  }
}