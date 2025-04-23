import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:web_project/reg.dart';
import 'addproduct.dart';
import 'customers.dart';
import 'generatebarcode.dart';
import 'ordersadmin.dart';
import 'products.dart';
import 'profile.dart';
import 'reports.dart';
import 'dart:math';

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.green[50],
      ),
      home: AdminHomePage(),
    );
  }
}

class AdminHomePage extends StatefulWidget {
  final String? adminId;


  AdminHomePage({Key? key, this.adminId}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  Timer? _inactivityTimer;
  String? _cachedAdminName;
  String? _cachedAdminProfilePic;

  final List<String> _menuTitles = [
    'Dashboard',
    'Customers',
    'Products List',
    'Add Product',
    'Orders',
    'Reports',
    'Profile'
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.people_sharp,
    Icons.grid_view,
    Icons.add_box,
    Icons.list,
    Icons.download_for_offline_rounded,
    Icons.admin_panel_settings_outlined
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadCachedAdminData();
    _pages = [
      AdminDashboardPage(adminId: widget.adminId),
      CustomerManagementPage(),
      ProductsGridPage(),
      AddProductPage(),
      OrderManagementPage(),
      ReportsPage(),
      AdminProfilePage(),
    ];
    _resetInactivityTimer();
  }

  Future<void> _loadCachedAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cachedAdminName = prefs.getString('cachedAdminName');
      _cachedAdminProfilePic = prefs.getString('cachedAdminProfilePic');
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 10), _logoutDueToInactivity);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      child: Scaffold(
        appBar: AppBar(
          title: _buildAppBarTitle(),
          backgroundColor: const Color(0xFF1D1E33),
          leading: isMobile ? _buildMenuButton(context) : null,
        ),
        drawer: isMobile ? _buildDrawer() : null,
        body: Row(
          children: [
            if (!isMobile) _buildSidebar(),
            Expanded(child: _pages[_selectedIndex]),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return Row(
      children: [
        Text(
          "CHEKR ADMIN",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Spacer(),
        _buildAdminRow(), // This now just shows the help icon and logout button
      ],
    );
  }

  Widget _buildAdminRow() {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.help_outline, color: Colors.white),
          onPressed: () {
            // TODO: Implement help functionality
          },
        ),
        SizedBox(width: 10),
        Text(
          'Logout',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        ),
        SizedBox(width: 5),
        IconButton(
          icon: Icon(Icons.logout, color: Colors.white),
          onPressed: () => _showLogoutConfirmation(context),
        ),
      ],
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Logout'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to logout?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('adminId');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => AdminLoginPage()),
                      (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return Builder(
      builder: (BuildContext scaffoldContext) {
        return IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(scaffoldContext).openDrawer();
          },
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: const Color(0xFF1D1E33),
      child: Column(
        children: [
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CachedNetworkImage(
              imageUrl: 'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/logo/logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              placeholder: (context, url) => CircularProgressIndicator(),
              errorWidget: (context, url, error) => Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 60,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _menuTitles.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(
                    _menuIcons[index],
                    color: _selectedIndex == index ? Colors.blueAccent : Colors.white,
                  ),
                  title: Text(
                    _menuTitles[index],
                    style: GoogleFonts.poppins(
                      color: _selectedIndex == index ? Colors.blueAccent : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  selected: _selectedIndex == index,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                      if (MediaQuery.of(context).size.width < 800) {
                        Navigator.pop(context);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1D1E33),
      child: _buildSidebar(),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  final String? adminId;

  AdminDashboardPage({Key? key, this.adminId}) : super(key: key);

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<Map<String, int>> _countsFuture;
  late Future<Map<String, int>> _paymentMethodsFuture;
  late Future<List<FlSpot>> _lineChartFuture;
  late Future<double> _userSatisfactionFuture;
  int _newInquiryCount = 0;
  List<String> _newInquiryUserNames = [];

  @override
  void initState() {
    super.initState();
    _initializeFutures();
    _fetchNewInquiries();
  }

  void _initializeFutures() {
    _countsFuture = _fetchCounts();
    _paymentMethodsFuture = _fetchPaymentMethodsData();
    _lineChartFuture = _fetchLineChartData();
    _userSatisfactionFuture = _fetchUserSatisfaction();
  }

  Future<void> _fetchNewInquiries() async {
    FirebaseFirestore.instance
        .collection('feedback')
        .where('response', isNull: true)
        .snapshots()
        .listen((snapshot) {
      final newCount = snapshot.docs.length;
      final userNames = <String>[];

      if (newCount > 0) {
        snapshot.docs.forEach((doc) async {
          final userDoc = await FirebaseFirestore.instance
              .collection('customers')
              .doc(doc['userId'])
              .get();
          if (userDoc.exists) {
            userNames.add(userDoc['name']);
          } else {
            userNames.add('Deleted account');
          }
        });
      }

      setState(() {
        _newInquiryCount = newCount;
        _newInquiryUserNames = userNames;
      });
    });
  }

  Future<Map<String, int>> _fetchCounts() async {
    final totalUsers = await _getTotalUsers();
    final activeCarts = await _getActiveCarts();
    final dailyVisits = await _getDailyVisits();
    final totalSalesToday = await _getTotalSalesToday();

    return {
      'totalUsers': totalUsers,
      'activeCarts': activeCarts,
      'dailyVisits': dailyVisits,
      'totalSalesToday': totalSalesToday,
    };
  }

  Future<int> _getTotalUsers() async {
    final totalUsersSnapshot = await FirebaseFirestore.instance.collection('customers').get();
    return totalUsersSnapshot.docs.length;
  }

  Future<int> _getActiveCarts() async {
    final activeCartsSnapshot = await FirebaseFirestore.instance.collectionGroup('cart')
        .where('cartStatus', isEqualTo: 'active').get();
    return activeCartsSnapshot.docs.length;
  }

  Future<int> _getDailyVisits() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final dailyLoginsSnapshot = await FirebaseFirestore.instance.collection('logins')
        .where('timestamp', isGreaterThan: startOfDay).get();

    final uniqueUserIds = <String>{};
    for (var doc in dailyLoginsSnapshot.docs) {
      uniqueUserIds.add(doc['userId']);
    }
    return uniqueUserIds.length;
  }

  Future<int> _getTotalSalesToday() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final totalSalesTodaySnapshot = await FirebaseFirestore.instance.collection('orders')
        .where('timestamp', isGreaterThan: startOfDay).get();
    return totalSalesTodaySnapshot.docs.length;
  }

  Future<Map<String, int>> _fetchPaymentMethodsData() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final ordersSnapshot = await FirebaseFirestore.instance.collection('orders')
        .where('timestamp', isGreaterThan: startOfDay).get();

    final paymentMethods = <String, int>{};
    for (var doc in ordersSnapshot.docs) {
      final paymode = doc['paymentmode'] as String? ?? 'Unknown';
      paymentMethods[paymode] = (paymentMethods[paymode] ?? 0) + 1;
    }

    return paymentMethods;
  }

  Future<List<FlSpot>> _fetchLineChartData() async {
    try {
      final today = DateTime.now();
      final last7Days = today.subtract(Duration(days: 6));

      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('timestamp', isGreaterThan: last7Days)
          .get();

      Map<DateTime, double> ordersByDay = {};

      for (var doc in ordersSnapshot.docs) {
        final timestamp = doc['timestamp'];

        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          final normalizedDay = DateTime(date.year, date.month, date.day);
          final saleAmount = (doc['amount'] ?? 0.0).toDouble();
          ordersByDay[normalizedDay] = (ordersByDay[normalizedDay] ?? 0) + saleAmount;
        }
      }

      List<FlSpot> spots = [];
      for (var i = 0; i < 7; i++) {
        final day = today.subtract(Duration(days: 6 - i));
        final normalizedDay = DateTime(day.year, day.month, day.day);
        final totalSales = ordersByDay[normalizedDay] ?? 0.0;
        spots.add(FlSpot(i.toDouble(), totalSales));
      }

      return spots;
    } catch (error) {
      print("Error fetching sales data: $error");
      return [];
    }
  }

  String _getDayLabel(int index) {
    final today = DateTime.now();
    final day = today.subtract(Duration(days: 6 - index));
    return DateFormat('E').format(day);
  }

  Future<double> _fetchUserSatisfaction() async {
    final satisfactionSnapshot = await FirebaseFirestore.instance.collection('satisfaction').get();
    if (satisfactionSnapshot.docs.isEmpty) return 0.0;

    double totalRating = 0;
    for (var doc in satisfactionSnapshot.docs) {
      totalRating += doc['rating'];
    }

    final averageRating = totalRating / satisfactionSnapshot.docs.length;
    return (averageRating / 5) * 100;
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Admin Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${DateFormat('EEE, d MMMM y').format(DateTime.now())}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            FutureBuilder<Map<String, int>>(
              future: _countsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  final counts = snapshot.data!;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildCard('Today\'s Visits', counts['dailyVisits'].toString(), Icons.visibility, Colors.blueAccent),
                      _buildCard('Registered Users', counts['totalUsers'].toString(), Icons.people, Colors.greenAccent),
                      _buildCard('Active Carts', counts['activeCarts'].toString(), Icons.shopping_cart, Colors.orangeAccent),
                      _buildCard('Total Sales Today', counts['totalSalesToday'].toString(), Icons.attach_money, Colors.purpleAccent),
                    ],
                  );
                }
              },
            ),
            Divider(color: Colors.grey, thickness: 1, height: 40),
            isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildLineChartCard(),
        SizedBox(height: 20),
        _buildPieChartCard(),
        SizedBox(height: 20),
        _buildUserSatisfactionCard(),
        SizedBox(height: 20),
        _buildLowStockProductsCard(),
        if (_newInquiryCount > 0) ...[
          SizedBox(height: 20),
          _buildNewInquiriesCard(),
        ],
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildLineChartCard(),
              SizedBox(height: 20),
              _buildPieChartCard(),
            ],
          ),
        ),
        VerticalDivider(color: Colors.grey, thickness: 1, width: 20),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildUserSatisfactionCard(),
              SizedBox(height: 20),
              _buildLowStockProductsCard(),
              if (_newInquiryCount > 0) ...[
                SizedBox(height: 20),
                _buildNewInquiriesCard(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewInquiriesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mark_email_unread, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'New Inquiries ($_newInquiryCount)',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            if (_newInquiryUserNames.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _newInquiryUserNames.take(3).map((name) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '• $name',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                    ),
                  ),
                )).toList(),
              ),
            if (_newInquiryUserNames.length > 3)
              Text(
                '...and ${_newInquiryUserNames.length - 3} more',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Implement navigation to inquiries page
                  setState(() {
                    _newInquiryCount = 0; // Clear count when viewing all
                  });
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: 200,
        height: 150,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 5),
            Text(
              count,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockProductsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('quantity', isLessThan: 5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No low stock products',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                );
              } else {
                final lowStockProducts = snapshot.data!.docs;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Low Stock Products (${lowStockProducts.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: lowStockProducts.length,
                        itemBuilder: (context, index) {
                          final product = lowStockProducts[index];
                          final data = product.data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CachedNetworkImage(
                              imageUrl: data['imageUrl'] ?? '',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                              errorWidget: (context, url, error) => Icon(Icons.error),
                            ),
                            title: Text(
                              data['name'] ?? 'Unknown Product',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Qty: ${data['quantity']}',
                              style: GoogleFonts.poppins(
                                color: Colors.red[200],
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.add, color: Colors.blue),
                              onPressed: () {
                                _showRestockDialog(context, product.id, data['name']);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _showRestockDialog(BuildContext context, String productId, String productName) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Restock $productName'),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity to add',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (quantityController.text.isNotEmpty) {
                  final quantityToAdd = int.tryParse(quantityController.text) ?? 0;
                  if (quantityToAdd > 0) {
                    final doc = await FirebaseFirestore.instance
                        .collection('products')
                        .doc(productId)
                        .get();
                    final currentQty = doc['quantity'] ?? 0;

                    await FirebaseFirestore.instance
                        .collection('products')
                        .doc(productId)
                        .update({
                      'quantity': currentQty + quantityToAdd,
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$productName restocked successfully')),
                    );
                  }
                }
              },
              child: Text('Restock'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLineChartCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 300,
          child: FutureBuilder<List<FlSpot>>(
            future: _lineChartFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                final spots = snapshot.data!;
                return Column(
                  children: [
                    Text(
                      'Weekly Sales Trend',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    '${spot.y.toInt()} sales\n${_getDayLabel(spot.x.toInt())}',
                                    GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.withOpacity(0.2),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 20,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _getDayLabel(value.toInt()),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          lineBarsData: [
                          LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.blueAccent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blueAccent.withOpacity(0.1),
                          ),
                          )
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 300,
          child: FutureBuilder<Map<String, int>>(
            future: _paymentMethodsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                final paymentMethods = snapshot.data!;
                if (paymentMethods.isEmpty) {
                  return Center(
                    child: Text(
                      'No payment data available',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    Text(
                      'Payment Methods Distribution',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sections: paymentMethods.entries.map((entry) {
                            return PieChartSectionData(
                              value: entry.value.toDouble(),
                              color: _getPieColor(entry.key),
                              title: '${entry.key}\n(${entry.value})',
                              radius: 80,
                              titleStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUserSatisfactionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 150,
          child: FutureBuilder<double>(
            future: _userSatisfactionFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                final satisfaction = snapshot.data!;
                final Color gaugeColor;
                if (satisfaction >= 70) {
                  gaugeColor = Colors.green;
                } else if (satisfaction >= 50) {
                  gaugeColor = Colors.blue;
                } else {
                  gaugeColor = Colors.red;
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'User Satisfaction',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(200, 100),
                            painter: _SemiCirclePainter(
                              color: Colors.grey.withOpacity(0.3),
                              strokeWidth: 10,
                              startAngle: 180,
                              sweepAngle: 180,
                            ),
                          ),
                          CustomPaint(
                            size: Size(200, 100),
                            painter: _SemiCirclePainter(
                              color: gaugeColor,
                              strokeWidth: 10,
                              startAngle: 180,
                              sweepAngle: 180 * (satisfaction / 100),
                            ),
                          ),
                          Positioned(
                            bottom: 20,
                            child: Text(
                              '${satisfaction.toStringAsFixed(0)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: gaugeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Color _getPieColor(String paymode) {
    switch (paymode) {
      case 'M-Pesa':
        return Colors.blue;
      case 'Credit Card':
        return Colors.green;
      case 'PayPal':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _SemiCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double startAngle;
  final double sweepAngle;

  _SemiCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    canvas.drawArc(
      rect,
      startAngle * (pi / 180),
      sweepAngle * (pi / 180),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

void main() => runApp(AdminDashboard());