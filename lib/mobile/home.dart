import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'account.dart';
import 'helpcenter.dart';
import 'scan.dart';
import 'cart.dart';
import 'admin_response.dart';


class HomePage extends StatefulWidget {
  final String username;
  final int initialIndex;

  const HomePage({
    Key? key,
    required this.username,
    this.initialIndex = 1, // Default to Scan page (index 1)
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String _currentUsername;
  late int _selectedIndex;
  int _cartItemCount = 0;
  int _notificationCount = 0;
  DateTime? _lastBackPressTime;
  Timer? _notificationTimer;

  late List<Widget> _pages;
  List<String> notifications = [];
  List<AdminResponse> adminResponses = [];

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.username;
    _selectedIndex = widget.initialIndex;
    _fetchUserData();
    _ensureSessionIdExists();
    _pages = [
      CartPage(),
      ScanPage(username: _currentUsername),
      AccountPage(
        userName: _currentUsername,
        notificationCount: _notificationCount,
        notifications: notifications,
        adminResponses: adminResponses,
        onNotificationsViewed: () {
          setState(() {
            _notificationCount = 0;
          });
        },
      ),
    ];
    _fetchCartItemCount();
    _startNotificationTimer();
    _listenForAdminResponses();
  }

  Future<void> _ensureSessionIdExists() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final cartDoc = FirebaseFirestore.instance
        .collection('customers')
        .doc(userId)
        .collection('cart')
        .doc('activeCart');

    final cartSnapshot = await cartDoc.get();

    if (!cartSnapshot.exists || cartSnapshot.data()?['sessionId'] == null) {
      var uuid = Uuid();
      String sessionId = uuid.v4();
      await cartDoc.set({
        'sessionId': sessionId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _fetchUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .get();

      if (doc.exists) {
        setState(() {
          _currentUsername = doc.data()?['name'] ?? 'Guest';
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  void _listenForAdminResponses() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      FirebaseFirestore.instance
          .collection('feedback')
          .where('userId', isEqualTo: userId)
          .where('response', isNotEqualTo: null)
          .where('isNewResponse', isEqualTo: true) // Only listen for new responses
          .snapshots()
          .listen((snapshot) {
        for (var doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added || doc.type == DocumentChangeType.modified) {
            final data = doc.doc.data() as Map<String, dynamic>;

            // Create new AdminResponse
            final response = AdminResponse(
              title: data['title'],
              description: data['description'] ?? 'No description',
              response: data['response'],
              timestamp: (data['responseTime'] as Timestamp).toDate(),
              respondedBy: data['respondedBy'] ?? 'Admin',
              isNew: true,
            );

            setState(() {
              // Add to beginning of list to show newest first
              adminResponses.insert(0, response);
              _updateNotificationCount();
            });

            // Add a single notification about new admin response
            _addNotification('You have a new admin response to your query');
          }
        }
      });
    }
  }

  void _updateNotificationCount() {
    setState(() {
      _notificationCount = notifications.length +
          (adminResponses.any((r) => r.isNew) ? 1 : 0);
    });
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(Duration(minutes: 25), (timer) {
      _checkCartIdleTime();
    });
  }

  void _checkCartIdleTime() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final cartDoc = FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .doc('activeCart');

      final cartSnapshot = await cartDoc.get();
      if (cartSnapshot.exists) {
        final lastAddedTimestamp =
        cartSnapshot.data()?['lastAddedTimestamp']?.toDate();
        if (lastAddedTimestamp != null) {
          final now = DateTime.now();
          final difference = now.difference(lastAddedTimestamp);

          if (difference.inMinutes >= 5) {
            _addNotification(
                'You have items in your cart. Would you like to proceed to checkout?');
          }
        }
      }
    }
  }

  void _addNotification(String message) {
    if (!notifications.contains(message)) {
      setState(() {
        notifications.insert(0, message);
        _updateNotificationCount();
      });
    }
  }

  void _showNotifications() {
    // Mark all admin responses as read in Firestore
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      FirebaseFirestore.instance
          .collection('feedback')
          .where('userId', isEqualTo: userId)
          .where('isNewResponse', isEqualTo: true)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'isNewResponse': false});
        }
      });
    }

    // Mark all as read locally
    setState(() {
      adminResponses =
          adminResponses.map((r) => r.copyWith(isNew: false)).toList();
      _notificationCount = 0;
    });

    // Navigate to NotificationsPage
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            NotificationsPage(
              notifications: notifications,
              adminResponses: adminResponses,
              /*onResponseOpened: (response) {
                // Handle the response opened logic here
                // For example, you can navigate to a detailed view of the response
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AdminResponseDetailPage(response: response),
                  ),
                );
              },*/
            ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _fetchCartItemCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .doc('activeCart')
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          final products = data?['products'] as List<dynamic>? ?? [];
          setState(() {
            _cartItemCount = products.length;
          });
        } else {
          setState(() {
            _cartItemCount = 0;
          });
        }
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 1) {
      setState(() {
        _selectedIndex = 1;
      });
      return false;
    }

    if (_lastBackPressTime == null ||
        DateTime.now().difference(_lastBackPressTime!) >
            const Duration(seconds: 2)) {
      _lastBackPressTime = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Press back again to exit')),
      );
      return false;
    }
    return true;
  }

  void _navigateToHelpCenter() {
    setState(() {
      _selectedIndex = 2;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const HelpCenterPage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _getPageTitle(_selectedIndex),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          actions: [
            if (_selectedIndex == 1)
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: _navigateToHelpCenter,
              ),
            if (_selectedIndex == 2)
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: _showNotifications,
                  ),
                  if (_notificationCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '$_notificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.shopping_cart),
                  if (_cartItemCount > 0)
                    Positioned(
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 10,
                          minHeight: 10,
                        ),
                        child: Text(
                          '$_cartItemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.document_scanner),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.person),
                  if (_notificationCount > 0)
                    Positioned(
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 10,
                          minHeight: 10,
                        ),
                        child: Text(
                          '$_notificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Cart';
      case 1:
        return 'Chekr';
      case 2:
        return 'Account';
      default:
        return 'Chekr';
    }
  }
}


