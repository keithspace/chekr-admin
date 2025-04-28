import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'accountdetails.dart';
import 'activity.dart';
import 'admin_response.dart';
import 'helpcenter.dart';
import 'landing.dart';
import 'login.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountPage extends StatefulWidget {
  final String userName;
  final int notificationCount;
  final List<String> notifications;
  final List<AdminResponse> adminResponses;
  final VoidCallback onNotificationsViewed;

  const AccountPage({
    Key? key,
    required this.userName,
    required this.notificationCount,
    required this.notifications,
    required this.adminResponses,
    required this.onNotificationsViewed,
  }) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late String _displayName;
  final firebase.FirebaseAuth _auth = firebase.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();
  String? email;
  String? phone;
  String? profilePicUrl;
  bool _isUploading = false;
  bool _hasNewNotifications = false;

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName;
    _fetchUserDetails();
    _hasNewNotifications = widget.notificationCount > 0;

    // Mark notifications as viewed when page is first opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onNotificationsViewed();
    });
  }

  @override
  void didUpdateWidget(covariant AccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notificationCount > oldWidget.notificationCount) {
      setState(() {
        _hasNewNotifications = true;
      });
    }
  }

  Future<void> _launchPrivacyPolicyUrl() async {
    final url = Uri.parse('https://www.termsfeed.com/live/b23e1ec6-735e-4a2e-98b1-18454e3e4c64');
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // Opens in browser instead of in-app
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch privacy policy')),
      );
    }
  }

  Future<void> refreshUserData() async {
    await _fetchUserDetails();
    if (mounted) setState(() {});
  }

  Future<void> _fetchUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore.collection('customers')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _displayName = data['name'] ?? widget.userName;
            email = data['email'];
            phone = data['phone'];
            profilePicUrl = data['profilePic'];
          });
        }
      } catch (e) {
        print('Error fetching user details: $e');
      }
    }
  }

  Future<String> uploadProfilePictureToSupabase(XFile imageFile) async {
    final client = SupabaseClient(
        'https://wlbdvdbnecfwmxxftqrk.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsYmR2ZGJuZWNmd214eGZ0cXJrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczODc0NzI0NywiZXhwIjoyMDU0MzIzMjQ3fQ.29nyle2IpA5tyAn6NY0K77ZhScC_ErOvtKCzKBu95Io'
    );

    final imageBytes = await imageFile.readAsBytes();
    final fileName = 'profile_pictures/${Uuid().v4()}.jpg';

    try {
      await client.storage.from('productimages').uploadBinary(
          fileName, imageBytes, fileOptions: const FileOptions(upsert: true));
      final publicUrl = client.storage.from('productimages').getPublicUrl(
          fileName);
      return publicUrl;
    } catch (e) {
      throw Exception('Profile picture upload failed: $e');
    }
  }

  Future<void> _uploadProfilePicture() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        final imageUrl = await uploadProfilePictureToSupabase(image);
        firebase.User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('customers').doc(user.uid).update({
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

  void _showNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            NotificationsPage(
              notifications: widget.notifications,
              adminResponses: widget.adminResponses,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: <Widget>[
          // Profile Image with "+" icon
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: profilePicUrl != null &&
                            profilePicUrl!.isNotEmpty
                            ? NetworkImage(profilePicUrl!)
                            : const NetworkImage(
                            'https://www.w3schools.com/w3images/avatar2.png'),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadProfilePicture,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildListTile(
            icon: Icons.history,
            title: 'Activity',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ActivityPage(userId: _auth.currentUser!.uid),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.person_outline,
            title: 'Account Details',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AccountDetailsPage()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.help_outline,
            title: 'Help Center',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpCenterPage()),
              );
            },
          ),
          // Add the Privacy Policy tile here
          _buildListTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _launchPrivacyPolicyUrl(),
          ),
          _buildListTile(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () => _showLogoutConfirmation(context),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, size: 24),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          onTap: onTap,
        ),
        const Divider(height: 1, color: Colors.grey, thickness: 0.2),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close the confirmation dialog
                await _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors
                    .red, // Make logout button red for emphasis
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Clear all authentication data
      await _auth.signOut();
      await _storage.delete(key: 'auth_token');

      // Clear any cached admin data if exists
      await _storage.delete(key: 'cachedAdminName');
      await _storage.delete(key: 'cachedAdminProfilePic');

      // Navigate to login page and remove all routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        // Changed from LandingPage to LoginPage
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      // If any error occurs, still force logout and clear data
      Navigator.of(context).pop(); // Remove loading indicator

      // Force clear all auth data
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'cachedAdminName');
      await _storage.delete(key: 'cachedAdminProfilePic');
      await _auth.signOut();

      // Force navigate to login page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        // Changed from LandingPage to LoginPage
            (Route<dynamic> route) => false,
      );
    }
  }
}

// Notification Page
class NotificationsPage extends StatelessWidget {
  final List<String> notifications;
  final List<AdminResponse> adminResponses;

  const NotificationsPage({
    Key? key,
    required this.notifications,
    required this.adminResponses,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: [
          if (notifications.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'App Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ...notifications.map((notification) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.notifications, color: Colors.blue),
              title: Text(notification),
            ),
          )),

          if (adminResponses.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Support Responses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ...adminResponses.map((response) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.green),
              title: Text(response.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(response.response),
                  const SizedBox(height: 4),
                  Text(
                    'Response from ${response.respondedBy}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )),

          if (notifications.isEmpty && adminResponses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No notifications available',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}



