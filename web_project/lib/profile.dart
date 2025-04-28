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
  bool isMobile = false;

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
    _inactivityTimer =
        Timer(const Duration(minutes: 10), _logoutDueToInactivity);
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

  /*void _showUserInquiries() {
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
  }*/

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

  /*Widget _buildEditForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Phone',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[800],
            ),
          ),
          SizedBox(height: 20),
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
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _updateAdminDetails();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }*/

  Widget _buildTaskButton(
    BuildContext context,
    String text,
    bool enabled,
    VoidCallback onPressed,
    bool isMobile, // Add this parameter
  ) {
    return SizedBox(
      width: isMobile ? double.infinity : null,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? Color(0xFF0A0E21) : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: Size(isMobile ? double.infinity : 150, 50),
        ),
      ),
    );
  }

  /*Widget _buildInfoDisplay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return _buildWideInfoDisplay();
        } else {
          return _buildNarrowInfoDisplay();
        }
      },
    );
  }*/

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // If mobile and right side content is shown, only show that
    if (isMobile && _rightSideContent != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Admin Panel', style: GoogleFonts.poppins()),
          backgroundColor: colorScheme.surface,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => setState(() => _rightSideContent = null),
          ),
        ),
        body: _rightSideContent!,
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: adminData == null
          ? Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side Panel
                Expanded(
                  flex: isMobile ? 1 : 2,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Profile Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundColor:
                                          colorScheme.primary.withOpacity(0.1),
                                      backgroundImage: profilePicUrl != null
                                          ? NetworkImage(profilePicUrl!)
                                          : null,
                                      child: _isUploading
                                          ? CircularProgressIndicator()
                                          : profilePicUrl == null
                                              ? Icon(Icons.person,
                                                  size: 50,
                                                  color: colorScheme.onSurface)
                                              : null,
                                    ),
                                    FloatingActionButton.small(
                                      onPressed: _uploadProfilePicture,
                                      backgroundColor: colorScheme.primary,
                                      child: Icon(Icons.camera_alt, size: 20),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  adminData?['name'] ?? 'No Name',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Chip(
                                  label: Text(
                                    adminData?['task'] ?? 'No Role',
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                  backgroundColor:
                                      colorScheme.primary.withOpacity(0.2),
                                ),
                                SizedBox(height: 16),
                                Divider(),
                                SizedBox(height: 16),
                                _buildInfoSection(),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 16),

                        // Admin Tools Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Tools',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 16),
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  crossAxisCount: isMobile ? 1 : 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 3,
                                  children: [
                                    _buildToolButton(
                                      icon: Icons.person_add,
                                      label: 'Create Admin',
                                      enabled: isAdmin,
                                      onTap: () => _showAdminCreation(isMobile),
                                    ),
                                    _buildToolButton(
                                      icon: Icons.people,
                                      label: 'View Admins',
                                      enabled: isAdmin,
                                      onTap: () => _showAdminList(isMobile),
                                    ),
                                    _buildToolButton(
                                      icon: Icons.chat,
                                      label: 'User Inquiries',
                                      enabled: true,
                                      onTap: () => _showUserInquiries(isMobile),
                                    ),
                                    _buildToolButton(
                                      icon: Icons.campaign,
                                      label: 'Message',
                                      enabled: true,
                                      onTap: () => _showPromoEditor(isMobile),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Side Content
                if (_rightSideContent != null && !isMobile) ...[
                  VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    flex: 3,
                    child: Scaffold(
                      appBar: AppBar(
                        title:
                            Text('Admin Panel', style: GoogleFonts.poppins()),
                        backgroundColor: colorScheme.surface,
                        leading: IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _rightSideContent = null),
                        ),
                      ),
                      body: _rightSideContent!,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildInfoSection() {
    return _isEditing ? _buildEditForm() : _buildInfoDisplay();
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: enabled ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.grey.shade300,
        foregroundColor: enabled
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Colors.grey.shade600,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _isEditing = false),
              child: Text('Cancel'),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: _updateAdminDetails,
              child: Text('Save Changes'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoDisplay() {
    final isWide = MediaQuery.of(context).size.width > 600;
    final textStyle = GoogleFonts.poppins(fontSize: 14);
    final boldTextStyle = textStyle.copyWith(fontWeight: FontWeight.w600);

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.person, size: 24),
          title: Text('Name', style: textStyle),
          subtitle: Text(adminData?['name'] ?? 'No Name', style: boldTextStyle),
          trailing: IconButton(
            icon: Icon(Icons.edit, size: 20),
            onPressed: () => setState(() => _isEditing = true),
          ),
        ),
        Divider(height: 1),
        ListTile(
          leading: Icon(Icons.email, size: 24),
          title: Text('Email', style: textStyle),
          subtitle:
              Text(adminData?['email'] ?? 'No Email', style: boldTextStyle),
        ),
        Divider(height: 1),
        ListTile(
          leading: Icon(Icons.phone, size: 24),
          title: Text('Phone', style: textStyle),
          subtitle:
              Text(adminData?['phone'] ?? 'No Phone', style: boldTextStyle),
        ),
        Divider(height: 1),
        ListTile(
          leading: Icon(Icons.work, size: 24),
          title: Text('Role', style: textStyle),
          subtitle: Text(adminData?['task'] ?? 'No Role', style: boldTextStyle),
        ),
      ],
    );
  }

  void _showAdminCreation(bool isMobile) {
    final content = CreateAdminForm(
      onCreateAdmin: (email, password, name, phone, task) {
        _createAdmin(email, password, name, phone, task);
        setState(() => _rightSideContent = null);
      },
      onClose: () => setState(() => _rightSideContent = null),
    );

    if (isMobile) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: Text('Create Admin')),
              body: content,
            ),
          ));
    } else {
      setState(() => _rightSideContent = content);
    }
  }

  void _showAdminList(bool isMobile) {
    final content = AdminListPage(
      onAdminSelected: _deleteAdmin,
      onTaskUpdated: _updateAdminTask,
      onClose: () => setState(() => _rightSideContent = null),
    );

    if (isMobile) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: Text('Admin List')),
              body: content,
            ),
          ));
    } else {
      setState(() => _rightSideContent = content);
    }
  }

  void _showUserInquiries(bool isMobile) {
    final content = UserInquiriesPage(
      onInquirySelected: (inquiry) {
        setState(() {
          _rightSideContent = ConversationPage(
            inquiryId: inquiry['id'],
            userId: inquiry['userId'],
            userName: inquiry['userName'],
            description: inquiry['description'],
            isResponded: inquiry['isResponded'],
            adminName: adminData?['name'] ?? 'Admin',
            onBackPressed: () => setState(() => _rightSideContent = null),
          );
        });
      },
      onBackPressed: () => setState(() => _rightSideContent = null),
    );

    if (isMobile) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(body: content),
          ));
    } else {
      setState(() => _rightSideContent = content);
    }
  }

  void _showPromoEditor(bool isMobile) {
    final content = _buildPromoMessageEditor();

    if (isMobile) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: Text('Update Promo')),
              body: content,
            ),
          ));
    } else {
      setState(() => _rightSideContent = content);
    }
  }
}

