import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'receipt.dart';

class PaymentSuccessPage extends StatefulWidget {
  final String transactionId;
  final double amount;
  final List<Map<String, dynamic>> products;
  final String phoneNumber;
  final DateTime timestamp;
  final String paymode;

  const PaymentSuccessPage({
    Key? key,
    required this.transactionId,
    required this.amount,
    required this.products,
    required this.phoneNumber,
    required this.timestamp,
    required this.paymode,
  }) : super(key: key);

  @override
  _PaymentSuccessPageState createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  bool _isRatingSubmitted = false;
  bool _hasShoppingBag = false;
  int _shoppingBagCount = 0;

  @override
  void initState() {
    super.initState();
    _checkForShoppingBags();
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isRatingSubmitted) {
        _showRatingModalSheet(context);
      }
    });
  }

  void _checkForShoppingBags() {
    // Check if any product has ID '581f78e5' (shopping bag)
    for (var product in widget.products) {
      if (product['id'] == '581f78e5') {
        setState(() {
          _hasShoppingBag = true;
          _shoppingBagCount = product['quantity'] ?? 1;
        });
        break;
      }
    }
  }

  void _showRatingModalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _RatingModalSheet(
          transactionId: widget.transactionId,
          onRatingSubmitted: () {
            setState(() {
              _isRatingSubmitted = true;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Successful')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                'Thanks for shopping with Chekr!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your payment was successful!',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),

              // Display shopping bag pickup message if applicable
              if (_hasShoppingBag)
                Text(
                  _shoppingBagCount == 1
                      ? 'Pick your shopping bag at Counter 1'
                      : 'Pick your shopping bags at Counter 1',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),

              const SizedBox(height: 20),

              // View Receipt button with green outline
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReceiptPage(
                        transactionId: widget.transactionId,
                        amount: widget.amount,
                        products: widget.products,
                        phoneNumber: widget.phoneNumber,
                        timestamp: widget.timestamp,
                        paymode: widget.paymode,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: const Text(
                  'View Receipt',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'If you want to continue shopping, you can find the receipt on your Profile > Activity > Receipts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Keep your existing _RatingModalSheet class unchanged
class _RatingModalSheet extends StatefulWidget {
  final String transactionId;
  final VoidCallback onRatingSubmitted;

  const _RatingModalSheet({
    required this.transactionId,
    required this.onRatingSubmitted,
  });

  @override
  __RatingModalSheetState createState() => __RatingModalSheetState();
}

class __RatingModalSheetState extends State<_RatingModalSheet> {
  int _selectedRating = 0;
  bool _isThankYouShown = false;

  void _submitRating(int rating) async {
    await FirebaseFirestore.instance
        .collection('satisfaction')
        .doc(widget.transactionId)
        .set({
      'transactionId': widget.transactionId,
      'rating': rating,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      _isThankYouShown = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      widget.onRatingSubmitted();
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'How satisfied are you with your experience?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  Icons.star,
                  color: index < _selectedRating ? Colors.green : Colors.grey,
                  size: 40,
                ),
                onPressed: () {
                  setState(() {
                    _selectedRating = index + 1;
                  });
                  _submitRating(_selectedRating);
                },
              );
            }),
          ),
          const SizedBox(height: 20),
          if (_isThankYouShown)
            const Column(
              children: [
                Icon(Icons.thumb_up, color: Colors.green, size: 50),
                SizedBox(height: 10),
                Text(
                  'Thank you for your feedback!',
                  style: TextStyle(fontSize: 16, color: Colors.green),
                ),
              ],
            ),
        ],
      ),
    );
  }
}