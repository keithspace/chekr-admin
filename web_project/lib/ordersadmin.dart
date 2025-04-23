import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:html' as html;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_project/panel.dart';
import 'package:web_project/reg.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({Key? key}) : super(key: key);

  @override
  _OrderManagementPageState createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  String searchQuery = '';
  String selectedTimeFilter = 'All Time';
  String selectedPaymentFilter = 'All';
  Timer? _inactivityTimer;
  DateTimeRange? selectedDateRange;

  // Payment mode image URLs
  final String mpesaImageUrl = 'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/payment_modes/mpesalogo.png';
  final String paypalImageUrl = 'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/payment_modes/paypal.png';
  final String cardImageUrl = 'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/payment_modes/card1.png';

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
      initialDateRange: selectedDateRange ?? DateTimeRange(
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => AdminHomePage()),
                  (Route<dynamic> route) => false,
            );
          },
        ),
        title: Text(
          'Order Management',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      backgroundColor: const Color(0xFF1D1E33),
      body: Column(
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'View and manage all customer orders. Filter by time period, payment method or search by transaction code.',
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
          if (selectedTimeFilter == 'Custom Range' && selectedDateRange != null)
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
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
    return ElevatedButton(
      onPressed: _downloadOrdersAsPdf,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[900],
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        compact ? 'Download' : 'Download Report',
        style: GoogleFonts.poppins(color: Colors.white),
      ),
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
                              placeholder: (context, url) => const CircularProgressIndicator(),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          if (order['paymentmode']
                              .toString()
                              .toLowerCase()
                              .contains('paypal'))
                            CachedNetworkImage(
                              imageUrl: paypalImageUrl,
                              width: 24,
                              height: 24,
                              placeholder: (context, url) => const CircularProgressIndicator(),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          if (order['paymentmode']
                              .toString()
                              .toLowerCase()
                              .contains('card'))
                            CachedNetworkImage(
                              imageUrl: cardImageUrl,
                              width: 24,
                              height: 24,
                              placeholder: (context, url) => const CircularProgressIndicator(),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            order['paymentmode'].toString(),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      FutureBuilder<String>(
                        future: _getCustomerName(order['userId']),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text('Loading...',
                                style:
                                GoogleFonts.poppins(color: Colors.white));
                          }
                          return Text(
                            snapshot.data ?? 'Deleted Account',
                            style: GoogleFonts.poppins(color: Colors.white),
                          );
                        },
                      ),
                    ),
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

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
          .where('timestamp', isLessThan: endDate.add(const Duration(days: 1))) // Include the end date
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
    try {
      // Get admin ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('adminId');

      String adminName = 'Administrator';
      String adminRole = 'System Admin';

      if (adminId != null && adminId.isNotEmpty) {
        // Fetch admin details from Firestore
        final adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(adminId)
            .get();

        if (adminDoc.exists) {
          final adminData = adminDoc.data()!;
          adminName = adminData['name'] ?? adminName;
          adminRole = adminData['task'] ?? adminRole;
        }
      }

      // Get all the orders data
      final ordersSnapshot = await _getFilteredOrders().first;

      if (ordersSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No orders found for the selected filters')),
        );
        return;
      }

      // Load organization logo
      final logoUrl = 'https://wlbdvdbnecfwmxxftqrk.supabase.co/storage/v1/object/public/productimages/logo/logo2.png';
      final response = await http.get(Uri.parse(logoUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to load logo: ${response.statusCode}');
      }

      final logoBytes = response.bodyBytes;

      // Prepare all data asynchronously
      final List<Map<String, dynamic>> preparedData = [];

      for (final doc in ordersSnapshot.docs) {
        final order = doc.data() as Map<String, dynamic>;
        final date = order['timestamp'].toDate();
        final customerName = await _getCustomerName(order['userId']) ?? 'Deleted Account';

        preparedData.add({
          'transactionId': _truncateTransactionId(order['transactionId'].toString()),
          'paymentMethod': order['paymentmode'].toString(),
          'customerName': customerName,
          'phone': _formatPhoneNumber(order['phoneNumber'].toString()),
          'amount': 'Ksh ${order['amount'].toStringAsFixed(2)}',
          'date': DateFormat('dd/MM/yyyy').format(date),
          'time': DateFormat('HH:mm').format(date),
        });
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
            final formattedDate = "${day}$suffix ${DateFormat('MMMM y, h.mma').format(now)}";

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
                          'Order Management Report',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
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
                      'Txn ID',
                      'Method',
                      'Customer',
                      'Phone',
                      'Amount',
                      'Date',
                      'Time'
                    ],
                    ...preparedData.map(
                          (data) => [
                        data['transactionId'],
                        data['paymentMethod'],
                        data['customerName'],
                        data['phone'],
                        data['amount'],
                        data['date'],
                        data['time'],
                      ],
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
          ..setAttribute('download', 'Order_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        await Printing.layoutPdf(onLayout: (_) => pdfBytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: ${e.toString()}')),
      );
    }
  }


  Future<String> _getCustomerName(String userId) async {
    final customerDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(userId)
        .get();
    if (customerDoc.exists) {
      return customerDoc['name'];
    }
    return 'Deleted Account';
  }

  String _formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.length > 6) {
      return '${phoneNumber.substring(0, 3)}XXX${phoneNumber.substring(phoneNumber.length - 3)}';
    }
    return phoneNumber;
  }
}
