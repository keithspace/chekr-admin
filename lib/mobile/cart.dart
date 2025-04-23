import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'orders.dart';

class CartPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cartStream = FirebaseFirestore.instance
        .collection('customers')
        .doc(FirebaseAuth.instance.currentUser !.uid)
        .collection('cart')
        .doc('activeCart')
        .snapshots();

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: cartStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cartData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final products = cartData['products'] as List<dynamic>? ?? [];
          final sessionId = cartData['sessionId'] as String? ?? '';

          double totalPrice = 0;
          for (var product in products) {
            totalPrice += ((product['price'] as num?)?.toDouble() ?? 0.0) *
                (product['quantity'] ?? 0);
          }

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 50,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.lightGreenAccent[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      leading: Image.network(
                        product['imageUrl'] ?? '',
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image_not_supported),
                      ),
                      title: Text(
                        product['name'] ?? 'Unnamed Product',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      subtitle: Text(
                        'Ksh${(product['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontWeight:FontWeight.w300),
                      ),
                      trailing: _buildQuantityControls(context, product, products),
                    );
                  },
                ),
              ),
              const Divider(thickness: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Total: KES${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        _checkForBagsAndProceed(context, products, sessionId);
                      },
                      child: const Text('Proceed to Checkout',
                          style: TextStyle(fontSize: 16, color: Colors.green)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuantityControls(BuildContext context, Map<String, dynamic> product, List<dynamic> products) {
    return Container(
      height: 40,
      width: 160,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 0.5),
        borderRadius: BorderRadius.circular(100),
      ),
      padding: EdgeInsets.symmetric(horizontal:0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.green, size: 16),
            onPressed: () {
              HapticFeedback.mediumImpact(); // Add haptic feedback
              _increaseProductQuantity(context, product, products);
            },
          ),
          Text(
            '${product['quantity'] ?? 0}',
            style: TextStyle(fontSize: 14),
          ),
          IconButton(
            icon: Icon(Icons.remove, color: Colors.red, size: 16),
            onPressed: () {
              HapticFeedback.mediumImpact(); // Add haptic feedback
              _removeProductFromCart(context, product, products);
            },
          ),
          SizedBox(width: 0),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.grey, size: 16),
            onPressed: () {
              HapticFeedback.heavyImpact(); // Stronger feedback for delete
              _confirmRemoveProduct(context, product, products);
            },
          ),
        ],
      ),
    );
  }

  void _confirmRemoveProduct(BuildContext context, Map<String, dynamic> product, List<dynamic> products) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder (borderRadius: BorderRadius.circular(15)),
          title: Text('Remove Product?'),
          content: Text('Are you sure you want to remove this product from your cart?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _removeProductCompletely(context, product, products);
              },
              child: Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeProductCompletely(BuildContext context, Map<String, dynamic> product, List<dynamic> products) async {
    final cartDoc = FirebaseFirestore.instance
        .collection('customers')
        .doc(FirebaseAuth.instance.currentUser !.uid)
        .collection('cart')
        .doc('activeCart');

    final productRef = FirebaseFirestore.instance.collection('products').doc(product['id']);

    try {
      int index = products.indexWhere((p) => p['id'] == product['id']);
      if (index == -1) return;

      int quantityToRestore = product['quantity'] ?? 0;
      products.removeAt(index);
      await cartDoc.update({'products': products});
      await productRef.update({'quantity': FieldValue.increment(quantityToRestore)});

      _showCustomAlert(context, 'Product removed from cart.');
    } catch (error) {
      _showCustomAlert(context, 'Failed to remove product: $error');
    }
  }

  void _removeProductFromCart(BuildContext context, Map<String, dynamic> product, List<dynamic> products) async {
    final cartDoc = FirebaseFirestore.instance
        .collection('customers')
        .doc(FirebaseAuth.instance.currentUser !.uid)
        .collection('cart')
        .doc('activeCart');

    final productRef = FirebaseFirestore.instance.collection('products').doc(product['id']);

    try {
      int index = products.indexWhere((p) => p['id'] == product['id']);
      if (index == -1) return;

      if (product['quantity'] > 1) {
        products[index]['quantity'] -= 1;
        await cartDoc.update({'products': products});
        await productRef.update({'quantity': FieldValue.increment(1)});
      } else {
        await _removeProductCompletely(context, product, products);
      }
    } catch (error) {
      _showCustomAlert(context, 'Failed to remove product: $error');
    }
  }

  void _increaseProductQuantity(BuildContext context, Map<String, dynamic> product, List<dynamic> products) async {
    final String? productId = product['id'];
    if (productId == null || productId.isEmpty) return;

    final productDoc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
    final int availableStock = productDoc.data()?['quantity'] ?? 0;

    int currentQuantity = product['quantity'] ?? 0;

    if (currentQuantity >= availableStock) {
      _showOutOfStockAlert(context, product['name']);
      return;
    }

    product['quantity'] += 1;

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(FirebaseAuth.instance.currentUser !.uid)
        .collection('cart')
        .doc('activeCart')
        .update({'products': products});

    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .update({'quantity': FieldValue.increment(-1)});
  }

  void _showOutOfStockAlert(BuildContext context, String productName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: const [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text('Stock Alert', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$productName is out of stock!', textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Icon(Icons.remove_shopping_cart, color: Colors.red, size: 50),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact(); // Added for OK
                Navigator.pop(context);
              },
              child: const Text("OK", style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  void _showCustomAlert(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Notification'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact(); // Added for OK
                Navigator.pop(context);
              },
              child: const Text('OK', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }


  void _checkForBagsAndProceed(BuildContext context, List<dynamic> products, String sessionId) {
    final hasBags = products.any((product) => product['id'] == '581f78e5');

    if (!hasBags) {
      _showBagPrompt(context, products, sessionId);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderPage(
            cartId: 'activeCart',
            userId: FirebaseAuth.instance.currentUser !.uid,
            sessionId: sessionId,
          ),
        ),
      );
    }
  }

  void _showBagPrompt(BuildContext context, List<dynamic> products, String sessionId) {
    int? bagQuantity;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('Need a shopping bag?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How many shopping bags do you need?'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of bags',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onChanged: (value) {
                        if (RegExp(r'^[1-9]\d*$').hasMatch(value)) {
                          setState(() {
                            bagQuantity = int.parse(value);
                          });
                        } else {
                          setState(() {
                            bagQuantity = null;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact(); // Added for No Thanks
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderPage(
                          cartId: 'activeCart',
                          userId: FirebaseAuth.instance.currentUser!.uid,
                          sessionId: sessionId,
                        ),
                      ),
                    );
                  },
                  child: const Text('No, thanks', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: bagQuantity == null
                      ? null
                      : () async {
                    HapticFeedback.mediumImpact(); // Added for Add Bags
                    final bagStockData = await _checkBagStock();
                    int bagStock = bagStockData['quantity'];
                    String bagImageUrl = bagStockData['imageUrl'];

                    if (bagQuantity! > bagStock) {
                      _showOutOfStockAlert(context, 'Shopping Bags');
                    } else {
                      await _addBagsToCart(bagQuantity!, bagImageUrl);
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderPage(
                            cartId: 'activeCart',
                            userId: FirebaseAuth.instance.currentUser!.uid,
                            sessionId: sessionId,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Add Bags', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _checkBagStock() async {
    final bagDoc = await FirebaseFirestore.instance
        .collection('products')
        .doc('581f78e5')
        .get();

    return {
      'quantity': bagDoc.data()?['quantity'] ?? 0,
      'imageUrl': bagDoc.data()?['imageUrl'] ?? '',
    };
  }

  Future<void> _addBagsToCart(int quantity, String bagImageUrl) async {
    final cartDoc = FirebaseFirestore.instance
        .collection('customers')
        .doc(FirebaseAuth.instance.currentUser !.uid)
        .collection('cart')
        .doc('activeCart');

    final cartSnapshot = await cartDoc.get();
    List<dynamic> products = cartSnapshot.data()?['products'] ?? [];

    final existingBag = products.firstWhere(
          (product) => product[' id'] == '581f78e5',
      orElse: () => null,
    );

    if (existingBag != null) {
      existingBag['quantity'] += quantity;
    } else {
      products.add({
        'id': '581f78e5',
        'name': 'Shopping Bag',
        'price': 0.10,
        'imageUrl': bagImageUrl,
        'quantity': quantity,
      });
    }

    await FirebaseFirestore.instance
        .collection('products')
        .doc('581f78e5')
        .update({
      'quantity': FieldValue.increment(-quantity),
    });

    await cartDoc.set({
      'products': products,
      'lastAddedTimestamp': FieldValue.serverTimestamp(),
    });
  }
}