// [Rest of your existing classes (CreateAdminForm, AdminListPage, UserInquiriesPage, ConversationPage) remain exactly the same]

// Create Admin Form
class CreateAdminForm extends StatefulWidget {
  final Function(String, String, String, String, String) onCreateAdmin;
  final VoidCallback onClose;

  const CreateAdminForm({
    required this.onCreateAdmin,
    required this.onClose,
    Key? key,
  }) : super(key: key);

  @override
  _CreateAdminFormState createState() => _CreateAdminFormState();
}

class _CreateAdminFormState extends State<CreateAdminForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedTask;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: isMobile ? EdgeInsets.zero : EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobile)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create Admin',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                if (!isMobile) SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Name is required';
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Email is required';
                          if (!value.contains('@')) return 'Enter valid email';
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Password is required';
                          if (value.length < 6) return 'Minimum 6 characters';
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                          hintText: '712345678',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Phone is required';
                          if (value.length != 9) return '9 digits required';
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedTask,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(Icons.work),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          'Administrator',
                          'Inventory Manager',
                          'Cashier',
                          'Exit Tech'
                        ].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedTask = newValue;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Role is required' : null,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            widget.onCreateAdmin(
                              _emailController.text,
                              _passwordController.text,
                              _nameController.text,
                              '+254${_phoneController.text}',
                              _selectedTask!,
                            );
                          }
                        },
                        child: Text('Create Admin'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
      ),
    );
  }
}

