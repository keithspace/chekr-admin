import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase initialization
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_project/reg.dart'; // Supabase import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyCaaLggxQ6SjmOovCrUO8p0Pz-upBr6ZWc",
        authDomain: "chekr1.firebaseapp.com",
        projectId: "chekr1",
        storageBucket: "chekr1.firebasestorage.app",
        messagingSenderId: "692565424167",
        appId: "1:692565424167:web:4d1ac9462f138b33eb3602",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://wlbdvdbnecfwmxxftqrk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsYmR2ZGJuZWNmd214eGZ0cXJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg3NDcyNDcsImV4cCI6MjA1NDMyMzI0N30.JUKAxGQe8O57rb2kkZ6KUOEGi6RTiCQv34mAgUlHals',
  );

  runApp(const MyWebApp());
}

class MyWebApp extends StatelessWidget {
  const MyWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chekr Admin Panel',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0A0E21), // Dark blue-black
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1D1E33), // Darker blue
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1D1E33), // Darker blue
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      home: AdminApp(),
    );
  }
}
