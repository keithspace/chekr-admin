import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:checkoutapp/mobile/payment_success.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:checkoutapp/services/mpesa_service.dart';
import 'package:flutter_braintree/flutter_braintree.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'package:live_currency_rate/live_currency_rate.dart';
import 'package:url_launcher/url_launcher.dart';


class OrderPage extends StatefulWidget {
  final String cartId;
  final String userId;
  final String sessionId;

  const OrderPage({
    required this.cartId,
    required this.userId,
    required this.sessionId,
    Key? key,
  }) : super(key: key);

  @override
  _OrderPageState createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  bool _isListening = false;
  late double _totalAmount;
  String _loadingMessage = 'Processing payment...';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paymentListener;
  bool _paymentVerified = false;
  String? _paypalToken;
  Future<double> _convertKesToUsd(double kesAmount) async {
    try {
      CurrencyRate rate = await LiveCurrencyRate.convertCurrency("KES", "USD", kesAmount);
      return rate.result;
   } catch (e) {
      // Fallback rate in case the API fails
      debugPrint("Error getting live rate: $e");
      return kesAmount / 130.0; // Use a reasonable fallback rate
    }
  }

  @override
  void dispose() {
    _paymentListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: const Text('Order Summary')),
      body: Stack(
        children: [
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('customers')
                .doc(widget.userId)
                .collection('cart')
                .doc(widget.cartId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('No items in the cart.'));
              }

              final cartData = snapshot.data!.data() ?? {};
              final products = List<Map<String, dynamic>>.from(cartData['products'] ?? []);

              _totalAmount = products.fold(0.0, (sum, item) {
                final price = (item['price'] ?? 0).toDouble();
                final quantity = (item['quantity'] ?? 1).toDouble();
                return sum + (price * quantity);
              });

              final tax = _totalAmount * (0.08 / 1.08);
              final subtotal = _totalAmount - tax;

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final price = (product['price'] ?? 0).toDouble();
                        final quantity = (product['quantity'] ?? 1) as int;
                        return ListTile(
                          leading: product.containsKey('imageUrl') && product['imageUrl'] != null
                              ? Image.network(
                            product['imageUrl'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported, size: 50),
                          )
                              : const Icon(Icons.image_not_supported, size: 50),
                          title: Text(product['name'] ?? 'Unnamed Product'),
                          subtitle: Text(
                              'Price: Ksh.${price.toStringAsFixed(2)}\nQuantity: $quantity'),
                          trailing: Text(
                              'Total: Ksh.${(price * quantity).toStringAsFixed(2)}'),
                        );
                      },
                    ),
                  ),
                  const Divider(thickness: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal: KES ${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w300),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              child: const Text('Edit Cart',
                                  style: TextStyle(fontSize: 16, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tax: KES ${tax.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w300),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Total: KES ${_totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => _showPaymentOptions(context, _totalAmount),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Proceed to Pay',
                              style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              _loadingMessage,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _silentlyWakeUpServers() async {
    try {
      // Fire and forget - we don't await these as we want them to run in background
      unawaited(
        Future.wait([
          http.get(Uri.parse('https://paypalserver-ycch.onrender.com'))
              .timeout(const Duration(seconds: 5))
              .catchError((e) => null),
          http.get(Uri.parse('https://server-iz6n.onrender.com/test'))
              .timeout(const Duration(seconds: 5))
              .catchError((e) => null),
        ]).then((responses) {
          // Optional: Log the results if needed
          debugPrint('PayPal server status: ${responses[0]?.statusCode}');
          debugPrint('MPesa server status: ${responses[1]?.statusCode}');
        }),
      );
    } catch (e) {
      debugPrint('Silent server wakeup error: $e');
    }
  }

  void _showPaymentOptions(BuildContext context, double totalAmount) {
    // Silently wake up servers in the background without showing loading
    _silentlyWakeUpServers();

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Payment Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           /* ListTile(
              leading: Image.asset('assets/images/card1.png', width: 40, height: 30),
              title: const Text('Card Payment'),
              onTap: () {
                Navigator.pop(context);
                _processCardPayment(totalAmount);
              },
            ),*/
            ListTile(
              leading: Image.asset('assets/images/icons8-mpesa-96.png', width: 40, height: 30),
              title: const Text('M-Pesa'),
              onTap: () async {
                Navigator.pop(context);
                // Wait for the bottom sheet to fully close and animations to complete
                await Future.delayed(const Duration(milliseconds: 500));
                if (mounted) {
                  // Get a fresh context that's guaranteed to be valid
                  final freshContext = _scaffoldKey.currentContext;
                  if (freshContext != null) {
                    _showMpesaBottomSheet(freshContext, totalAmount);
                  }
                }
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/paypal.png', width: 40, height: 30),
              title: const Text('PayPal'),
              onTap: () {
                Navigator.pop(context);
                _processPaypalPayment(totalAmount);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }


  Future<void> _processCardPayment(double kesAmount) async {
    await _vibrate();

    // Get conversion rate first
    final usdAmount = await _convertKesToUsd(kesAmount);

    // Show processing overlay with both currencies
    _showPaymentProcessingOverlay(
      kesAmount: kesAmount,
      usdAmount: usdAmount,
      message: 'Preparing card payment...',
    );

    try {
      // Fetch client token dynamically
      final clientToken = await _getClientToken();

      // Dismiss the loading overlay
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _isLoading = true;
        _loadingMessage = 'Processing payment...';
      });

      final request = BraintreeDropInRequest(
        clientToken: clientToken,
        collectDeviceData: true,
        googlePaymentRequest: BraintreeGooglePaymentRequest(
          totalPrice: usdAmount.toStringAsFixed(2),
          currencyCode: 'USD',
        ),
        paypalRequest: BraintreePayPalRequest(
          amount: usdAmount.toStringAsFixed(2),
          displayName: 'Chekr',
        ),
        cardEnabled: true,
      );

      final result = await BraintreeDropIn.start(request);

      if (result != null) {
        await _vibrate(type: HapticFeedbackType.success);
        await _handleSuccessfulPayment(
          paymentMethod: result.paymentMethodNonce.typeLabel ?? 'Card',
          transactionId: result.paymentMethodNonce.nonce,
          amount: kesAmount,
        );
      } else {
        await _vibrate(type: HapticFeedbackType.mediumImpact);
        setState(() => _isLoading = false);
        _showPaymentDialog('Payment Cancelled', 'Payment was cancelled');
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await _vibrate(type: HapticFeedbackType.error);
      setState(() => _isLoading = false);
      _showPaymentDialog('Error', 'Error processing payment: $e');
    }
  }

  void _showPaymentProcessingOverlay({
    required double kesAmount,
    required double usdAmount,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/card.png', width: 100, height: 100),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'KES ${kesAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                '≈ \$${usdAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Please wait while we connect to payment processor',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPaypalPayment(double kesAmount) async {
    await _vibrate();

    // Track dialog state
    bool isDialogShown = true;
    NavigatorState? navigator;

    // Show processing dialog with live rate conversion
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        navigator = Navigator.of(context);
        return WillPopScope(
          onWillPop: () async => false,
          child: FutureBuilder<double>(
            future: _convertKesToUsd(kesAmount),
            builder: (context, snapshot) {
              //final usdAmount = snapshot.hasData ? snapshot.data! : kesAmount / 130.0;
              final isRateLoaded = snapshot.connectionState == ConnectionState.done;

              return AlertDialog(
                contentPadding: const EdgeInsets.all(20),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/paypal.png', width: 100, height: 100),
                    const SizedBox(height: 20),
                    const Text(
                      'Processing PayPal Payment',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'KES ${kesAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    /*Text(
                      '≈ \$${usdAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),*/
                    if (!isRateLoaded) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Fetching current exchange rates...',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 30),
                    isRateLoaded
                        ? const CircularProgressIndicator()
                        : const LinearProgressIndicator(),
                    const SizedBox(height: 20),
                    const SizedBox(height: 10),
                    const Text(
                      'Return to app when payment is complete',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 10),

                    GestureDetector(
                      onTap: () async {
                        const url = 'https://www.paypal.com/ke/legalhub/paypal/useragreement-full';
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text(
                        'Terms and Conditions Apply',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    try {
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Processing PayPal payment...';
      });

      // Get token and convert amount
      final token = await _getClientToken();
      final usdAmount = await _convertKesToUsd(kesAmount);

      final request = BraintreePayPalRequest(
        amount: usdAmount.toStringAsFixed(2),
        displayName: 'Chekr',
        currencyCode: 'USD',
      );

      // Launch PayPal flow
      final result = await Braintree.requestPaypalNonce(token, request);

      // Dismiss dialog
      if (isDialogShown && navigator != null) {
        navigator!.pop();
        isDialogShown = false;
      }

      if (result != null) {
        await _vibrate(type: HapticFeedbackType.success);
        await _handleSuccessfulPayment(
          paymentMethod: 'PayPal',
          transactionId: result.nonce,
          amount: kesAmount, // Store original KES amount
        );
      } else {
        await _vibrate(type: HapticFeedbackType.mediumImpact);
        setState(() => _isLoading = false);
        _showPaymentDialog('Payment Cancelled', 'PayPal payment was cancelled');
      }
    } on PlatformException catch (e) {
      if (isDialogShown && navigator != null) {
        navigator!.pop();
        isDialogShown = false;
      }
      await _vibrate(type: HapticFeedbackType.error);
      setState(() => _isLoading = false);
      _showPaymentDialog(
        'Payment Error',
        e.message ?? 'Please check your internet connection and try again',
      );
    } catch (e) {
      if (isDialogShown && navigator != null) {
        navigator!.pop();
        isDialogShown = false;
      }
      await _vibrate(type: HapticFeedbackType.error);
      setState(() => _isLoading = false);
      _showPaymentDialog(
        'Payment Error',
        e.toString().contains('internet')
            ? e.toString()
            : 'Please check your internet connection and try again',
      );
    }
  }


  void _showMpesaBottomSheet(BuildContext context, double totalAmount) async {
    final scaffoldContext = _scaffoldKey.currentContext ?? context;
    if (!mounted) return;

    // Get user phone number
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.userId)
        .get();

    String userPhone = userSnapshot['phone'] ?? '';

    // Format phone number
    if (userPhone.startsWith('0')) {
      userPhone = userPhone.substring(1);
    } else if (userPhone.startsWith('254')) {
      userPhone = userPhone.substring(3);
    }

    TextEditingController phoneController = TextEditingController(text: userPhone);

    showModalBottomSheet(
      context: scaffoldContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pay with M-Pesa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Amount Display
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount to Pay:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'KES ${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Phone Input
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  onChanged: (value){
                    if (mounted) setState(() {
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'M-Pesa Phone Number',
                    hintText: '7XXXXXXXX',
                    prefix: const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Text('+254 '),
                    ),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[100],
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.contact_page),
                      onPressed: () {
                        phoneController.text = userPhone ?? '';
                      },
                      tooltip: 'Use my phone number',
                    ),
                    counterText: '',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${phoneController.text.length}/9',
                      style: TextStyle(
                        color: phoneController.text.length < 9 ? Colors.red : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your M-Pesa registered phone number',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Pay Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child:ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () async {
                      String userInput = phoneController.text.trim();
                      if (userInput.length == 9 && RegExp(r'^[0-9]+$').hasMatch(userInput)) {
                        String fullPhoneNumber = '254$userInput';
                        Navigator.pop(context);
                        setState(() {
                          _isLoading = true;
                          _loadingMessage = 'STK request sent...';
                        });

                        bool paymentInitiated = await _initiateMpesaPayment(
                            context,
                            fullPhoneNumber,
                            totalAmount
                        );

                        if (!paymentInitiated && mounted) {
                          setState(() => _isLoading = false);
                          _showAlert("STK push failed. Please try again.");
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Invalid phone number format. Enter 9 digits after 254"))
                        );
                      }
                    },
                    child: Text(
                        'Recieve M-Pesa STK Push',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),

                  ),

                ),
                const SizedBox(height: 10),

              // Help Text
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'You will receive an M-Pesa STK push prompt on your phone',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),

// Terms and Conditions Link
              GestureDetector(
                onTap: () async {
                  const url = 'https://www.safaricom.co.ke/media-center-landing/terms-and-conditions/m-pesa-customer-terms-conditions';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text(
                  'Terms and Conditions Apply',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Safaricom Logo
              Image.asset(
                'assets/images/mpesalogo.png', width: 100,
                height: 40,
                fit: BoxFit.contain,
              ),

              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          );
        },
    );
  }

  void _showAlert(String message) async {
    if (!mounted) return;
    
    await _vibrate(type: HapticFeedbackType.error);
    showDialog(
      context: _scaffoldKey.currentContext!,
      builder: (context) => AlertDialog(
        title: Text('Payment Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }


  Future<bool> _initiateMpesaPayment(BuildContext context, String phoneNumber, double amount) async {
    try {
      bool success = await MpesaService().initiateMpesaPayment(
        userId: widget.userId,
        phoneNumber: phoneNumber,
        amount: amount,
        cartId: widget.cartId,
        sessionId: widget.sessionId,
      );

      if (success) {
        if (mounted) {
          setState(() {
            _isListening = true;
            _loadingMessage = 'Checking if payment was successful...';
          });
          _listenForPaymentStatus(); // Start listening after successful STK push
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("M-Pesa initiation error: $e");
      return false;
    }
  }

  void _listenForPaymentStatus() {
    final orderRef = FirebaseFirestore.instance.collection('orders');

    _paymentListener = orderRef
        .where('userId', isEqualTo: widget.userId)
        .where('amount', isEqualTo: _totalAmount)
        .where('cartId', isEqualTo: widget.cartId)
        .where('sessionId', isEqualTo: widget.sessionId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final orderData = change.doc.data();
          if (orderData != null) {
            if (orderData['status'] == 'Completed') {
              setState(() {
                _isListening = false;
                _isLoading = false;
              });

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentSuccessPage(
                    transactionId: orderData['transactionId'].toString(),
                    amount: (orderData['amount'] ?? 0).toDouble(),
                    products: List<Map<String, dynamic>>.from(orderData['products'] ?? []),
                    phoneNumber: orderData['phoneNumber'].toString(),
                    timestamp: (orderData['timestamp'] as Timestamp).toDate(),
                    paymode: orderData['paymentmode'].toString(),
                  ),
                ),
              );
            }
            else if (orderData['status'] == 'Failed') {
              setState(() {
                _isListening = false;
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment unsuccessful. Please try again.'))
              );
            }
          }
        }
      }
    }, onError: (error) {
      debugPrint("Payment listener error: $error");
      if (mounted) {
        setState(() {
          _isListening = false;
          _isLoading = false;
        });
      }
    });
  }


  Future<void> _handleSuccessfulPayment({
    required String paymentMethod,
    required String transactionId,
    required double amount,
  }) async {
    try {
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.userId)
          .collection('cart')
          .doc(widget.cartId)
          .get();

      if (!cartSnapshot.exists) throw Exception('Cart not found');

      final cartData = cartSnapshot.data()!;
      final products = List<Map<String, dynamic>>.from(cartData['products'] ?? []);

      await FirebaseFirestore.instance.collection('orders').doc(transactionId).set({
        'userId': widget.userId,
        'cartId': widget.cartId,
        'sessionId': widget.sessionId,
        'transactionId': transactionId,
        'amount': amount,
        'products': products,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Completed',
        'paymentmode': paymentMethod,
        'phoneNumber': paymentMethod == 'M-Pesa' ? cartData['phoneNumber'] : '',
      });

      await cartSnapshot.reference.delete();

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessPage(
              transactionId: transactionId,
              amount: amount,
              products: products,
              phoneNumber: paymentMethod == 'M-Pesa' ? cartData['phoneNumber'].toString() : '',
              timestamp: DateTime.now(),
              paymode: paymentMethod,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showPaymentDialog('Error', 'Error completing order: $e');
      }
    }
  }

  Future<String> _getClientToken() async {
    try {
      final response = await http.post(
        Uri.parse('https://paypalserver-ycch.onrender.com/generate-braintree-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['token'];
      }
      throw Exception('Please check your internet connection and try again');
    } on http.ClientException {
      throw Exception('Please check your internet connection and try again');
    } on TimeoutException {
      throw Exception('Connection timeout. Please try again');
    } catch (e) {
      throw Exception('Please check your internet connection and try again');
    }
  }

  Future<void> _vibrate({HapticFeedbackType type = HapticFeedbackType.selectionClick}) async {
    if (await Vibration.hasVibrator() ?? false) {
      switch (type) {
        case HapticFeedbackType.success:
          await Vibration.vibrate(pattern: [0, 50, 100, 50]);
          break;
        case HapticFeedbackType.error:
          await Vibration.vibrate(pattern: [0, 200, 100, 200]);
          break;
        default:
          await Vibration.vibrate(duration: 10);
      }
    }
  }

  void _showPaymentDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _vibrate();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

enum HapticFeedbackType {
  selectionClick,
  success,
  error,
  mediumImpact,
}