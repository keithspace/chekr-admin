import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_project/panel.dart';
import 'package:flutter/services.dart';

// Admin role constants
const List<String> allowedRoles = ['Administrator', 'Cashier', 'Inventory Manager'];
const maxLoginAttempts = 5;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      home: AdminLoginPage(),
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  @override
  _AdminLoginPageState createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _accountLocked = false;
  String _lockedAccountMessage = '';
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true; // For hiding/showing password

  Future<void> _checkAccountStatus(String email) async {
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (adminDoc.docs.isNotEmpty) {
        final data = adminDoc.docs.first.data();
        if (data['isLocked'] == true) {
          setState(() {
            _accountLocked = true;
            _lockedAccountMessage = 'Your account has been locked due to suspicious activity. '
                'Please check your email for password reset instructions.';
          });
        } else if (data['loginAttempts'] >= maxLoginAttempts) {
          await _lockAccount(adminDoc.docs.first.id, email);
          setState(() {
            _accountLocked = true;
            _lockedAccountMessage = 'Too many failed attempts. Account locked. '
                'Password reset link has been sent to your email.';
          });
        }
      }
    } catch (e) {
      print('Error checking account status: $e');
    }
  }

  Future<void> _lockAccount(String adminId, String email) async {
    try {
      // Update admin document
      await FirebaseFirestore.instance.collection('admins').doc(adminId).update({
        'isLocked': true,
        'lockedAt': FieldValue.serverTimestamp(),
      });

      // Send password reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      // Notify main admin (optional)
      await _notifyMainAdmin(email);
    } catch (e) {
      print('Error locking account: $e');
    }
  }

  Future<void> _notifyMainAdmin(String lockedEmail) async {
    try {
      final mainAdmin = await FirebaseFirestore.instance
          .collection('admins')
          .where('role', isEqualTo: 'Administrator')
          .limit(1)
          .get();

      if (mainAdmin.docs.isNotEmpty) {
        final adminEmail = mainAdmin.docs.first.data()['email'];
        // Implement your email sending logic here
        print('Notifying main admin $adminEmail about locked account $lockedEmail');
      }
    } catch (e) {
      print('Error notifying main admin: $e');
    }
  }

  Future<void> _loginAdmin() async {
    if (_accountLocked) {
      _showErrorDialog(_lockedAccountMessage);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check internet connection
      try {
        await FirebaseFirestore.instance.collection('dummy').doc('dummy').get().timeout(const Duration(seconds: 5));
      } catch (e) {
        throw Exception('No internet connection. Please check your network and try again.');
      }

      final email = _emailController.text.trim();
      await _checkAccountStatus(email);

      if (_accountLocked) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      ).timeout(const Duration(seconds: 15));

      // Verify admin role
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(userCredential.user?.uid)
          .get();

      if (!adminDoc.exists || !allowedRoles.contains(adminDoc.data()?['task'])) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Access denied. Your role does not have admin privileges.');
      }

      // Reset login attempts on successful login
      await FirebaseFirestore.instance.collection('admins').doc(userCredential.user?.uid).update({
        'loginAttempts': 0,
      });

      // Store admin ID
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('adminId', userCredential.user?.uid ?? '');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminHomePage(adminId: userCredential.user?.uid),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      // Handle failed login attempts
      if (e.code == 'wrong-password' || e.code == 'user-not-found') {
        final email = _emailController.text.trim();
        await _handleFailedAttempt(email);

        final adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (adminDoc.docs.isNotEmpty) {
          final attempts = adminDoc.docs.first.data()['loginAttempts'] ?? 0;
          final remainingAttempts = maxLoginAttempts - attempts;

          errorMessage = 'Invalid credentials. ${remainingAttempts > 0
              ? '$remainingAttempts attempts remaining'
              : 'Account locked. Check your email for reset instructions.'}';
        } else {
          errorMessage = 'Invalid credentials.';
        }
      } else {
        errorMessage = _getAuthErrorMessage(e.code);
      }

      _showErrorDialog(errorMessage);
    } on TimeoutException catch (_) {
      _showErrorDialog('Connection timed out. Please check your internet connection and try again.');
    } on SocketException catch (_) {
      _showErrorDialog('No internet connection. Please check your network and try again.');
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFailedAttempt(String email) async {
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (adminDoc.docs.isNotEmpty) {
        final docId = adminDoc.docs.first.id;
        final currentAttempts = adminDoc.docs.first.data()['loginAttempts'] ?? 0;
        final newAttempts = currentAttempts + 1;

        await FirebaseFirestore.instance.collection('admins').doc(docId).update({
          'loginAttempts': newAttempts,
          'lastFailedAttempt': FieldValue.serverTimestamp(),
        });

        if (newAttempts >= maxLoginAttempts) {
          await _lockAccount(docId, email);
          setState(() {
            _accountLocked = true;
            _lockedAccountMessage = 'Too many failed attempts. Account locked. '
                'Please check your email for password reset instructions.';
          });
        }
      }
    } catch (e) {
      print('Error handling failed attempt: $e');
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No admin found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Login Error',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      backgroundColor: Color(0xFF121212), // Darker background
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                ],
              ),
            ),
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: isSmallScreen ? size.width * 0.9 : 450,
                margin: EdgeInsets.all(24),
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo with animation
                      Hero(
                        tag: 'app-logo',
                        child: CachedNetworkImage(
                          imageUrl: 'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/logo/logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            width: 120,
                            height: 120,
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 60,
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Title
                      Text(
                        'Admin Portal',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),

                      SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Sign in to continue',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),

                      if (_accountLocked) ...[
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _lockedAccountMessage,
                                  style: GoogleFonts.poppins(
                                    color: Colors.red[200],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 32),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.grey[400],
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.grey[500],
                          ),
                          filled: true,
                          fillColor: Colors.grey[900]!.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.grey[800]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.blueAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (_accountLocked) {
                            _checkAccountStatus(value.trim());
                          }
                        },
                      ),

                      SizedBox(height: 20),

                      // Password Field
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.grey[400],
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Colors.grey[500],
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey[500],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.grey[900]!.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.grey[800]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.blueAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,  // Use the state variable here
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _accountLocked
                              ? null
                              : () {
                            if (_formKey.currentState!.validate()) {
                              _loginAdmin();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accountLocked
                                ? Colors.grey[700]
                                : Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 3,
                            shadowColor: Colors.blueAccent.withOpacity(0.3),
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                              : Text(
                            'LOG IN',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Forgot Password
                      TextButton(
                        onPressed: () {
                          if (_emailController.text.isNotEmpty) {
                            FirebaseAuth.instance.sendPasswordResetEmail(
                                email: _emailController.text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Password reset link sent to your email',
                                  style: GoogleFonts.poppins(),
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            _showErrorDialog('Please enter your email first');
                          }
                        },
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.poppins(
                            color: Colors.blueAccent[200],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blueAccent),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Authenticating...',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDot({required double delay}) {
    return Builder(
      builder: (context) {
        return FutureBuilder(
          future: Future.delayed(Duration(milliseconds: (delay * 1000).round())),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(width: 10, height: 10);
            }
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}