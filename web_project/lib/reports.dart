import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'package:flutter_web_browser/flutter_web_browser.dart'
    if (dart.library.html) 'dart:html' as html;
import 'package:web_project/panel.dart';
import 'package:web_project/reg.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReportsPage extends StatefulWidget {
  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  Widget? _selectedReport;
  Map<String, dynamic>? adminInfo;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    fetchAdminInfo();
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer =
        Timer(const Duration(minutes: 10), _logoutDueToInactivity);
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
    // Remove the back button listener when the widget is disposed
    super.dispose();
  }

  Future<void> fetchAdminInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    if (adminId != null && adminId.isNotEmpty) {
      try {
        DocumentSnapshot adminSnapshot = await FirebaseFirestore.instance
            .collection('admins')
            .doc(adminId)
            .get();
        if (adminSnapshot.exists) {
          setState(() {
            adminInfo = adminSnapshot.data() as Map<String, dynamic>?;
          });
        }
      } catch (e) {
        print('Error fetching admin info: $e');
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_selectedReport == null) {
      // You're on the Reports Dashboard, go back to AdminHomePage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AdminHomePage()),
      );
      return false; // Prevent default pop behavior
    } else {
      // You're inside a specific report, just go back to dashboard
      setState(() {
        _selectedReport = null;
      });
      return false; // Prevent popping the page
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkTheme = theme.brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount = screenWidth < 600
        ? 1
        : screenWidth < 900
            ? 2
            : 3;

    String pageTitle = 'Reports Dashboard';
    if (_selectedReport != null) {
      if (_selectedReport is CustomerReport) {
        pageTitle = 'Customer Activity Report';
      } else if (_selectedReport is OrderReport) {
        pageTitle = 'Sales Report';
      } else if (_selectedReport is ProductReport) {
        pageTitle = 'Product Report';
      }
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1D1E33),
            ],
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              pageTitle,
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
                if (_selectedReport == null) {
                  // Already on the dashboard — go back to AdminHomePage
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => AdminHomePage()),
                  );
                } else {
                  // Inside a sub-report — just go back to dashboard
                  setState(() {
                    _selectedReport = null;
                  });
                }
              },
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedReport == null) ...[
                  Text(
                    'Reports Dashboard',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkTheme ? Colors.white : Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Access detailed reports for sales, customer activity, and product stock levels.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.7,
                        ),
                        child: GridView.builder(
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: 3, // Now showing all three reports
                          itemBuilder: (context, index) {
                            return ReportButton(
                              title: index == 0
                                  ? 'Sales Reports'
                                  : index == 1
                                      ? 'Customer Activity'
                                      : 'Product Reports',
                              icon: index == 0
                                  ? Icons.bar_chart
                                  : index == 1
                                      ? Icons.people
                                      : Icons.inventory,
                              onPressed: () {
                                if (!mounted) return;
                                setState(() {
                                  _selectedReport = index == 0
                                      ? OrderReport(adminInfo: adminInfo)
                                      : index == 1
                                          ? CustomerReport(adminInfo: adminInfo)
                                          : ProductReport(adminInfo: adminInfo);
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _selectedReport!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReportButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const ReportButton({
    required this.title,
    required this.icon,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      color: isDarkTheme ? Color(0xFF1D1E33) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: isDarkTheme ? Colors.blue[200] : Colors.blue[800],
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkTheme ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'View report',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderReport extends StatefulWidget {
  final Map<String, dynamic>? adminInfo;

  const OrderReport({Key? key, required this.adminInfo}) : super(key: key);

  @override
  _OrderReportState createState() => _OrderReportState();
}

class _OrderReportState extends State<OrderReport> {
  String searchQuery = '';
  String selectedTimeFilter = 'All Time';
  String selectedPaymentFilter = 'All';
  DateTimeRange? selectedDateRange;
  bool _isGeneratingReport = false;

  // Payment mode image URLs
  final String mpesaImageUrl =
      'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/payment_modes/mpesalogo.png';
  final String paypalImageUrl =
      'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/payment_modes/paypal.png';
  final String cardImageUrl =
      'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/payment_modes/card1.png';

  // Filter options
  final List<String> timeFilters = [
    'All Time',
    'Past 24 Hours',
    'Past Week',
    'Past Month',
    'Custom Range'
  ];
  final List<String> paymentFilters = ['All', 'M-PESA', 'PayPal', 'Card'];

  String _truncateTransactionId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 5)}...${id.substring(id.length - 5)}';
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
        selectedTimeFilter = 'Custom Range';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0E21), Color(0xFF1D1E33)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales Report',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'View detailed sales information. Filter by time period, payment method or search by transaction code.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),

            // Search and Filter Controls
            _buildFilterControls(),

            // Date range display if custom range is selected
            if (selectedTimeFilter == 'Custom Range' &&
                selectedDateRange != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${DateFormat('dd MMM yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange!.end)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                      onPressed: () {
                        setState(() {
                          selectedDateRange = null;
                          selectedTimeFilter = 'All Time';
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Orders List
            Expanded(
              child: Container(
                color: const Color(0xFF0A0E21),
                child: _buildOrdersList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          if (isMobile) {
            return Column(
              children: [
                // Search and Time Filter
                Row(
                  children: [
                    Expanded(
                      child: _buildSearchField(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimeFilterDropdown(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Payment Filter and Download Button
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentFilterDropdown(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDownloadButton(compact: true),
                    ),
                  ],
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _buildSearchField(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTimeFilterDropdown(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildPaymentFilterDropdown(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildDownloadButton(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search Transactions',
        labelStyle: GoogleFonts.poppins(color: Colors.grey[300]),
        prefixIcon: Icon(Icons.search, color: Colors.grey[300]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[800],
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      style: GoogleFonts.poppins(color: Colors.white),
      onChanged: (value) => setState(() => searchQuery = value),
    );
  }

  Widget _buildTimeFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: DropdownButton<String>(
        value: selectedTimeFilter,
        onChanged: (String? newValue) {
          if (newValue == 'Custom Range') {
            _selectDateRange(context);
          } else {
            setState(() {
              selectedTimeFilter = newValue!;
              selectedDateRange = null;
            });
          }
        },
        items: timeFilters.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }).toList(),
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[300]),
        isExpanded: true,
        hint: Text('Time Period',
            style: GoogleFonts.poppins(color: Colors.white)),
      ),
    );
  }

  Widget _buildPaymentFilterDropdown() {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: DropdownButton<String>(
          value: selectedPaymentFilter,
          onChanged: (String? newValue) =>
              setState(() => selectedPaymentFilter = newValue!),
          items: paymentFilters.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value == 'All' ? 'All Payments' : value,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            );
          }).toList(),
          underline: const SizedBox(),
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[300]),
          isExpanded: true,
          hint: Text('Payment Method',
              style: GoogleFonts.poppins(color: Colors.white)),
        ));
  }

  Widget _buildDownloadButton({bool compact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: _isGeneratingReport ? null : _downloadOrdersAsPdf,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[900],
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isGeneratingReport
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  compact ? 'Download' : 'Download Report',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
        ),
        if (_isGeneratingReport)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Generating report...',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading orders',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No orders found',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }

        var orders = snapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .where((order) =>
                order['transactionId']
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()) &&
                (selectedPaymentFilter == 'All' ||
                    order['paymentmode'].toString().toLowerCase() ==
                        selectedPaymentFilter.toLowerCase()))
            .toList();

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(
                    label: Text('#',
                        style: GoogleFonts.poppins(color: Colors.white))),
                DataColumn(
                    label: Text('Transaction ID',
                        style: GoogleFonts.poppins(color: Colors.white))),
                DataColumn(
                    label: Text('Payment Method',
                        style: GoogleFonts.poppins(color: Colors.white))),
                DataColumn(
                    label: Text('Customer',
                        style: GoogleFonts.poppins(color: Colors.white))),
                DataColumn(
                    label: Text('Phone',
                        style: GoogleFonts.poppins(color: Colors.white))),
                DataColumn(
                    label: Text('Amount',
                        style: GoogleFonts.poppins(color: Colors.white))),
                DataColumn(
                    label: Text('Date',
                        style: GoogleFonts.poppins(color: Colors.white))),
                DataColumn(
                    label: Text('Time',
                        style: GoogleFonts.poppins(color: Colors.white))),
              ],
              rows: orders.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;
                final date = order['timestamp'].toDate();
                return DataRow(
                  cells: [
                    DataCell(Text((index + 1).toString(),
                        style: GoogleFonts.poppins(color: Colors.white))),
                    DataCell(
                      Text(
                        _truncateTransactionId(
                            order['transactionId'].toString()),
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          if (order['paymentmode']
                              .toString()
                              .toLowerCase()
                              .contains('m-pesa'))
                            CachedNetworkImage(
                              imageUrl: mpesaImageUrl,
                              width: 24,
                              height: 24,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          if (order['paymentmode']
                              .toString()
                              .toLowerCase()
                              .contains('paypal'))
                            CachedNetworkImage(
                              imageUrl: paypalImageUrl,
                              width: 24,
                              height: 24,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          if (order['paymentmode']
                              .toString()
                              .toLowerCase()
                              .contains('card'))
                            CachedNetworkImage(
                              imageUrl: cardImageUrl,
                              width: 24,
                              height: 24,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            order['paymentmode'].toString(),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    DataCell(FutureBuilder<String?>(
                      future: _getCustomerName(order['userId']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text('Loading...',
                              style: GoogleFonts.poppins(color: Colors.white));
                        }
                        return Text(
                          snapshot.data ?? 'Deleted Account',
                          style: GoogleFonts.poppins(color: Colors.white),
                        );
                      },
                    )),
                    DataCell(Text(
                        _formatPhoneNumber(order['phoneNumber'].toString()),
                        style: GoogleFonts.poppins(color: Colors.white))),
                    DataCell(Text('Ksh ${order['amount'].toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(color: Colors.white))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(date),
                        style: GoogleFonts.poppins(color: Colors.white))),
                    DataCell(Text(DateFormat('HH:mm').format(date),
                        style: GoogleFonts.poppins(color: Colors.white))),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getFilteredOrders() {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime? endDate;

    switch (selectedTimeFilter) {
      case 'Past 24 Hours':
        startDate = now.subtract(const Duration(days: 1));
        break;
      case 'Past Week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Past Month':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'Custom Range':
        if (selectedDateRange != null) {
          startDate = selectedDateRange!.start;
          endDate = selectedDateRange!.end;
        } else {
          startDate = DateTime(2000);
        }
        break;
      default:
        startDate = DateTime(2000);
    }

    if (endDate != null) {
      return FirebaseFirestore.instance
          .collection('orders')
          .where('timestamp', isGreaterThan: startDate)
          .where('timestamp',
              isLessThan:
                  endDate.add(const Duration(days: 1))) // Include the end date
          .orderBy('timestamp', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('orders')
          .where('timestamp', isGreaterThan: startDate)
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  Future<void> _downloadOrdersAsPdf() async {
    setState(() {
      _isGeneratingReport = true;
    });
    try {
      // Get admin ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('adminId');

      String adminName = widget.adminInfo?['name'] ?? 'Administrator';
      String adminRole = widget.adminInfo?['role'] ?? 'System Admin';

      // Get all the orders data
      final ordersSnapshot = await _getFilteredOrders().first;

      if (ordersSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No orders found for the selected filters')),
        );
        return;
      }

      // Load organization logo
      final logoUrl =
          'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/logo/logo2.png';
      final response = await http.get(Uri.parse(logoUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to load logo: ${response.statusCode}');
      }

      final logoBytes = response.bodyBytes;

      // Prepare all data asynchronously and calculate total revenue
      final List<Map<String, dynamic>> preparedData = [];
      double totalRevenue = 0;

      for (final doc in ordersSnapshot.docs) {
        final order = doc.data() as Map<String, dynamic>;
        final date = order['timestamp'].toDate();
        final customerName =
            await _getCustomerName(order['userId']) ?? 'Deleted Account';
        final amount = order['amount'] as double;
        totalRevenue += amount;

        preparedData.add({
          'transactionId':
              _truncateTransactionId(order['transactionId'].toString()),
          'paymentMethod': order['paymentmode'].toString(),
          'customerName': customerName,
          'phone': _formatPhoneNumber(order['phoneNumber'].toString()),
          'amount': 'Ksh ${amount.toStringAsFixed(2)}',
          'date': DateFormat('dd/MM/yyyy').format(date),
          'time': DateFormat('HH:mm').format(date),
        });
      }

      // Generate time period text with date range if applicable
      String timePeriodText = selectedTimeFilter;
      if (selectedTimeFilter == 'Custom Range' && selectedDateRange != null) {
        timePeriodText =
            'Custom Range (${DateFormat('dd MMM yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange!.end)})';
      } else if (selectedTimeFilter == 'Past Week') {
        final startDate = DateTime.now().subtract(const Duration(days: 7));
        timePeriodText =
            'Past Week (${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(DateTime.now())})';
      } else if (selectedTimeFilter == 'Past Month') {
        final startDate = DateTime.now().subtract(const Duration(days: 30));
        timePeriodText =
            'Past Month (${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(DateTime.now())})';
      } else if (selectedTimeFilter == 'Past 24 Hours') {
        final startDate = DateTime.now().subtract(const Duration(days: 1));
        timePeriodText =
            'Past 24 Hours (${DateFormat('dd MMM yyyy, HH:mm').format(startDate)} - ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())})';
      }

      // Build PDF
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            final now = DateTime.now();
            final day = now.day;
            String suffix = 'th';
            if (day % 100 < 11 || day % 100 > 13) {
              switch (day % 10) {
                case 1:
                  suffix = 'st';
                  break;
                case 2:
                  suffix = 'nd';
                  break;
                case 3:
                  suffix = 'rd';
                  break;
              }
            }
            final formattedDate =
                "${day}$suffix ${DateFormat('MMMM y, h.mma').format(now)}";

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Image(
                      pw.MemoryImage(logoBytes),
                      height: 60,
                      width: 60,
                    ),
                    pw.SizedBox(width: 20),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Order Report',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Time Period: $timePeriodText',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Generated on: $formattedDate',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated by: $adminName ($adminRole)',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    <String>[
                      '#',
                      'Txn ID',
                      'Method',
                      'Customer',
                      'Phone',
                      'Amount',
                      'Date',
                      'Time'
                    ],
                    ...preparedData.asMap().entries.map(
                          (entry) => [
                            (entry.key + 1).toString(),
                            entry.value['transactionId'],
                            entry.value['paymentMethod'],
                            entry.value['customerName'],
                            entry.value['phone'],
                            entry.value['amount'],
                            entry.value['date'],
                            entry.value['time'],
                          ],
                        ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Revenue: Ksh ${totalRevenue.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Save and download PDF
      final Uint8List pdfBytes = await pdf.save();
      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download',
              'Order_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        await Printing.layoutPdf(onLayout: (_) => pdfBytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingReport = false;
        });
      }
    }
  }

  Future<String?> _getCustomerName(String userId) async {
    final customerDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(userId)
        .get();
    if (customerDoc.exists) {
      return customerDoc['name'];
    }
    return null;
  }

  String _formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.length > 6) {
      return '${phoneNumber.substring(0, 3)}XXX${phoneNumber.substring(phoneNumber.length - 3)}';
    }
    return phoneNumber;
  }
}

class CustomerReport extends StatefulWidget {
  final Map<String, dynamic>? adminInfo;

  const CustomerReport({Key? key, required this.adminInfo}) : super(key: key);

  @override
  _CustomerReportState createState() => _CustomerReportState();
}

class _CustomerReportState extends State<CustomerReport> {
  String selectedPeriod = 'All Time';
  late Future<List<Map<String, dynamic>>> customerDataFuture;
  String searchQuery = '';
  String? statusFilter;
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    customerDataFuture = fetchCustomerActivity();
  }

  Future<List<Map<String, dynamic>>> fetchCustomerActivity() async {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case 'Daily':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Weekly':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'Monthly':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(2000);
    }

    QuerySnapshot customerSnapshot =
        await FirebaseFirestore.instance.collection('customers').get();
    List<Map<String, dynamic>> customers = [];

    for (var customerDoc in customerSnapshot.docs) {
      String customerId = customerDoc.id;
      Map<String, dynamic> customerInfo =
          customerDoc.data() as Map<String, dynamic>;

      Query orderQuery = FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: customerId)
          .orderBy('timestamp')
          .startAt([startDate]);

      QuerySnapshot orderSnapshot = await orderQuery.get();
      int orderCount = orderSnapshot.docs.length;
      double totalSpent =
          orderSnapshot.docs.fold(0, (sum, doc) => sum + (doc['amount'] ?? 0));

      Query loginQuery = FirebaseFirestore.instance
          .collection('logins')
          .where('userId', isEqualTo: customerId)
          .orderBy('timestamp', descending: true)
          .limit(1);

      QuerySnapshot loginSnapshot = await loginQuery.get();
      DateTime? lastLogin = loginSnapshot.docs.isNotEmpty
          ? (loginSnapshot.docs.first['timestamp'] as Timestamp).toDate()
          : null;

      DateTime? timeRegistered =
          (customerInfo['timeRegistered'] as Timestamp?)?.toDate();

      String status = 'Inactive';
      if (lastLogin != null) {
        final daysSinceLastLogin = now.difference(lastLogin).inDays;
        status = daysSinceLastLogin <= 30 ? 'Active' : 'Inactive';
      }

      customers.add({
        'name': customerInfo['name'] ?? 'Unknown',
        'email': customerInfo['email'] ?? 'No Email',
        'orders': orderCount,
        'totalSpent': totalSpent.toStringAsFixed(2),
        'registrationDate': timeRegistered != null
            ? DateFormat('dd MMM yyyy').format(timeRegistered)
            : 'N/A',
        'lastLogin': lastLogin,
        'status': status,
      });
    }

    return customers;
  }

  Future<void> _downloadReportAsPdf() async {
    final pdf = pw.Document();
    final customerData = await customerDataFuture;
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);

    final imageBytes = await _networkImageToByteArray(
      'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/logo/logo2.png',
    );

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  width: 150,
                  height: 50,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Customer Activity Report - $selectedPeriod',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated on: [$formattedDate][$formattedTime]',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated by: ${widget.adminInfo?['name'] ?? 'N/A'} (${widget.adminInfo?['task'] ?? 'N/A'})',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  'Name',
                  'Email',
                  'Orders',
                  'Total Spent',
                  'Registration Date',
                  'Status'
                ],
                data: customerData.map((data) {
                  return [
                    data['name'],
                    data['email'],
                    data['orders'].toString(),
                    'Ksh ${data['totalSpent']}',
                    data['registrationDate'],
                    data['status'],
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    final Uint8List pdfBytes = await pdf.save();

    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
            'download', 'customer_activity_report_$selectedPeriod.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    }
  }

  Future<Uint8List> _networkImageToByteArray(String imageUrl) async {
    final response = await html.HttpRequest.request(
      imageUrl,
      method: 'GET',
      responseType: 'arraybuffer',
    );
    return Uint8List.fromList(response.response as List<int>);
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final bool isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1D1E33),
            ],
          ),
        ),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF1D1E33).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (isMobile) _buildMobileControls(),
                        if (isTablet) _buildTabletControls(),
                        if (!isMobile && !isTablet) _buildDesktopControls(),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF1D1E33).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: customerDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('Error: ${snapshot.error}',
                                style: TextStyle(color: Colors.white)),
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('No data available',
                                style: TextStyle(color: Colors.white)),
                          ),
                        );
                      }

                      var filteredData = snapshot.data!.where((customer) {
                        final name = customer['name'].toString().toLowerCase();
                        final email =
                            customer['email'].toString().toLowerCase();
                        final matchesSearch =
                            name.contains(searchQuery.toLowerCase()) ||
                                email.contains(searchQuery.toLowerCase());
                        final matchesStatus = statusFilter == null ||
                            customer['status'] == statusFilter;
                        return matchesSearch && matchesStatus;
                      }).toList();

                      return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.6,
                          ),
                          child: Scrollbar(
                            controller:
                                _verticalController, // Add controller here
                            thumbVisibility:
                                true, // Makes scrollbar always visible
                            child: SingleChildScrollView(
                              controller:
                                  _verticalController, // Match controller here
                              physics: AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Scrollbar(
                                  controller:
                                      _horizontalController, // Horizontal controller
                                  thumbVisibility: true,
                                  notificationPredicate: (notification) =>
                                      notification.depth ==
                                      1, // Only listen to inner scroll
                                  child: SingleChildScrollView(
                                    controller:
                                        _horizontalController, // Match horizontal controller
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 20,
                                      horizontalMargin: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                      ),
                                      columns: [
                                        DataColumn(
                                          label: ConstrainedBox(
                                            constraints:
                                                BoxConstraints(minWidth: 120),
                                            child: Text('Name',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                        DataColumn(
                                          label: ConstrainedBox(
                                            constraints:
                                                BoxConstraints(minWidth: 150),
                                            child: Text('Email',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                        DataColumn(
                                          label: ConstrainedBox(
                                            constraints:
                                                BoxConstraints(minWidth: 60),
                                            child: Text('Orders',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                        DataColumn(
                                          label: ConstrainedBox(
                                            constraints:
                                                BoxConstraints(minWidth: 100),
                                            child: Text('Total Spent',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                        DataColumn(
                                          label: ConstrainedBox(
                                            constraints:
                                                BoxConstraints(minWidth: 120),
                                            child: Text('Reg. Date',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                        DataColumn(
                                          label: ConstrainedBox(
                                            constraints:
                                                BoxConstraints(minWidth: 80),
                                            child: Text('Status',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                      rows: filteredData.map((data) {
                                        return DataRow(
                                          cells: [
                                            DataCell(ConstrainedBox(
                                              constraints:
                                                  BoxConstraints(maxWidth: 150),
                                              child: Text(data['name'] ?? 'N/A',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            )),
                                            DataCell(ConstrainedBox(
                                              constraints:
                                                  BoxConstraints(maxWidth: 200),
                                              child: Text(
                                                  data['email'] ?? 'N/A',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            )),
                                            DataCell(Text(
                                                data['orders'].toString(),
                                                style: TextStyle(
                                                    color: Colors.white))),
                                            DataCell(Text(
                                                'Ksh ${data['totalSpent']}',
                                                style: TextStyle(
                                                    color: Colors.white))),
                                            DataCell(Text(
                                                data['registrationDate'],
                                                style: TextStyle(
                                                    color: Colors.white))),
                                            DataCell(
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color:
                                                      data['status'] == 'Active'
                                                          ? Colors.green
                                                              .withOpacity(0.3)
                                                          : Colors.grey
                                                              .withOpacity(0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  data['status'] ?? 'N/A',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileControls() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'Search',
            labelStyle: TextStyle(color: Colors.white70),
            prefixIcon: Icon(Icons.search, color: Colors.white70),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
          style: TextStyle(color: Colors.white),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
              customerDataFuture = fetchCustomerActivity();
            });
          },
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedPeriod,
                items: ['All Time', 'Daily', 'Weekly', 'Monthly']
                    .map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                              style: GoogleFonts.poppins(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedPeriod = newValue;
                    });
                    customerDataFuture = fetchCustomerActivity();
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                style: GoogleFonts.poppins(color: Colors.white),
                dropdownColor: Color(0xFF1D1E33),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: statusFilter,
                hint: Text('Status',
                    style: GoogleFonts.poppins(color: Colors.white)),
                items: ['Active', 'Inactive']
                    .map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                              style: GoogleFonts.poppins(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    statusFilter = newValue;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                style: GoogleFonts.poppins(color: Colors.white),
                dropdownColor: Color(0xFF1D1E33),
              ),
            ),
            SizedBox(width: 10),
            IconButton(
              onPressed: _downloadReportAsPdf,
              icon: Icon(Icons.download, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Color(0xFF0A0E21),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Search',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                style: TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    customerDataFuture = fetchCustomerActivity();
                  });
                },
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedPeriod,
                items: ['All Time', 'Daily', 'Weekly', 'Monthly']
                    .map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                              style: GoogleFonts.poppins(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedPeriod = newValue;
                    });
                    customerDataFuture = fetchCustomerActivity();
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                style: GoogleFonts.poppins(color: Colors.white),
                dropdownColor: Color(0xFF1D1E33),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: statusFilter,
                hint: Text('Filter by Status',
                    style: GoogleFonts.poppins(color: Colors.white)),
                items: ['Active', 'Inactive']
                    .map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                              style: GoogleFonts.poppins(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    statusFilter = newValue;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                style: GoogleFonts.poppins(color: Colors.white),
                dropdownColor: Color(0xFF1D1E33),
              ),
            ),
            SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _downloadReportAsPdf,
              icon: Icon(Icons.download),
              label: Text('Download', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0A0E21),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                minimumSize: Size(0, 48),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopControls() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Search by Name or Email',
              labelStyle: TextStyle(color: Colors.white70),
              prefixIcon: Icon(Icons.search, color: Colors.white70),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
            style: TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
                customerDataFuture = fetchCustomerActivity();
              });
            },
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: selectedPeriod,
            items: ['All Time', 'Daily', 'Weekly', 'Monthly']
                .map((String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value,
                          style: GoogleFonts.poppins(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  selectedPeriod = newValue;
                });
                customerDataFuture = fetchCustomerActivity();
              }
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            style: GoogleFonts.poppins(color: Colors.white),
            dropdownColor: Color(0xFF1D1E33),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: statusFilter,
            hint: Text('Filter by Status',
                style: GoogleFonts.poppins(color: Colors.white)),
            items: ['Active', 'Inactive']
                .map((String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value,
                          style: GoogleFonts.poppins(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (String? newValue) {
              setState(() {
                statusFilter = newValue;
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            style: GoogleFonts.poppins(color: Colors.white),
            dropdownColor: Color(0xFF1D1E33),
          ),
        ),
        SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _downloadReportAsPdf,
          icon: Icon(Icons.download),
          label: Text('Download Report', style: GoogleFonts.poppins()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0A0E21),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class ProductReport extends StatefulWidget {
  final Map<String, dynamic>? adminInfo;

  const ProductReport({Key? key, required this.adminInfo}) : super(key: key);

  @override
  _ProductReportState createState() => _ProductReportState();
}

class _ProductReportState extends State<ProductReport> {
  List<Product> products = [];
  Map<String, int> productSalesQuantity = {};
  Map<String, double> productSalesRevenue = {};
  Map<String, List<Map<String, dynamic>>> productSalesDetails = {};
  bool isLoading = true;
  int _selectedViewIndex = 0;
  final List<String> _viewOptions = [
    'Sold Items',
    'Stock Levels',
    'Out of Stock'
  ];
  final ScrollController _scrollController = ScrollController();
  bool _showHelpSection = true;

  // Product details view variables
  Product? _selectedProduct;
  DateTimeRange? _selectedDateRange;
  int _filteredSalesQuantity = 0;
  double _filteredSalesRevenue = 0.0;
  List<Map<String, dynamic>> _filteredSalesDetails = [];

  List<Product> get outOfStockProducts =>
      products.where((product) => product.quantity == 0).toList();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([fetchProducts(), fetchSoldItems()]);
  }

  Future<void> fetchSoldItems() async {
    if (!mounted) return;

    try {
      setState(() => isLoading = true);

      final orderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get()
          .timeout(const Duration(seconds: 30));

      final newProductSalesQuantity = <String, int>{};
      final newProductSalesRevenue = <String, double>{};
      final newProductSalesDetails = <String, List<Map<String, dynamic>>>{};

      for (var orderDoc in orderSnapshot.docs) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final orderDate =
            (orderData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final orderProducts = orderData['products'] ?? [];

        for (var orderProduct in orderProducts) {
          final productId = orderProduct['id']?.toString() ?? '';
          if (productId.isEmpty) continue;

          final quantity = (orderProduct['quantity'] as num?)?.toInt() ?? 0;
          final price = (orderProduct['price'] as num?)?.toDouble() ?? 0.0;
          final revenue = quantity * price;

          newProductSalesQuantity[productId] =
              (newProductSalesQuantity[productId] ?? 0) + quantity;
          newProductSalesRevenue[productId] =
              (newProductSalesRevenue[productId] ?? 0.0) + revenue;

          if (!newProductSalesDetails.containsKey(productId)) {
            newProductSalesDetails[productId] = [];
          }
          newProductSalesDetails[productId]!.add({
            'timestamp': orderDate,
            'quantity': quantity,
            'revenue': revenue,
          });
        }
      }

      if (mounted) {
        setState(() {
          productSalesQuantity = newProductSalesQuantity;
          productSalesRevenue = newProductSalesRevenue;
          productSalesDetails = newProductSalesDetails;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      debugPrint('Error fetching sold items: $e');
    }
  }

  Widget _buildUserGuidance() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'How to use this report',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showHelpSection = false),
                tooltip: 'Hide help',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedViewIndex == 0) ...[
            _buildGuidanceItem(
              '1. View top selling products in the list',
              Icons.list_alt,
            ),
            _buildGuidanceItem(
              '2. Click the eye icon or product name to see detailed sales data',
              Icons.remove_red_eye,
            ),
            _buildGuidanceItem(
              '3. Filter by date range to analyze specific periods',
              Icons.calendar_today,
            ),
            _buildGuidanceItem(
              '4. Download reports for any view or time period',
              Icons.download,
            ),
          ] else if (_selectedViewIndex == 1) ...[
            _buildGuidanceItem(
              '1. View current stock levels for all products',
              Icons.inventory,
            ),
            _buildGuidanceItem(
              '2. Identify low stock items (highlighted in orange)',
              Icons.warning_amber,
            ),
            _buildGuidanceItem(
              '3. Download the full stock report if needed',
              Icons.download,
            ),
          ] else ...[
            _buildGuidanceItem(
              '1. View all out-of-stock products that need restocking',
              Icons.error_outline,
            ),
            _buildGuidanceItem(
              '2. Check when each product last had stock',
              Icons.history,
            ),
            _buildGuidanceItem(
              '3. Download the out-of-stock report for purchasing',
              Icons.download,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuidanceItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> fetchProducts() async {
    if (!mounted) return;

    try {
      setState(() => isLoading = true);

      final productSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('timeAdded', descending: true)
          .get()
          .timeout(const Duration(seconds: 30));

      final newProducts = productSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product(
          id: data['id']?.toString() ?? '',
          name: data['name']?.toString() ?? 'Unknown Product',
          quantity: (data['quantity'] as num?)?.toInt() ?? 0,
          price: (data['price'] as num?)?.toDouble() ?? 0.0,
          status: data['status']?.toString() ?? 'unknown',
          timeAdded:
              (data['timeAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          products = newProducts;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      debugPrint('Error fetching products: $e');
    }
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _selectedDateRange = null;
      _filteredSalesQuantity = 0;
      _filteredSalesRevenue = 0.0;
      _filteredSalesDetails = productSalesDetails[product.id] ?? [];
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      _applyDateFilter(picked);
    }
  }

  void _applyDateFilter(DateTimeRange dateRange) {
    if (_selectedProduct == null) return;

    final allSales = productSalesDetails[_selectedProduct!.id] ?? [];
    final filtered = allSales.where((sale) {
      final date = sale['timestamp'] as DateTime;
      return date.isAfter(dateRange.start) && date.isBefore(dateRange.end);
    }).toList();

    final totalQuantity =
        filtered.fold(0, (sum, sale) => sum + (sale['quantity'] as int));
    final totalRevenue =
        filtered.fold(0.0, (sum, sale) => sum + (sale['revenue'] as double));

    setState(() {
      _selectedDateRange = dateRange;
      _filteredSalesDetails = filtered;
      _filteredSalesQuantity = totalQuantity;
      _filteredSalesRevenue = totalRevenue;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
      if (_selectedProduct != null) {
        _filteredSalesDetails = productSalesDetails[_selectedProduct!.id] ?? [];
        _filteredSalesQuantity = 0;
        _filteredSalesRevenue = 0.0;
      }
    });
  }

  void _clearProductSelection() {
    setState(() {
      _selectedProduct = null;
      _selectedDateRange = null;
      _filteredSalesQuantity = 0;
      _filteredSalesRevenue = 0.0;
      _filteredSalesDetails = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0E21), Color(0xFF1D1E33)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // Header with view selection and download button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SegmentedButton<int>(
                        segments: _viewOptions.asMap().entries.map((entry) {
                          return ButtonSegment<int>(
                            value: entry.key,
                            label: Text(entry.value),
                            icon: Icon(
                              entry.key == 0
                                  ? Icons.shopping_cart
                                  : entry.key == 1
                                      ? Icons.inventory
                                      : Icons.warning,
                            ),
                          );
                        }).toList(),
                        selected: {_selectedViewIndex},
                        onSelectionChanged: (Set<int> newSelection) {
                          setState(() {
                            _selectedViewIndex = newSelection.first;
                            _selectedProduct = null;
                          });
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected)) {
                                return const Color(0xFF0A0E21).withOpacity(0.8);
                              }
                              return Colors.transparent;
                            },
                          ),
                          foregroundColor:
                              MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) => Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        if (!_showHelpSection)
                          IconButton(
                            onPressed: () =>
                                setState(() => _showHelpSection = true),
                            icon: const Icon(Icons.help_outline),
                            tooltip: 'Show help',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF0A0E21),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        const SizedBox(width: 8),
                        isMobile
                            ? IconButton(
                                onPressed:
                                    isLoading ? null : () => _generateReport(),
                                icon: const Icon(Icons.download),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A0E21),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                        color: Colors.white.withOpacity(0.2)),
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed:
                                    isLoading ? null : () => _generateReport(),
                                icon: const Icon(Icons.download),
                                label: Text('Download Report',
                                    style: GoogleFonts.poppins()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A0E21),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                        color: Colors.white.withOpacity(0.2)),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_showHelpSection)
              SliverToBoxAdapter(
                child: _buildUserGuidance(),
              ),

            if (isLoading)
              SliverToBoxAdapter(
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            // Main content area
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: isLoading
                    ? const SizedBox()
                    : _selectedProduct != null && _selectedViewIndex == 0
                        ? _buildSplitView()
                        : _buildSingleView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleView() {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildCurrentView(),
      ),
    );
  }

  Widget _buildSplitView() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 400),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Sold items list
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33).withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildSoldItemsView(showActions: false),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Right side - Product details
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33).withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildProductDetailsView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedViewIndex) {
      case 0:
        return _buildSoldItemsView();
      case 1:
        return _buildStockLevelView();
      case 2:
        return _buildOutOfStockView();
      default:
        return _buildStockLevelView();
    }
  }

  Widget _buildSoldItemsView({bool showActions = true}) {
    if (productSalesQuantity.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No sales data available',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    var sortedSales = productSalesQuantity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DataTable(
      columnSpacing: 20,
      horizontalMargin: 0,
      decoration: const BoxDecoration(color: Colors.transparent),
      columns: [
        DataColumn(
            label: Text('Product',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Qty Sold',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        if (showActions)
          DataColumn(
              label: Text('Actions',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
      ],
      rows: sortedSales.map((entry) {
        final product = products.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => Product(
            id: '',
            name: 'Unknown',
            quantity: 0,
            price: 0.0,
            status: 'unknown',
            timeAdded: DateTime.now(),
          ),
        );

        final isSelected = _selectedProduct?.id == product.id;

        return DataRow(
          color: MaterialStateProperty.resolveWith<Color>((states) {
            return isSelected
                ? Colors.blue.withOpacity(0.2)
                : Colors.transparent;
          }),
          cells: [
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  product.name,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onTap: () => _selectProduct(product),
            ),
            DataCell(
              Text('${entry.value}',
                  style: const TextStyle(color: Colors.white)),
              onTap: () => _selectProduct(product),
            ),
            if (showActions)
              DataCell(
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.blue),
                  onPressed: () => _selectProduct(product),
                  tooltip: 'View details',
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProductDetailsView() {
    final salesDetails = _selectedDateRange != null
        ? _filteredSalesDetails
        : productSalesDetails[_selectedProduct!.id] ?? [];

    final totalQuantity = _selectedDateRange != null
        ? _filteredSalesQuantity
        : productSalesQuantity[_selectedProduct!.id] ?? 0;

    final totalRevenue = _selectedDateRange != null
        ? _filteredSalesRevenue
        : productSalesRevenue[_selectedProduct!.id] ?? 0.0;

    final product = _selectedProduct!;

    // Group sales by month
    final monthlySales = <String, Map<String, dynamic>>{};
    for (var sale in salesDetails) {
      final date = sale['timestamp'] as DateTime;
      final monthKey = DateFormat('MMM y').format(date);

      if (!monthlySales.containsKey(monthKey)) {
        monthlySales[monthKey] = {'quantity': 0, 'revenue': 0.0};
      }

      monthlySales[monthKey]!['quantity'] += sale['quantity'] as int;
      monthlySales[monthKey]!['revenue'] += sale['revenue'] as double;
    }

    final sortedMonths = monthlySales.keys.toList()
      ..sort((a, b) =>
          DateFormat('MMM y').parse(a).compareTo(DateFormat('MMM y').parse(b)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Product Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _downloadProductSpecificReport(),
                    icon: Icon(Icons.download, size: 18),
                    label: Text('Download Product Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: _clearProductSelection,
                  ),
                ],
              ),
            ],
          ),

          const Divider(color: Colors.white54),

          // Product summary card with date range info
          Card(
            color: Color(0xFF0A0E21).withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (_selectedDateRange != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Date Range: ${DateFormat('MMM d, y').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  Row(
                    children: [
                      _buildStatCard('Total Sold', '$totalQuantity'),
                      SizedBox(width: 8),
                      _buildStatCard('Current Stock', '${product.quantity}'),
                      SizedBox(width: 8),
                      _buildStatCard('Total Revenue',
                          'KES ${totalRevenue.toStringAsFixed(2)}'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Showing data for ${DateFormat('MMM d, y').format(_selectedDateRange!.start)} to ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}',
                style: TextStyle(color: Colors.white70),
              ),
            ),

          const SizedBox(height: 16),

          // Date filter controls
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _selectedDateRange != null
                        ? '${DateFormat('MMM d, y').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}'
                        : 'Filter by Date Range',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A0E21),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_selectedDateRange != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearDateFilter,
                    tooltip: 'Clear filter',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.3),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Sales chart
          Text(
            'Revenue Trend',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (sortedMonths.isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E21).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: sortedMonths.length,
                      itemBuilder: (context, index) {
                        final month = sortedMonths[index];
                        final sales = monthlySales[month]!;
                        final maxRevenue = sortedMonths
                            .map((m) => monthlySales[m]!['revenue'] as double)
                            .reduce((a, b) => a > b ? a : b);
                        final height = (sales['revenue'] / maxRevenue) * 100;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Tooltip(
                                message:
                                    'KES ${sales['revenue'].toStringAsFixed(2)} in $month (${sales['quantity']} sold)',
                                child: Container(
                                  width: 40,
                                  height: height,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.greenAccent,
                                        Colors.green
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                month.split(' ')[0],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monthly Revenue (KES)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'No sales data available for the selected period',
                style: TextStyle(color: Colors.white54),
              ),
            ),

          const SizedBox(height: 16),

          // Recent sales list
          Text(
            'Recent Sales',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (salesDetails.isNotEmpty)
            ...salesDetails
                .take(5)
                .map((sale) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.circle,
                              size: 8, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${sale['quantity']} × KES ${product.price.toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, y').format(sale['timestamp']),
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          if (salesDetails.length > 5)
            TextButton(
              onPressed: () {}, // Could implement view all functionality
              child: Text(
                'View all ${salesDetails.length} sales...',
                style: TextStyle(color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33).withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockLevelView() {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No products available',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    var sortedProducts = [...products]
      ..sort((a, b) => b.timeAdded.compareTo(a.timeAdded));

    return DataTable(
      columnSpacing: 20,
      horizontalMargin: 0,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      columns: [
        DataColumn(
            label: Text('Product',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Qty',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Price',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Status',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
      ],
      rows: sortedProducts.map((product) {
        return DataRow(
          cells: [
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  product.name,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              Text('${product.quantity}',
                  style: const TextStyle(color: Colors.white)),
            ),
            DataCell(
              Text('KES ${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white)),
            ),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: product.quantity == 0
                      ? Colors.red.withOpacity(0.3)
                      : product.quantity < 10
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  product.quantity == 0
                      ? 'Out of Stock'
                      : product.quantity < 10
                          ? 'Low Stock'
                          : 'In Stock',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildOutOfStockView() {
    if (outOfStockProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'All products are in stock',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    var sortedOutOfStock = [...outOfStockProducts]
      ..sort((a, b) => b.timeAdded.compareTo(a.timeAdded));

    return DataTable(
      columnSpacing: 20,
      horizontalMargin: 0,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      columns: [
        DataColumn(
            label: Text('Product',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Price',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Last Stock',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
      ],
      rows: sortedOutOfStock.map((product) {
        return DataRow(
          cells: [
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  product.name,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              Text('KES ${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white)),
            ),
            DataCell(
              Text(
                DateFormat('dd MMM yyyy').format(product.timeAdded),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _downloadProductSpecificReport() async {
    final product = _selectedProduct!;
    final salesDetails = _selectedDateRange != null
        ? _filteredSalesDetails
        : productSalesDetails[product.id] ?? [];

    final totalQuantity = _selectedDateRange != null
        ? _filteredSalesQuantity
        : productSalesQuantity[product.id] ?? 0;

    final totalRevenue = _selectedDateRange != null
        ? _filteredSalesRevenue
        : productSalesRevenue[product.id] ?? 0.0;

    try {
      final pdf = pw.Document();
      final imageBytes = await _networkImageToByteArray(
        'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/logo/logo2.png',
      );

      final now = DateTime.now();
      final formattedDate = DateFormat('dd/MM/yyyy').format(now);
      final formattedTime = DateFormat('HH:mm').format(now);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(imageBytes),
                    width: 150,
                    height: 50,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Product Sales Report - ${product.name}',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),
                if (_selectedDateRange != null)
                  pw.Text(
                    'Date Range: ${DateFormat('MMM d, y').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}',
                    style: pw.TextStyle(fontSize: 14),
                  ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated on: $formattedDate at $formattedTime',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated by: ${widget.adminInfo?['name'] ?? 'N/A'} (${widget.adminInfo?['task'] ?? 'N/A'})',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Product: ${product.name}',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Price: KES ${product.price.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Sold: $totalQuantity',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Total Revenue: KES ${totalRevenue.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Sales Details',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                if (salesDetails.isNotEmpty)
                  pw.Table.fromTextArray(
                    headers: ['Date', 'Quantity', 'Amount'],
                    data: salesDetails.map((sale) {
                      return [
                        DateFormat('dd MMM yyyy').format(sale['timestamp']),
                        sale['quantity'].toString(),
                        'KES ${sale['revenue'].toStringAsFixed(2)}',
                      ];
                    }).toList(),
                  )
                else
                  pw.Text(
                    'No sales data available for the selected period',
                    style: pw.TextStyle(fontSize: 12),
                  ),
              ],
            );
          },
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      final fileName = _selectedDateRange != null
          ? '${product.name}_sales_${DateFormat('yyyyMMdd').format(_selectedDateRange!.start)}_to_${DateFormat('yyyyMMdd').format(_selectedDateRange!.end)}.pdf'
          : '${product.name}_sales_report.pdf';

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  Future<Uint8List> _networkImageToByteArray(String imageUrl) async {
    try {
      if (kIsWeb) {
        final response = await html.HttpRequest.request(
          imageUrl,
          method: 'GET',
          responseType: 'arraybuffer',
        );
        final typedArray = response.response as dynamic;
        return Uint8List.view(typedArray);
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error loading image: $e');
      return Uint8List(0);
    }
  }

  Future<void> _generateReport() async {
    switch (_selectedViewIndex) {
      case 0:
        await generateSoldItemsPDF();
        break;
      case 1:
        await generateStockLevelsPDF();
        break;
      case 2:
        await generateOutOfStockPDF();
        break;
    }
  }

  Future<void> generateSoldItemsPDF() async {
    final pdf = pw.Document();
    final image = await networkImage(
        'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/logo/logo2.png');

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Container(
                height: 80,
                child: pw.Image(image),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              _selectedDateRange != null
                  ? 'Product Sales Report (${DateFormat('MMM d, y').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange!.end)})'
                  : 'Product Sales Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy').format(DateTime.now())} ${DateFormat('HH:mm:ss').format(DateTime.now())}'),
            pw.SizedBox(height: 10),
            pw.Text(
                'Generated by: ${widget.adminInfo?['name'] ?? 'N/A'} (${widget.adminInfo?['task'] ?? 'N/A'})'),
            pw.SizedBox(height: 20),
            if (_selectedProduct != null) ...[
              pw.Text(
                'Product: ${_selectedProduct!.name}',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Price: KES ${_selectedProduct!.price.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Total Sold: ${_selectedDateRange != null ? _filteredSalesQuantity : productSalesQuantity[_selectedProduct!.id] ?? 0}',
                style: pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Total Revenue: KES ${_selectedDateRange != null ? _filteredSalesRevenue.toStringAsFixed(2) : (productSalesRevenue[_selectedProduct!.id] ?? 0.0).toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 20),
            ],
            pw.Table.fromTextArray(
              headers: ['Product Name', 'Qty Sold', 'Revenue (KES)'],
              data: productSalesQuantity.entries.map((entry) {
                final product = products.firstWhere(
                  (p) => p.id == entry.key,
                  orElse: () => Product(
                    id: '',
                    name: 'Unknown',
                    quantity: 0,
                    price: 0.0,
                    status: 'unknown',
                    timeAdded: DateTime.now(),
                  ),
                );
                return [
                  product.name,
                  entry.value.toString(),
                  (productSalesRevenue[product.id] ?? 0.0).toStringAsFixed(2),
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    await _saveAndSharePdf(
      pdfBytes,
      _selectedProduct != null
          ? '${_selectedProduct!.name}_sales_report.pdf'
          : _selectedDateRange != null
              ? 'sales_report_${DateFormat('yyyyMMdd').format(_selectedDateRange!.start)}_to_${DateFormat('yyyyMMdd').format(_selectedDateRange!.end)}.pdf'
              : 'sales_report.pdf',
    );
  }

  Future<void> generateStockLevelsPDF() async {
    final pdf = pw.Document();
    final image = await networkImage(
        'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/logo/logo2.png');

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Container(
                height: 80,
                child: pw.Image(image),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Stock Levels Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
                'Generated on: [${DateFormat('dd/MM/yyyy').format(DateTime.now())}] [${DateFormat('HH:mm:ss').format(DateTime.now())}]'),
            pw.SizedBox(height: 10),
            pw.Text(
                'Generated by: ${widget.adminInfo?['name'] ?? 'N/A'} (${widget.adminInfo?['task'] ?? 'N/A'})'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Product Name', 'Quantity', 'Price'],
              data: products.map((product) {
                return [
                  product.name,
                  '${product.quantity}',
                  'KES ${product.price.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    await _saveAndSharePdf(pdfBytes, 'stock_levels_report.pdf');
  }

  Future<void> generateOutOfStockPDF() async {
    final pdf = pw.Document();
    final image = await networkImage(
        'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/logo/logo2.png');

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Container(
                height: 80,
                child: pw.Image(image),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Out of Stock Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
                'Generated on: [${DateFormat('dd/MM/yyyy').format(DateTime.now())}] [${DateFormat('HH:mm:ss').format(DateTime.now())}]'),
            pw.SizedBox(height: 10),
            pw.Text(
                'Generated by: ${widget.adminInfo?['name'] ?? 'N/A'} (${widget.adminInfo?['task'] ?? 'N/A'})'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Product Name', 'Price'],
              data: outOfStockProducts.map((product) {
                return [
                  product.name,
                  'KES ${product.price.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    await _saveAndSharePdf(pdfBytes, 'out_of_stock_report.pdf');
  }

  Future<void> _saveAndSharePdf(Uint8List pdfBytes, String fileName) async {
    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    }
  }
}

class Order {
  final String transactionId;
  final double amount;
  final String paymentMode;
  final DateTime timestamp;

  Order({
    required this.transactionId,
    required this.amount,
    required this.paymentMode,
    required this.timestamp,
  });
}

class Product {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String status;
  final DateTime timeAdded;

  Product({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.status,
    required this.timeAdded,
  });
}
