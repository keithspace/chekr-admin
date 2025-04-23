import 'dart:async';
import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter/services.dart';

import 'home.dart';

class ScanPage extends StatefulWidget {
  final String username;

  const ScanPage({Key? key, required this.username}) : super(key: key);

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String barcode = "";
  Map<String, dynamic> productDetails = {};
  int quantity = 1;
  final PageController _pageController = PageController();
  Timer? _timer;
  String? profilePicUrl;
  bool isLoadingProfilePic = true;
  bool showSuccess = false;
  bool showProductCard = false;
  bool showError = false;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchCustomerProfile();
    _timer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_pageController.page!.toInt() + 1) % 3;
        _pageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchCustomerProfile() async {
    try {
      final customerId = FirebaseAuth.instance.currentUser!.uid;
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .get();

      if (customerDoc.exists) {
        setState(() {
          profilePicUrl = customerDoc.data()?['profilePic'];
          isLoadingProfilePic = false;
        });
      } else {
        setState(() {
          isLoadingProfilePic = false;
        });
      }
    } catch (e) {
      print("Error fetching customer profile: $e");
      setState(() {
        isLoadingProfilePic = false;
      });
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final scanResult = await BarcodeScanner.scan();
      if (scanResult.rawContent.isNotEmpty && mounted) {
        setState(() {
          barcode = scanResult.rawContent;
          showProductCard = false;
          showError = false;
          showSuccess = false;
          quantity = 1;
        });
        await _fetchProductDetails(barcode);
      }
    } catch (e) {
      print("Error scanning barcode: $e");
    }
  }

  Future<void> _fetchProductDetails(String barcode) async {
    try {
      final productQuery = FirebaseFirestore.instance.collection('products');
      final querySnapshot = await productQuery.get();

      bool productFound = false;

      for (var doc in querySnapshot.docs) {
        if (doc.data()['id'] == barcode) {
          productFound = true;
          if (mounted) {
            setState(() {
              productDetails = doc.data();
              showProductCard = true;
            });
            // Haptic feedback when product is found
            HapticFeedback.mediumImpact();
          }
          break;
        }
      }

      if (!productFound) {
        if (mounted) {
          setState(() {
            showError = true;
            errorMessage = "Item doesn't exist";
          });
          // Haptic feedback for error
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      print("Error fetching product details: $e");
      if (mounted) {
        setState(() {
          showError = true;
          errorMessage = "Error fetching product";
        });
        // Haptic feedback for error
        HapticFeedback.heavyImpact();
      }
    }
  }

  Future<void> _addToCart() async {
    try {
      if (quantity > (productDetails['quantity'] ?? 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cannot add more than available stock (${productDetails['quantity']})'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final customerId = FirebaseAuth.instance.currentUser!.uid;
      final cartDoc = FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .collection('cart')
          .doc('activeCart');

      final cartSnapshot = await cartDoc.get();
      List<dynamic> products = cartSnapshot.data()?['products'] ?? [];

      if (productDetails['quantity'] == 0) {
        _showAlert("This product is out of stock.");
        return;
      }

      final existingProduct = products.firstWhere(
            (product) => product['id'] == productDetails['id'],
        orElse: () => null,
      );

      if (existingProduct != null) {
        if ((existingProduct['quantity'] + quantity) >
            productDetails['quantity']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Cannot add more than available stock (${productDetails['quantity']})'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        existingProduct['quantity'] += quantity;
      } else {
        products.add({
          ...productDetails,
          'quantity': quantity,
        });
      }

      await cartDoc.set({
        'products': products,
        'lastAddedTimestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('products')
          .doc(productDetails['id'])
          .update({'quantity': FieldValue.increment(-quantity)});

      // Trigger haptic feedback
      HapticFeedback.mediumImpact();

      setState(() {
        showSuccess = true;
        showProductCard = false;
      });

      Timer(Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            showSuccess = false;
            barcode = "";
            productDetails = {};
          });
        }
      });
    } catch (e) {
      _showAlert("Failed to add product to cart. Please try again.");
      print("Error adding to cart: $e");
    }
  }

  void _showAlert(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rescan();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).then((_) {
      _rescan();
    });
  }

  void _rescan() {
    if (mounted) {
      setState(() {
        barcode = '';
        productDetails = {};
        showProductCard = false;
        showError = false;
        showSuccess = false;
        quantity = 1;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isLoadingProfilePic)
                      CircleAvatar(
                        radius: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          // Navigate to account page (index 2)
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => HomePage(
                                username: widget.username,
                                initialIndex: 2, // Account page index
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: profilePicUrl != null
                              ? CachedNetworkImageProvider(profilePicUrl!)
                              : null,
                          child: profilePicUrl == null
                              ? Icon(Icons.person, size: 24)
                              : null,
                        ),
                      ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting,',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          widget.username,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HOW TO SCAN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: PageView(
                        controller: _pageController,
                        children: [
                          _buildInstructionCard(
                            LucideIcons.qrCode,
                            'Click the scan button below',
                            'Point your device at the product barcode',
                          ),
                          _buildInstructionCard(
                            LucideIcons.scan,
                            'Point at the barcode',
                            'Align the barcode within the scanning area',
                          ),
                          _buildInstructionCard(
                            LucideIcons.check,
                            'Hold steady to scan',
                            'Keep the device steady until the scan completes',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: SmoothPageIndicator(
                        controller: _pageController,
                        count: 3,
                        effect: WormEffect(
                          dotHeight: 8,
                          dotWidth: 8,
                          activeDotColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                                width: 10,
                              ),
                            ),
                            child: Material(
                              shape: const CircleBorder(),
                              color: Colors.green,
                              child: InkWell(
                                onTap: _scanBarcode,
                                borderRadius: BorderRadius.circular(100),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(LucideIcons.qrCode,
                                          size: 48, color: Colors.white),
                                      SizedBox(height: 8),
                                      Text(
                                        'SCAN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (showSuccess) _buildSuccessIndicator(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap to scan a product',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: showProductCard || showError ? 300 : 0),
              ],
            ),
          ),

          // Overlay when product card or error is shown
          if (showProductCard || showError)
            Container(
              color: Colors.black.withOpacity(0.5),
            ),

          // Product card or error display
          if (showProductCard || showError)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: showProductCard ? _buildProductOverlay() : _buildErrorOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(
      IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.green),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductOverlay() {
    return Card(
      key: ValueKey('product'),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (productDetails['imageUrl'] != null)
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: productDetails['imageUrl'],
                      placeholder: (context, url) =>
                      const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                      fit: BoxFit.contain,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  productDetails['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ksh${productDetails['price'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 20),
                        onPressed: () {
                          if (quantity > 1) {
                            setState(() {
                              quantity--;
                              HapticFeedback.selectionClick();
                            });
                          }
                        },
                      ),
                      SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: () {
                          if (quantity < (productDetails['quantity'] ?? 0)) {
                            setState(() {
                              quantity++;
                              HapticFeedback.selectionClick();
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Only ${productDetails['quantity']} items available'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _addToCart,
                        child: const Text(
                          'Add to Cart',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _rescan,
                        child: const Text('Rescan'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.grey),
              onPressed: _rescan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Card(
      key: ValueKey('error'),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_sharp,
              size: 50,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w200,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _rescan,
              child: Text('Try Another One'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessIndicator() {
    return Positioned(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check, size: 30, color: Colors.white),
            SizedBox(height: 4),
            Text('Added!', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
