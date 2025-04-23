import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:html' as html; // For web implementation
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_project/panel.dart';
import 'package:web_project/reg.dart'; // Add this import
import 'generatebarcode.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart'; // For image editing

class ProductsGridPage extends StatefulWidget {
  @override
  _ProductsGridPageState createState() => _ProductsGridPageState();
}

class _ProductsGridPageState extends State<ProductsGridPage> {
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedSubcategory;
  Timer? _inactivityTimer;
  Map<String, dynamic>? _selectedProduct;

  final List<String> _categories = ['Men', 'Women', 'Kids', 'Unisex'];
  final List<String> _subcategories = [
    'Footwear',
    'Accessories',
    'Swimwear',
    'Sleepwear',
    'Formalwear',
    'Casual',
    'Underwear'
  ];

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    final firestore = FirebaseFirestore.instance;
    Query query = firestore.collection('products');

    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    if (_selectedSubcategory != null) {
      query = query.where('subcategory', isEqualTo: _selectedSubcategory);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': data['name'],
        'price': data['price'],
        'imageUrl': data['imageUrl'],
        'quantity': data['quantity'] ?? 0,
      };
    }).toList();
  }

  void _refreshProducts() {
    setState(() {});
  }

  void _showProductOverlay(Map<String, dynamic> product) {
    setState(() {
      _selectedProduct = product;
    });
  }

  void _hideProductOverlay() {
    setState(() {
      _selectedProduct = null;
    });
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

  void _navigateToAdminHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => AdminHomePage()),
    );
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1E33),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => AdminHomePage()),
            );
          },
        ),
        title: Text(
          'Products List',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search and Filter Row
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    child: Row(
                      children: [
                        // Search by name
                        Flexible(
                          flex: 1,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.6,
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.search, color: Colors.white),
                                labelText: 'Search by name',
                                labelStyle: GoogleFonts.poppins(color: Colors.white),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0A0E21),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                              ),
                              style: GoogleFonts.poppins(color: Colors.white),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        // Filter by category
                        Flexible(
                          flex: 1,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.4,
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(
                                    category,
                                    style: GoogleFonts.poppins(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                  _selectedSubcategory = null;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Category',
                                labelStyle: GoogleFonts.poppins(color: Colors.white),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0A0E21),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                              ),
                              dropdownColor: const Color(0xFF0A0E21),
                              icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        // Filter by subcategory
                        Flexible(
                          flex: 1,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.4,
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedSubcategory,
                              items: _subcategories.map((subcategory) {
                                return DropdownMenuItem(
                                  value: subcategory,
                                  child: Text(
                                    subcategory,
                                    style: GoogleFonts.poppins(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSubcategory = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Subcategory',
                                labelStyle: GoogleFonts.poppins(color: Colors.white),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0A0E21),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                              ),
                              dropdownColor: const Color(0xFF0A0E21),
                              icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Products Grid
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchProducts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          'No products available',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      );
                    }

                    final products = snapshot.data!
                        .where((product) =>
                        product['name'].toLowerCase().contains(
                            _searchQuery.toLowerCase()))
                        .toList();

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: _getChildAspectRatio(context),
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductCard(
                          productId: product['id'],
                          productName: product['name'],
                          productPrice: product['price'],
                          productImage: product['imageUrl'],
                          productQuantity: product['quantity'],
                          onTap: () => _showProductOverlay(product),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Product Overlay
          if (_selectedProduct != null)
            ProductOverlay(
              product: _selectedProduct!,
              onClose: _hideProductOverlay,
              onUpdate: _refreshProducts,
            ),
        ],
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
  }

  double _getChildAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 0.75;
    if (width > 800) return 0.8;
    return 0.85;
  }
}

class ProductOverlay extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onClose;
  final VoidCallback onUpdate;

  const ProductOverlay({
    required this.product,
    required this.onClose,
    required this.onUpdate,
  });

  @override
  _ProductOverlayState createState() => _ProductOverlayState();
}

