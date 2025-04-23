import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'forgot_password.dart';
import 'signup.dart';
import 'home.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final storage = const FlutterSecureStorage();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();
  }
  String generateSessionId() {
    var uuid = Uuid();
    return uuid.v4();
  }

  Future<void> _wakeUpServers() async {
    try {
      // Wake up both servers in parallel
      await Future.wait([
        // PayPal server
        http.get(Uri.parse('https://paypalserver-ycch.onrender.com'))
            .timeout(const Duration(seconds: 10))
            .catchError((e) => print('PayPal wakeup error: $e')),

        // MPesa server
        http.get(Uri.parse('https://server-iz6n.onrender.com/test'))
            .timeout(const Duration(seconds: 10))
            .catchError((e) => print('MPesa wakeup error: $e')),
      ]);

      print('Servers woken up successfully');
    } catch (e) {
      print('Error waking servers: $e');
    }
  }

  Future<void> _checkIfLoggedIn() async {
    if (await AuthHelper.isLoggedIn()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check if email is verified
        if (!user.emailVerified) {
          await FirebaseAuth.instance.signOut();
          return;
        }

        // Get username from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .get();

        final username = userDoc.data()?['name'] ?? 'Guest';

        // Navigate to home page and clear stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage(username: username)),
              (Route<dynamic> route) => false,
        );
      }
    }
  }

  void _initializeCart(String userId) async {
    final String sessionId = generateSessionId();
    final cartDoc = FirebaseFirestore.instance
        .collection('customers')
        .doc(userId)
        .collection('cart')
        .doc('activeCart');

    final docSnapshot = await cartDoc.get();

    if (!docSnapshot.exists) {
      await cartDoc.set({
        'userId': userId,
        'sessionId': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'products': [],
        'cartStatus': 'active',
      });
    } else {
      if (docSnapshot.data()?['sessionId'] == null) {
        await cartDoc.update({'sessionId': sessionId});
      }
    }
  }

  void _login() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _emailError = 'Email cannot be empty.';
        _isLoading = false;
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Password cannot be empty.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Check if email exists in customers collection
      var customerQuery = await FirebaseFirestore.instance
          .collection('customers')
          .where('email', isEqualTo: email)
          .get();

      if (customerQuery.docs.isEmpty) {
        setState(() {
          _emailError = 'No customer found with this email.';
          _isLoading = false;
        });
        return;
      }

      // Authenticate user
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      await userCredential.user!.reload();
      final currentUser = FirebaseAuth.instance.currentUser;

      // Check email verification
      if (!currentUser!.emailVerified) {
        setState(() { _isLoading = false; });

        bool resend = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Email Verification Required'),
            content: const Text('Please verify your email address before logging in.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Resend'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (resend) {
          await _resendVerificationEmail(currentUser);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email resent!')),
          );
        }
        return;
      }

      // Update Firestore and persist login
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(currentUser.uid)
          .update({'emailVerified': true});

      await AuthHelper.persistLogin(currentUser);

      // Wake up servers before proceeding
      await _wakeUpServers();

      // Get user data and navigate
      String uid = userCredential.user!.uid;
      String username = "Guest";
      var userDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        username = userDoc.data()?['name'] ?? "Guest";
      }

      // Record login and navigate to home
      await FirebaseFirestore.instance.collection('logins').add({
        'userId': uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage(username: username)),
              (Route<dynamic> route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _emailError = 'No user found for this email.';
        } else if (e.code == 'wrong-password') {
          _passwordError = 'Incorrect password. Try again.';
        } else {
          _emailError = 'Authentication failed. Please check your credentials.';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _resendVerificationEmail(User user) async {
    await user.sendEmailVerification();
    // Update Firestore to indicate we've resent the email
    await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .update({
      'verificationSentAt': FieldValue.serverTimestamp(),
    });
  }

// Add this new function to update session ID
  Future<void> _updateSessionId(String userId, String sessionId) async {
    final cartDoc = FirebaseFirestore.instance
        .collection('customers')
        .doc(userId)
        .collection('cart')
        .doc('activeCart');

    await cartDoc.set({
      'sessionId': sessionId,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/login1.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Please enter your email and a valid password',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Email Address',
                                errorText: _emailError,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Password',
                                errorText: _passwordError,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.all(16),
                              ),
                              onPressed: _isLoading ? null : _login,
                              child: const Text('Log in'),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SignUpPage()),
                                );
                              },
                              child: const Text(
                                "Don't have an account? Sign up here.",
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
                                );
                              },
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class AuthHelper {
  static final storage = const FlutterSecureStorage();
  static final _auth = FirebaseAuth.instance;

  static Future<bool> isLoggedIn() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Force token refresh to check validity
      final tokenResult = await user.getIdTokenResult(true);
      return tokenResult.token != null;
    } catch (e) {
      return false;
    }
  }

  static Future<void> persistLogin(User user) async {
    final token = await user.getIdToken();
    await storage.write(key: 'auth_token', value: token);
  }

  static Future<void> clearSession() async {
    await storage.delete(key: 'auth_token');
    await _auth.signOut();
  }
}