// Admin List Page
class AdminListPage extends StatelessWidget {
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
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 0 : 16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Color(0xFF1E1E1E), // Dark card background
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Admin List',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white, // White text for better contrast
                    ),
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
                  stream: FirebaseFirestore.instance
                      .collection('admins')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text('No admins found',
                            style: GoogleFonts.poppins(color: Colors.white)),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final admin = snapshot.data!.docs[index];
                        final role = admin['task'] ?? 'No role assigned';

                        // Define role colors
                        final roleColor = _getRoleColor(role);

                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          color: Color(0xFF2D2D2D), // Darker card
                          child: ListTile(
                            title: Text(admin['name'],
                                style: GoogleFonts.poppins(color: Colors.white)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(admin['email'],
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey[400])),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Role: ',
                                        style: GoogleFonts.poppins(color: Colors.grey[400])),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: roleColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: roleColor),
                                      ),
                                      child: DropdownButton<String>(
                                        value: role,
                                        dropdownColor: Color(0xFF2D2D2D), // Dark dropdown
                                        style: GoogleFonts.poppins(color: Colors.white),
                                        underline: SizedBox(), // Remove default underline
                                        items: [
                                          'Administrator',
                                          'Inventory Manager',
                                          'Cashier',
                                          'Exit Tech'
                                        ].map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(
                                              value,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            onTaskUpdated(admin.id, newValue);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red[400]),
                              onPressed: () => _showDeleteDialog(
                                  context, admin.id, admin['name']),
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
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Administrator':
        return Colors.blueAccent;
      case 'Inventory Manager':
        return Colors.green;
      case 'Cashier':
        return Colors.orange;
      case 'Exit Tech':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showDeleteDialog(BuildContext context, String adminId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2D2D2D),
          title: Text('Delete Admin', style: GoogleFonts.poppins(color: Colors.white)),
          content: Text('Delete $name? This action cannot be undone.',
              style: GoogleFonts.poppins(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAdminSelected(adminId);
              },
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class UserInquiriesPage extends StatelessWidget {
  final Function(Map<String, dynamic>) onInquirySelected;
  final VoidCallback onBackPressed;

  UserInquiriesPage({
    required this.onInquirySelected,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Color(0xFF121212), // Dark background
      appBar: AppBar(
        title: Text('User Inquiries', style: GoogleFonts.poppins()),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: onBackPressed,
        ),
        backgroundColor: Color(0xFF1E1E1E),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedback')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No inquiries found',
                  style: GoogleFonts.poppins(color: Colors.white)),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final inquiry = snapshot.data!.docs[index];
              final inquiryData = inquiry.data() as Map<String, dynamic>;
              final isResponded = inquiryData['isResponded'] ?? false;
              final hasResponse = inquiryData.containsKey('response');

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('customers')
                    .doc(inquiry['userId'])
                    .get(),
                builder: (context, userSnapshot) {
                  final userName =
                  userSnapshot.hasData && userSnapshot.data!.exists
                      ? userSnapshot.data!['name']
                      : 'Deleted account';

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    color: Color(0xFF1E1E1E),
                    child: ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        child: !isResponded && !hasResponse
                            ? Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        )
                            : Icon(Icons.check_circle, color: Colors.green),
                      ),
                      title: Text(
                        userName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inquiryData['title'] ?? 'No title',
                            style: GoogleFonts.poppins(color: Colors.grey[400]),
                          ),
                          if (isResponded || hasResponse)
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Responded',
                                style: GoogleFonts.poppins(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Colors.grey[600],
                      ),
                      onTap: () => onInquirySelected({
                        'id': inquiry.id,
                        'userId': inquiry['userId'],
                        'userName': userName,
                        'description': inquiryData['description'] ?? '',
                        'isResponded': isResponded || hasResponse,
                      }),
                    ),
                  );
                },
              );
            },
          );
        },
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
  final Function() onBackPressed;

  ConversationPage({
    required this.inquiryId,
    required this.userId,
    required this.userName,
    required this.description,
    required this.isResponded,
    required this.adminName,
    required this.onBackPressed,
  });

  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final TextEditingController _responseController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName, style: GoogleFonts.poppins()),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: widget.onBackPressed,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User's message
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.userName,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text(widget.description,
                              style: GoogleFonts.poppins()),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Admin responses
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('feedback')
                        .doc(widget.inquiryId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return SizedBox();
                      }

                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      if (!data.containsKey('response')) {
                        return SizedBox();
                      }

                      final response = data['response'];
                      final responseTime =
                          (data['responseTime'] as Timestamp).toDate();

                      return Card(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.adminName,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Text(response, style: GoogleFonts.poppins()),
                              SizedBox(height: 8),
                              Text(
                                DateFormat('MMM d, y h:mm a')
                                    .format(responseTime),
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey),
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
          ),

          // Response input
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _responseController,
                    decoration: InputDecoration(
                      hintText: 'Type your response...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _submitResponse,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitResponse() async {
    if (_responseController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please enter a response')));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('feedback')
          .doc(widget.inquiryId)
          .update({
        'response': _responseController.text,
        'respondedBy': widget.adminName,
        'responseTime': DateTime.now(),
        'isResponded': true,
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Response submitted!')));
      _responseController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