class _ProductOverlayState extends State<ProductOverlay> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  String? _imageUrl;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product['name']);
    _priceController = TextEditingController(text: widget.product['price'].toString());
    _quantityController = TextEditingController(text: widget.product['quantity'].toString());
    _imageUrl = widget.product['imageUrl'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product['id'])
            .update({
          'name': _nameController.text,
          'price': double.parse(_priceController.text),
          'quantity': int.parse(_quantityController.text),
          'imageUrl': _imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product updated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );

        widget.onUpdate();
        setState(() {
          _isEditing = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating product: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // In a real app, you would upload this image to Firebase Storage
      // and get the download URL. For simplicity, we'll just use the local path
      setState(() {
        _imageUrl = pickedFile.path;
      });
    }
  }

  Future<void> _downloadBarcode() async {
    try {
      final GlobalKey barcodeKey = GlobalKey();

      // Build the widget to capture
      final barcodeWidget = RepaintBoundary(
        key: barcodeKey,
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BarcodeWidget(
                barcode: Barcode.code128(),
                data: widget.product['id'],
                width: 300,
                height: 100,
                color: Colors.black,
              ),
              SizedBox(height: 10),
              Text(
                _nameController.text,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'KES ${_priceController.text}',
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );

      // Show the widget in an overlay to ensure it's painted
      final overlayState = Overlay.of(context);
      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -10000, // Position off-screen
          child: Material(
            type: MaterialType.transparency,
            child: barcodeWidget,
          ),
        ),
      );

      overlayState.insert(overlayEntry);

      // Wait for the widget to be built and painted
      await Future.delayed(Duration(milliseconds: 100));

      // Generate the barcode image
      final boundary = barcodeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not find render boundary');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final imageBytes = byteData?.buffer.asUint8List();

      if (imageBytes != null) {
        // For web implementation (similar to your reference code)
        if (kIsWeb) {
          final blob = html.Blob([imageBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", 'barcode_${widget.product['id']}.png')
            ..click();
          html.Url.revokeObjectUrl(url);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Barcode downloaded successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // For mobile implementation
          final directory = await getTemporaryDirectory();
          final imagePath = '${directory.path}/barcode_${widget.product['id']}.png';
          final file = File(imagePath);
          await file.writeAsBytes(imageBytes);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Barcode saved to temporary directory'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Remove the overlay
      overlayEntry.remove();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save barcode: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark overlay
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Colors.black.withOpacity(0.7),
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // Centered product card
        Center(
          child: SingleChildScrollView(
            child: Container(
              width: 300,
              margin: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E21),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product Image with edit option
                    Stack(
                      children: [
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            image: DecorationImage(
                              image: _imageUrl!.startsWith('http')
                                  ? NetworkImage(_imageUrl!)
                                  : FileImage(File(_imageUrl!)) as ImageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: IconButton(
                              icon: Icon(Icons.edit, color: Colors.white),
                              onPressed: _pickImage,
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name
                          _isEditing
                              ? TextFormField(
                            controller: _nameController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Name',
                              labelStyle: GoogleFonts.poppins(color: Colors.white70),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a name';
                              }
                              return null;
                            },
                          )
                              : Text(
                            _nameController.text,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          // Product Price
                          _isEditing
                              ? TextFormField(
                            controller: _priceController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Price',
                              labelStyle: GoogleFonts.poppins(color: Colors.white70),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a price';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          )
                              : Text(
                            'KES ${_priceController.text}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          // Product Quantity
                          _isEditing
                              ? TextFormField(
                            controller: _quantityController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Quantity',
                              labelStyle: GoogleFonts.poppins(color: Colors.white70),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a quantity';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          )
                              : Text(
                            'Quantity: ${_quantityController.text}',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 16),
                          // Barcode
                          BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: widget.product['id'],
                            width: double.infinity,
                            height: 60,
                            color: Colors.white,
                            backgroundColor: Colors.transparent,
                          ),
                          SizedBox(height: 16),
                          // Action Buttons
                          if (_isEditing)
                            Column(
                              children: [
                                ElevatedButton(
                                  onPressed: _updateProduct,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    minimumSize: Size(double.infinity, 40),
                                  ),
                                  child: Text(
                                    'Save Changes',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                    });
                                  },
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                ElevatedButton(
                                  onPressed: _downloadBarcode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    minimumSize: Size(double.infinity, 40),
                                  ),
                                  child: Text(
                                    'Download Barcode',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = true;
                                    });
                                  },
                                  child: Text(
                                    'Edit Product',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}