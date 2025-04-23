import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'dart:ui';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;
  String _loadingMessage = "";
  String _profilePicUrl =
      "https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/profile_pictures/default_profile.jpg";

  void _showOverlay(String message) {
    setState(() {
      _isLoading = true;
      _loadingMessage = message;
    });
  }

  void _hideOverlay() {
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _sendVerificationEmail(User user) async {
    await user.sendEmailVerification();
    await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .update({
      'emailVerified': false,
      'verificationSentAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _signUp() async {
    if (_formKey.currentState?.validate() ?? false) {
      _showOverlay("Signing up...");
      try {
        UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (userCredential.user != null) {
          final User user = userCredential.user!;
          final timestamp = FieldValue.serverTimestamp();

          await FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'password': _passwordController.text.trim(),
            'emailVerified': false,
            'emailVerifiedAt': null,
            'profilePic': _profilePicUrl,
            'timeRegistered': timestamp,
            'verificationSentAt': timestamp,
            'createdAt': timestamp,
            'lastLogin': null,
          });

          await _sendVerificationEmail(user);

          _showOverlay(
              "Registration successful!\nPlease check your email for verification.");
          await Future.delayed(const Duration(seconds: 3));

          await FirebaseAuth.instance.signOut();

          _nameController.clear();
          _emailController.clear();
          _phoneController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        _hideOverlay();
        String errorMessage = 'An error occurred during registration';

        if (e.code == 'email-already-in-use') {
          errorMessage = 'This email is already registered.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password should be at least 6 characters.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'The email address is invalid.';
        } else if (e.code == 'operation-not-allowed') {
          errorMessage = 'Email/password accounts are not enabled.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        _hideOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        _hideOverlay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/register.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Dark overlay
            Container(
              color: Colors.black.withOpacity(0.5),
            ),

            // Content
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: _inputDecoration('Name'),
                                    validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Name is required'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: _inputDecoration('Email'),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) =>
                                    value == null || !value.contains('@')
                                        ? 'Enter a valid email.'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _phoneController,
                                    decoration: _inputDecoration('Phone Number'),
                                    keyboardType: TextInputType.phone,
                                    validator: (value) =>
                                    value == null || value.length != 10
                                        ? 'Enter a valid 10-digit phone number.'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_passwordVisible,
                                    decoration: _passwordInputDecoration(
                                        'Password', _passwordVisible, () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
                                      });
                                    }),
                                    validator: (value) =>
                                    value == null || value.length < 6
                                        ? 'Password should be at least 6 characters.'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: !_confirmPasswordVisible,
                                    decoration: _passwordInputDecoration(
                                        'Confirm Password',
                                        _confirmPasswordVisible, () {
                                      setState(() {
                                        _confirmPasswordVisible =
                                        !_confirmPasswordVisible;
                                      });
                                    }),
                                    validator: (value) =>
                                    value != _passwordController.text
                                        ? 'Passwords do not match.'
                                        : null,
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(30)),
                                      ),
                                      onPressed: _signUp,
                                      child: const Text('Sign Up',
                                          style: TextStyle(fontSize: 15)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                              const LoginPage()));
                                    },
                                    child: const Text(
                                        'Already have an account? Log in',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Loading overlay
            if (_isLoading)
              AnimatedOpacity(
                opacity: _isLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _loadingMessage,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  InputDecoration _passwordInputDecoration(
      String hint, bool visible, VoidCallback onTap) {
    return _inputDecoration(hint).copyWith(
      suffixIcon: IconButton(
        icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
        onPressed: onTap,
      ),
    );
  }
}
