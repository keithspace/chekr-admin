import 'package:checkoutapp/mobile/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mobile/email_verification_handler.dart';

// Supabase initialization
Future<void> initializeSupabase() async {
  await Supabase.initialize(
    url: 'https://wlbdvdbnecfwmxxftqrk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsYmR2ZGJuZWNmd214eGZ0cXJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg3NDcyNDcsImV4cCI6MjA1NDMyMzI0N30.JUKAxGQe8O57rb2kkZ6KUOEGi6RTiCQv34mAgUlHals',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeSupabase();
  await EmailVerificationHandler.handleEmailVerification();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chekr App',
      theme: ThemeData(
        // Apply Inter to all text themes
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
        // Primary text theme also using Inter
        primaryTextTheme: GoogleFonts.interTextTheme(
          Theme.of(context).primaryTextTheme,
        ),
        // App bar theme with Inter
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black
          ),
        ),
        // Button theme
        buttonTheme: const ButtonThemeData(
          textTheme: ButtonTextTheme.primary,
        ),
        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: GoogleFonts.inter(),
          hintStyle: GoogleFonts.inter(),
          errorStyle: GoogleFonts.inter(color: Colors.red),
        ),
        // Floating action button theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          foregroundColor: Colors.white,
        ),
        // Dialog theme
        dialogTheme: DialogTheme(
          titleTextStyle: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          contentTextStyle: GoogleFonts.inter(
            color: Colors.black, // This sets the dialog content text color to black
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
