import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'receipt.dart'; // Import the ReceiptPage

class ActivityPage extends StatefulWidget {
  final String userId;

  const ActivityPage({Key? key, required this.userId}) : super(key: key);

  @override
  _ActivityPageState createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Receipts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionsList(),
          _buildReceiptsList(),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No activity found. You have not made any purchases yet.'),
          );
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            final transactionId = order['transactionId'];
            final amount = (order['amount'] as num).toDouble();
            final products = order['products'] as List?;
            final timestamp = (order['timestamp'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transaction ID: $transactionId',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Amount: KES $amount',
                        style: const TextStyle(color: Colors.green)),
                    Text('Date: ${timestamp.toLocal().toString().split(' ')[0]}',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8.0),
                    const Text('Products Purchased:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    if (products != null && products.isNotEmpty)
                      ...products.map((product) {
                        return Text(
                            '${product['name']} - KES ${product['price']} (Qty: ${product['quantity']})');
                      }).toList()
                    else
                      const Text('No products found for this order.'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReceiptsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No receipts found.'));
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            final transactionId =
            order['transactionId'].toString(); // Ensure it's a String
            final amount =
            (order['amount'] as num).toDouble(); // Convert to double
            final timestamp = (order['timestamp'] as Timestamp).toDate();

            // Ensure products is a List<Map<String, dynamic>>
            final products = List<Map<String, dynamic>>.from(
                order['products'] as List<dynamic>);

            // Convert phoneNumber to String if it's stored as a number
            final phoneNumber = order['phoneNumber'] != null
                ? order['phoneNumber'].toString()
                : '';

            // Retrieve payment mode
            final paymode = order['paymentmode']?.toString() ??
                'N/A'; // Ensure it's a String

            return ListTile(
              title: Text('Receipt for Transaction ID: $transactionId'),
              subtitle:
              Text('Date: ${timestamp.toLocal().toString().split(' ')[0]}'),
              onTap: () {
                // Navigate to the ReceiptPage to view/download the receipt
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceiptPage(
                      transactionId: transactionId,
                      amount: amount,
                      products: products,
                      phoneNumber: phoneNumber,
                      timestamp: timestamp,
                      paymode: paymode,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
