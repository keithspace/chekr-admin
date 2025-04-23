import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_project/panel.dart';
import 'package:web_project/reg.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({Key? key}) : super(key: key);

  @override
  _CustomerManagementPageState createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  String? selectedCustomerId;
  String? selectedTransactionId;
  TextEditingController searchController = TextEditingController();
  Timer? _inactivityTimer;

  String _truncateTransactionId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 5)}...${id.substring(id.length - 5)}';
  }

  Future<void> _deleteCustomer(String customerId, String email) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Deletion',
              style: GoogleFonts.poppins(color: Colors.white)),
          content: Text('Are you sure you want to delete this customer?',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: const Color(0xFF1D1E33),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
              Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .delete();
      try {
        UserCredential userCredential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: 'your_password_here',
        );
        await userCredential.user?.delete();
      } catch (e) {
        print('Error deleting user: $e');
      }
    }
  }

  Future<void> _deleteCartItem(String customerId, int index) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Deletion',
              style: GoogleFonts.poppins(color: Colors.white)),
          content: Text('Are you sure you want to delete this item?',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: const Color(0xFF1D1E33),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
              Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      var cartRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .collection('cart')
          .doc('activeCart');

      var cartSnapshot = await cartRef.get();
      if (cartSnapshot.exists) {
        var products = cartSnapshot.data()?['products'] as List<dynamic>? ?? [];
        if (index < products.length) {
          var productToDelete = products[index];
          products.removeAt(index);

          await cartRef.update({'products': products});

          var productId = productToDelete['id'];
          var productRef =
          FirebaseFirestore.instance.collection('products').doc(productId);
          var productSnapshot = await productRef.get();
          if (productSnapshot.exists) {
            int currentQuantity = productSnapshot['quantity'];
            int newQuantity =
                currentQuantity + (productToDelete['quantity'] as num).toInt();
            await productRef.update({'quantity': newQuantity});
          }
        }
      }
    }
  }

  Future<void> _updateCartItemQuantity(
      String customerId, int index, int newQuantity) async {
    if (newQuantity <= 0) {
      await _deleteCartItem(customerId, index);
      return;
    }

    var cartRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('cart')
        .doc('activeCart');

    var cartSnapshot = await cartRef.get();
    if (cartSnapshot.exists) {
      var products = cartSnapshot.data()?['products'] as List<dynamic>? ?? [];
      if (index < products.length) {
        var productToUpdate = products[index];
        int oldQuantity = productToUpdate['quantity'];
        products[index]['quantity'] = newQuantity;

        await cartRef.update({'products': products});

        var productId = productToUpdate['id'];
        var productRef =
        FirebaseFirestore.instance.collection('products').doc(productId);
        var productSnapshot = await productRef.get();
        if (productSnapshot.exists) {
          int currentQuantity = productSnapshot['quantity'];
          int newProductQuantity = currentQuantity + (oldQuantity - newQuantity);
          await productRef.update({'quantity': newProductQuantity});
        }
      }
    }
  }

  Future<void> _increaseCartItemQuantity(String customerId, int index) async {
    var cartRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('cart')
        .doc('activeCart');

    var cartSnapshot = await cartRef.get();
    if (cartSnapshot.exists) {
      var products = cartSnapshot.data()?['products'] as List<dynamic>? ?? [];
      if (index < products.length) {
        var productToUpdate = products[index];
        int newQuantity = productToUpdate['quantity'] + 1;
        products[index]['quantity'] = newQuantity;

        await cartRef.update({'products': products});

        var productId = productToUpdate['id'];
        var productRef =
        FirebaseFirestore.instance.collection('products').doc(productId);
        var productSnapshot = await productRef.get();
        if (productSnapshot.exists) {
          int currentQuantity = productSnapshot['quantity'];
          int newProductQuantity = currentQuantity - 1;
          await productRef.update({'quantity': newProductQuantity});
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
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
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customers',
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
      backgroundColor: const Color(0xFF0A0E21),
      body: Column(
        children: [
          // Search Bar with white text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: searchController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search customers...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                filled: true,
                fillColor: const Color(0xFF1D1E33),
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          Expanded(
            child: isMobile
                ? _buildMobileLayout()
                : Row(
              children: [
                // Customers List
                Expanded(
                  flex: 3,
                  child: _buildCustomerList(),
                ),
                // Vertical Divider
                if (selectedCustomerId != null)
                  Container(
                    width: 1,
                    color: Colors.grey[700],
                  ),
                // Customer Details or Order Details
                if (selectedCustomerId != null)
                  Expanded(
                    flex: 5,
                    child: selectedTransactionId == null
                        ? _buildCustomerDetails()
                        : _buildOrderDetails(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    if (selectedCustomerId == null) {
      return _buildCustomerList();
    } else {
      return selectedTransactionId == null
          ? _buildCustomerDetails()
          : _buildOrderDetails();
    }
  }

  Widget _buildCustomerList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .where('emailVerified', isEqualTo: true) // Add this filter
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white)));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Something went wrong',
                  style: GoogleFonts.poppins(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('No verified customers found',
                  style: GoogleFonts.poppins(color: Colors.white)));
        }

        var customers = snapshot.data!.docs.where((customer) {
          var name = customer['name'].toString().toLowerCase();
          var email = customer['email'].toString().toLowerCase();
          var searchTerm = searchController.text.toLowerCase();
          return name.contains(searchTerm) ||
              email.contains(searchTerm);
        }).toList();

        final isMobile = MediaQuery.of(context).size.width < 600;

        return ListView.builder(
          itemCount: customers.length,
          itemBuilder: (context, index) {
            var customer = customers[index];
            var profilePic = customer.data().toString().contains('profilePic')
                ? customer['profilePic']
                : '';

            return Card(
              margin: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: const Color(0xFF1D1E33),
              child: ListTile(
                leading: CircleAvatar(
                  radius: isMobile ? 20 : 24,
                  backgroundImage: profilePic.isNotEmpty
                      ? NetworkImage(profilePic)
                      : null,
                  child: profilePic.isEmpty
                      ? Icon(Icons.person,
                      color: Colors.white,
                      size: isMobile ? 20 : 24)
                      : null,
                ),
                title: Text(
                  customer['name'],
                  style: GoogleFonts.poppins(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: isMobile ? null : Text(
                  customer['email'],
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey[300]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete,
                      color: Colors.red,
                      size: isMobile ? 20 : 24),
                  onPressed: () {
                    _deleteCustomer(customer.id, customer['email']);
                  },
                ),
                onTap: () {
                  setState(() {
                    selectedCustomerId = customer.id;
                    selectedTransactionId = null;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerDetails() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close Button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    selectedCustomerId = null;
                  });
                },
              ),
            ),
            // Customer Details
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .doc(selectedCustomerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white)));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error loading customer details',
                          style: GoogleFonts.poppins(color: Colors.white)));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                      child: Text('Customer not found',
                          style: GoogleFonts.poppins(color: Colors.white)));
                }

                var customer = snapshot.data!;
                var phoneNumber = customer['phone'] ?? 'N/A';
                var hiddenPhoneNumber = phoneNumber.length > 6
                    ? '${phoneNumber.substring(0, 3)}XXX${phoneNumber.substring(phoneNumber.length - 3)}'
                    : phoneNumber;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['name'],
                      style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Email: ${customer['email']}',
                      style: GoogleFonts.poppins(
                          fontSize: 16, color: Colors.grey[300]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phone: $hiddenPhoneNumber',
                      style: GoogleFonts.poppins(
                          fontSize: 16, color: Colors.grey[300]),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            // Active Cart
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: const Color(0xFF1D1E33),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('customers')
                      .doc(selectedCustomerId)
                      .collection('cart')
                      .doc('activeCart')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white)));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Error loading cart',
                              style: GoogleFonts.poppins(color: Colors.white)));
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Center(
                          child: Text('No Active Cart',
                              style: GoogleFonts.poppins(color: Colors.white)));
                    }

                    var cart = snapshot.data!;
                    var products = (cart.data() as Map<String, dynamic>)['products'] as List<dynamic>? ?? [];

                    if (products.isEmpty) {
                      return Center(
                          child: Text('Cart is Empty',
                              style: GoogleFonts.poppins(color: Colors.white)));
                    }

                    double total = 0;
                    for (var product in products) {
                      total += product['price'] * product['quantity'];
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Cart',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        ...products.map((product) {
                          return ListTile(
                            title: Text(product['name'],
                                style:
                                GoogleFonts.poppins(color: Colors.white)),
                            subtitle: Text(
                                'Price: Ksh ${product['price']} | Qty: ${product['quantity']}',
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[300])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove, color: Colors.red),
                                  onPressed: () async {
                                    int newQuantity = product['quantity'] - 1;
                                    await _updateCartItemQuantity(
                                        selectedCustomerId!,
                                        products.indexOf(product),
                                        newQuantity);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.add, color: Colors.green),
                                  onPressed: () async {
                                    await _increaseCartItemQuantity(
                                        selectedCustomerId!,
                                        products.indexOf(product));
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    await _deleteCartItem(selectedCustomerId!,
                                        products.indexOf(product));
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        Divider(color: Colors.grey[300]),
                        Text(
                          'Total: KES ${total.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Transaction History
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: const Color(0xFF1D1E33),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Transaction History',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: searchController,
                                  style: GoogleFonts.poppins(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Search by Transaction ID',
                                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey[700]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey[700]!),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF1D1E33).withOpacity(0.5),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transaction History',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: searchController,
                                style: GoogleFonts.poppins(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search by Transaction ID',
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey[700]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey[700]!),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF1D1E33).withOpacity(0.5),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                                ),
                                onChanged: (value) => setState(() {}),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('userId', isEqualTo: selectedCustomerId)
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          );
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
                              'No Orders Yet!',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          );
                        }

                        var orders = snapshot.data!.docs.where((order) {
                          var transactionId = order['transactionId'].toString().toLowerCase();
                          var searchTerm = searchController.text.toLowerCase();
                          return transactionId.contains(searchTerm);
                        }).toList();

                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              columnSpacing: 20,
                              horizontalMargin: 16,
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'Transaction ID',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Amount',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Date',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              rows: orders.map((order) {
                                var date = order['timestamp'].toDate();
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            selectedTransactionId = order['transactionId'];
                                          });
                                        },
                                        child: Text(
                                          _truncateTransactionId(order['transactionId']),
                                          style: GoogleFonts.poppins(
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        'Ksh ${order['amount']}',
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(date),
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back Button
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      selectedTransactionId = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'Order Details',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Order Details
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('transactionId', isEqualTo: selectedTransactionId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white)));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error loading order details',
                          style: GoogleFonts.poppins(color: Colors.white)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                      child: Text('Order not found',
                          style: GoogleFonts.poppins(color: Colors.white)));
                }

                var order = snapshot.data!.docs.first;
                var date = order['timestamp'].toDate();
                var products = order['products'] as List<dynamic>;
                double total = order['amount'];

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  color: const Color(0xFF1D1E33),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction ID: ${order['transactionId']}',
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Date: ${DateFormat('dd/MM/yyyy').format(date)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'Time: ${DateFormat('HH:mm').format(date)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'Payment Method: ${order['paymentmode']}',
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Products:',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        ...products.map((product) {
                          return ListTile(
                            title: Text(product['name'],
                                style: GoogleFonts.poppins(color: Colors.white)),
                            subtitle: Text(
                                'Ksh ${product['price']} x ${product['quantity']}',
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[300])),
                            trailing: Text(
                                'Ksh ${(product['price'] * product['quantity']).toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                    color: Colors.white)),
                          );
                        }).toList(),
                        const Divider(color: Colors.grey),
                        Text(
                          'Total: Ksh ${total.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
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
    );
  }
}