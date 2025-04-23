import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:image_picker_web/image_picker_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_project/panel.dart';
import 'package:web_project/reg.dart';

class AdminProfilePage extends StatefulWidget {
  @override
  _AdminProfilePageState createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = SupabaseClient(
    'https://wlbdvdbnecfwmxxftqrk.supabase.co',
    'your-supabase-key',
  );

  String? profilePicUrl;
  bool _isUploading = false;
  Map<String, dynamic>? adminData;
  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  Widget? _rightSideContent;
  bool get isAdmin => adminData?['task'] == 'Administrator';
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _resetInactivityTimer();
  }

  void _logoutDueToInactivity() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('adminId');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AdminLoginPage()),
            (Route<dynamic> route) => false,
      );
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 10), _logoutDueToInactivity);
  }


  Future<void> _loadAdminData() async {
    final firebase_auth.User? user = _auth.currentUser;
    if (user != null) {
      final DocumentSnapshot snapshot =
          await _firestore.collection('admins').doc(user.uid).get();
      if (snapshot.exists) {
        setState(() {
          adminData = snapshot.data() as Map<String, dynamic>;
          profilePicUrl = adminData?['profilePic'];
          _nameController.text = adminData?['name'] ?? '';
          _emailController.text = adminData?['email'] ?? '';
          _phoneController.text = adminData?['phone'] ?? '';
        });
      }
    }
  }

  Future<String> uploadProfilePictureToSupabase(Uint8List imageBytes) async {
    final fileName =
        'profile_pictures/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _supabase.storage.from('productimages').uploadBinary(
          fileName, imageBytes,
          fileOptions: const FileOptions(upsert: true));
      final publicUrl =
          _supabase.storage.from('productimages').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      throw Exception('Profile picture upload failed: $e');
    }
  }

  Future<void> _uploadProfilePicture() async {
    final Uint8List? imageBytes = await ImagePickerWeb.getImageAsBytes();
    if (imageBytes != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        final imageUrl = await uploadProfilePictureToSupabase(imageBytes);
        final firebase_auth.User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('admins').doc(user.uid).update({
            'profilePic': imageUrl,
          });
          setState(() {
            profilePicUrl = imageUrl;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading profile picture: $e')));
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _updateAdminDetails() async {
    final firebase_auth.User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('admins').doc(user.uid).update({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Details updated successfully!')));
      setState(() {
        _isEditing = false;
      });
    }
  }

  Future<void> _updateAdminTask(String adminId, String newTask) async {
    try {
      await _firestore.collection('admins').doc(adminId).update({
        'task': newTask,
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admin task updated successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating admin task: $e')));
    }
  }

  Future<void> _createAdmin(String email, String password, String name,
      String phone, String task) async {
    try {
      final firebase_auth.UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('admins').doc(userCredential.user?.uid).set({
        'email': email,
        'name': name,
        'phone': phone,
        'task': task,
        'profilePic': '',
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Admin created successfully!')));
      setState(() {
        _rightSideContent = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error creating admin: $e')));
    }
  }

  Future<void> _deleteAdmin(String uid) async {
    try {
      await _firestore.collection('admins').doc(uid).delete();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Admin deleted successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting admin: $e')));
    }
  }


  void _showUserInquiries() {
    setState(() {
      _rightSideContent = UserInquiriesPage(
        onInquirySelected: (inquiry) {
          setState(() {
            _rightSideContent = ConversationPage(
              inquiryId: inquiry['id'],
              userId: inquiry['userId'],
              userName: inquiry['userName'],
              description: inquiry['description'],
              isResponded: inquiry['isResponded'],
              adminName: adminData?['name'] ?? 'Admin',
              onBackPressed: () {
                setState(() {
                  _rightSideContent = UserInquiriesPage(
                    onInquirySelected: (inquiry) {
                      setState(() {
                        _rightSideContent = ConversationPage(
                          inquiryId: inquiry['id'],
                          userId: inquiry['userId'],
                          userName: inquiry['userName'],
                          description: inquiry['description'],
                          isResponded: inquiry['isResponded'],
                          adminName: adminData?['name'] ?? 'Admin',
                          onBackPressed: () {
                            setState(() {
                              _rightSideContent = UserInquiriesPage(
                                onInquirySelected: (inquiry) {},
                                onBackPressed: () {
                                  setState(() {
                                    _rightSideContent = null;
                                  });
                                },
                              );
                            });
                          },
                        );
                      });
                    },
                    onBackPressed: () {
                      setState(() {
                        _rightSideContent = null;
                      });
                    },
                  );
                });
              },
            );
          });
        },
        onBackPressed: () {
          setState(() {
            _rightSideContent = null;
          });
        },
      );
    });
  }

  Widget _buildPromoMessageEditor() {
    String message = '';
    final TextEditingController _messageController = TextEditingController();
    final firebase_auth.User? user = _auth.currentUser;

    FirebaseFirestore.instance
        .collection('promotions')
        .doc('currentPromotion')
        .get()
        .then((snapshot) {
      if (snapshot.exists) {
        _messageController.text = snapshot.data()?['message'] ?? '';
      }
    });

    return Container(
      padding: EdgeInsets.all(16),
      color: Color(0xFF1D1E33),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Update Promotional Message',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _rightSideContent = null;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            height: 150,
            child: TextField(
              controller: _messageController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: "Enter your promotional message...",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                message = value;
              },
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              if (message.isNotEmpty && user != null) {
                await FirebaseFirestore.instance
                    .collection('promotions')
                    .doc('currentPromotion')
                    .set({
                  'adminId': user.uid,
                  'message': message,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Promotional message updated successfully!')),
                );
                setState(() {
                  _rightSideContent = null;
                });
              }
            },
            child: Text('Save Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildWideInfoDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            Text(
              adminData?['name'] ?? 'No Name',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'User Role',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            Text(
              adminData?['task'] ?? 'No Role',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            Text(
              adminData?['email'] ?? 'No Email',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phone Number',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            Text(
              adminData?['phone'] ?? 'No Phone',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNarrowInfoDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            Text(
              adminData?['name'] ?? 'No Name',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  adminData?['email'] ?? 'No Email',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  adminData?['phone'] ?? 'No Phone',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Role',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            Text(
              adminData?['task'] ?? 'No Role',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 80), // Limit field height
          child: TextFormField(
            controller: _nameController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        SizedBox(height: 12), // Reduced spacing
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 80),
          child: TextFormField(
            controller: _emailController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 80),
          child: TextFormField(
            controller: _phoneController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Phone',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                });
              },
              child: Text('Cancel', style: TextStyle(color: Colors.white)),
            ), // **Added missing closing bracket here**
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: _updateAdminDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Save'),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildInfoDisplay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return _buildWideInfoDisplay();
        } else {
          return _buildNarrowInfoDisplay();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    const double cardHeight = 250;

    // If mobile and right side content is shown, only show that
    if (isMobile && _rightSideContent != null) {
      return Scaffold(
        body: _rightSideContent!,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0A0E21),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => AdminHomePage()),
            );
          },
        ),
      ),
      body: adminData == null
          ? Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _uploadProfilePicture,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundImage: profilePicUrl != null
                                          ? NetworkImage(profilePicUrl!)
                                          : null,
                                      child: _isUploading
                                          ? CircularProgressIndicator()
                                          : profilePicUrl == null
                                              ? Icon(Icons.person,
                                                  size: 50, color: Colors.white)
                                              : null,
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF1D1E33),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.add,
                                          size: 20, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                adminData?['name'] ?? 'No Name',
                                style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              SizedBox(height: 8),
                              Text(
                                adminData?['task'] ?? 'No Task',
                                style: GoogleFonts.poppins(
                                    fontSize: 18, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        // Personal Information Card with tap to exit edit
                        GestureDetector(
                          onTap: () {
                            if (_isEditing) {
                              setState(() {
                                _isEditing = false;
                              });
                            }
                          },
                          child: Card(
                            elevation: 4,
                            color: Color(0xFF1D1E33),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Personal Information',
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (!_isEditing) // Only show edit button when not editing
                                        ElevatedButton.icon(
                                          icon: Icon(Icons.edit, size: 16),
                                          label: Text('Edit'),
                                          onPressed: () {
                                            setState(() {
                                              _isEditing = true;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF0A0E21),
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Divider(
                                    color: Colors.white.withOpacity(0.2),
                                    thickness: 1,
                                  ),
                                  SizedBox(height: 16),
                                  if (_isEditing)
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return SizedBox(
                                          height: constraints.maxHeight * 0.7, // Use 70% of available height
                                          child: SingleChildScrollView(
                                            child: _buildEditForm(),
                                          ),
                                        );
                                      },
                                    )
                                  else
                                    _buildInfoDisplay(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        // Tasks Card
                        SizedBox(
                          height: cardHeight,
                          child: Card(
                            elevation: 4,
                            color: Color(0xFF1D1E33),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tasks',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Expanded(
                                    child: Center(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          ElevatedButton(
                                            onPressed: isAdmin ? () {
                                              setState(() {
                                                _rightSideContent = CreateAdminForm(
                                                  onCreateAdmin: _createAdmin,
                                                  onClose: () => setState(() => _rightSideContent = null),
                                                );
                                              });
                                              if (isMobile) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => Scaffold(
                                                      body: _rightSideContent!,
                                                    ),
                                                  ),
                                                );
                                              }
                                            } : null,
                                            child: Text('Create Admin'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isAdmin ? Color(0xFF0A0E21) : Colors.grey,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: isAdmin ? () {
                                              setState(() {
                                                _rightSideContent = AdminListPage(
                                                  onAdminSelected: _deleteAdmin,
                                                  onTaskUpdated: (String adminId, String newTask) {
                                                    _updateAdminTask(adminId, newTask);
                                                  },
                                                  onClose: () => setState(() => _rightSideContent = null),
                                                );
                                              });
                                              if (isMobile) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => Scaffold(
                                                      body: _rightSideContent!,
                                                    ),
                                                  ),
                                                );
                                              }
                                            } : null,
                                            child: Text('View Admins'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isAdmin ? Color(0xFF0A0E21) : Colors.grey,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              _showUserInquiries();
                                              if (isMobile) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => Scaffold(
                                                      body: _rightSideContent!,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Text('Respond to Inquiries'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(0xFF0A0E21),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _rightSideContent = _buildPromoMessageEditor();
                                              });
                                              if (isMobile) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => Scaffold(
                                                      body: _rightSideContent!,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Text('Update Promo Message'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(0xFF0A0E21),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
                if (_rightSideContent != null && !isMobile) ...[
                  VerticalDivider(color: Colors.white),
                  Expanded(
                    flex: 2,
                    child: _rightSideContent!,
                  ),
                ],
              ],
            ),
    );
  }
}

// [Rest of your existing classes (CreateAdminForm, AdminListPage, UserInquiriesPage, ConversationPage) remain exactly the same]

// Create Admin Form
class CreateAdminForm extends StatelessWidget {
  final Function(String, String, String, String, String) onCreateAdmin;
  final VoidCallback? onClose;

  CreateAdminForm({required this.onCreateAdmin, this.onClose});

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _taskController = TextEditingController();

  final _formKey = GlobalKey<FormState>(); // Form key for validation

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        color: Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Admin',
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed:
                              onClose ?? () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Name is required';
                        }
                        if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) {
                          return 'Name should only contain alphabetic characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Phone Field
                    TextFormField(
                      controller: _phoneController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Phone (e.g., 712345678)',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Phone is required';
                        }
                        if (!RegExp(r'^\d{9}$').hasMatch(value)) {
                          return 'Phone must be 9 digits (e.g., 712345678)';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Task Dropdown
                    DropdownButtonFormField<String>(
                      value: _taskController.text.isEmpty
                          ? null
                          : _taskController.text,
                      decoration: InputDecoration(
                        labelText: 'Task',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items:
                          ['Inventory Manager', 'Cashier', 'Exit Tech'].map((String task) {
                        return DropdownMenuItem<String>(
                          value: task,
                          child:
                              Text(task, style: TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        _taskController.text = value!;
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Task is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // Prefix phone with +254
                          final phone = '+254${_phoneController.text}';
                          onCreateAdmin(
                            _emailController.text,
                            _passwordController.text,
                            _nameController.text,
                            phone,
                            _taskController.text,
                          );
                        }
                      },
                      child: Text('Create Admin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0A0E21),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Admin List Page
class AdminListPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Function(String) onAdminSelected;
  final Function(String, String) onTaskUpdated;
  final VoidCallback? onClose;

  AdminListPage({
    required this.onAdminSelected,
    required this.onTaskUpdated,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        color: Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Admin List',
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: onClose ?? () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('admins').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                              child: Text('No admins found',
                                  style:
                                  GoogleFonts.poppins(color: Colors.white)));
                        }
                        final admins = snapshot.data!.docs;
                        return ListView.builder(
                          physics: AlwaysScrollableScrollPhysics(),
                          itemCount: admins.length,
                          itemBuilder: (context, index) {
                            final admin = admins[index];
                            return Card(
                              color: Color(0xFF0A0E21),
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text(admin['name'],
                                    style:
                                    GoogleFonts.poppins(color: Colors.white)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(admin['email'],
                                        style: GoogleFonts.poppins(
                                            color: Colors.white70)),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text('Task: ',
                                            style: GoogleFonts.poppins(
                                                color: Colors.white70)),
                                        DropdownButton<String>(
                                          value: admin['task'],
                                          dropdownColor: Color(0xFF1D1E33),
                                          style: GoogleFonts.poppins(
                                              color: Colors.white),
                                          items: [
                                            'Administrator',
                                            'Inventory Manager',
                                            'Cashier',
                                            'Exit Tech' // Added missing comma here
                                          ].map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              onTaskUpdated(admin.id, newValue);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          backgroundColor: Color(0xFF1D1E33),
                                          title: Text('Delete Admin',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white)),
                                          content: Text(
                                              'Are you sure you want to delete this admin?',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white)),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: Text('Cancel',
                                                  style: GoogleFonts.poppins(
                                                      color: Colors.white)),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                onAdminSelected(admin.id);
                                              },
                                              child: Text('Delete',
                                                  style: GoogleFonts.poppins(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// User Inquiries Page
class UserInquiriesPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Function(Map<String, dynamic>) onInquirySelected;
  final Function() onBackPressed; // Add this callback for back navigation

  UserInquiriesPage({
    required this.onInquirySelected,
    required this.onBackPressed, // Pass the callback
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Inquiries',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Color(0xFF0A0E21),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBackPressed, // Use the callback for back navigation
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          color: Color(0xFF1D1E33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'User Inquiries',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('feedback')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                            child: Text('No inquiries found',
                                style:
                                    GoogleFonts.poppins(color: Colors.white)));
                      }
                      final inquiries = snapshot.data!.docs;
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: inquiries.length,
                        itemBuilder: (context, index) {
                          final inquiry = inquiries[index];
                          final Map<String, dynamic>? inquiryData =
                              inquiry.data() as Map<String, dynamic>?;
                          final bool isResponded =
                              inquiryData?.containsKey('response') ?? false;

                          return FutureBuilder<DocumentSnapshot>(
                            future: _firestore
                                .collection('customers')
                                .doc(inquiry['userId'])
                                .get(),
                            builder: (context, userSnapshot) {
                              final userName = userSnapshot.hasData &&
                                      userSnapshot.data!.exists
                                  ? userSnapshot.data!['name']
                                  : 'Deleted account';

                              return ListTile(
                                leading: isResponded
                                    ? null
                                    : Icon(Icons.circle,
                                        color: Colors.red, size: 12),
                                title: Text(userName,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white)),
                                subtitle: Text(inquiry['title'],
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70)),
                                onTap: () {
                                  onInquirySelected({
                                    'id': inquiry.id,
                                    'userId': inquiry['userId'],
                                    'userName': userName,
                                    'description': inquiry['description'],
                                    'isResponded': isResponded,
                                  });
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConversationPage extends StatefulWidget {
  final String inquiryId;
  final String userId;
  final String userName;
  final String description;
  final bool isResponded;
  final String adminName;
  final Function() onBackPressed; // Add this callback for back navigation

  ConversationPage({
    required this.inquiryId,
    required this.userId,
    required this.userName,
    required this.description,
    required this.isResponded,
    required this.adminName,
    required this.onBackPressed, // Pass the callback
  });

  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _responseController = TextEditingController();

  Future<void> _submitResponse() async {
    if (_responseController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please enter a response')));
      return;
    }

    try {
      await _firestore.collection('feedback').doc(widget.inquiryId).update({
        'response': _responseController.text,
        'respondedBy': widget.adminName,
        'responseTime': DateTime.now(),
        'isNewResponse': true,
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Response submitted successfully!')));

      // Call the callback to navigate back to UserInquiriesPage
      widget.onBackPressed();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting response: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName,
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Color(0xFF0A0E21),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed:
              widget.onBackPressed, // Use the callback for back navigation
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.description,
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ),
                  if (widget.isResponded)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('feedback')
                          .doc(widget.inquiryId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return SizedBox
                              .shrink(); // Hide if no response exists
                        }

                        final response =
                            snapshot.data!['response'] ?? 'No response yet';
                        final respondedBy =
                            snapshot.data!['respondedBy'] ?? 'Admin';
                        final responseTime =
                            (snapshot.data!['responseTime'] as Timestamp)
                                .toDate();

                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue[800],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  respondedBy,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.white70),
                                ),
                                Text(
                                  response,
                                  style:
                                      GoogleFonts.poppins(color: Colors.white),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  DateFormat('jm')
                                      .format(responseTime), // Format time
                                  style: GoogleFonts.poppins(
                                      fontSize: 10, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _responseController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type your response...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitResponse,
                  child: Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0A0E21),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
