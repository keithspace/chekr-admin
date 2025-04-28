import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:web_project/panel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_project/reg.dart';

Future<String> uploadImageToSupabase(XFile imageFile) async {
  final client = SupabaseClient(
    'https://wlbdvdbnecfwmxxftqrk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsYmR2ZGJuZWNmd214eGZ0cXJrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczODc0NzI0NywiZXhwIjoyMDU0MzIzMjQ3fQ.29nyle2IpA5tyAn6NY0K77ZhScC_ErOvtKCzKBu95Io',
  );

  final imageBytes = await imageFile.readAsBytes();
  final fileName = '${Uuid().v4()}.jpg';

  try {
    await client.storage.from('productimages').uploadBinary(
        'public/$fileName', imageBytes,
        fileOptions: const FileOptions(upsert: true));
    final publicUrl =
    client.storage.from('productimages').getPublicUrl('public/$fileName');
    return publicUrl;
  } catch (e) {
    throw Exception('Image upload failed: $e');
  }
}

class AddProductPage extends StatefulWidget {
  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String? _selectedCategory;
  String? _selectedSubcategory;
  File? _selectedImage;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  Timer? _inactivityTimer;

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
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    _resetInactivityTimer();
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImage = File(pickedFile.path);
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _uploadProduct() async {
    _resetInactivityTimer();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final xFile = XFile(_selectedImage!.path);
      final imageUrl = await uploadImageToSupabase(xFile);
      final firestore = FirebaseFirestore.instance;
      final productId = Uuid().v4().substring(0, 8);

      await firestore.collection('products').doc(productId).set({
        'id': productId,
        'name': _nameController.text,
        'price': double.parse(_priceController.text), // Directly parse the value
        'quantity': int.parse(_quantityController.text),
        'imageUrl': imageUrl,
        'category': _selectedCategory,
        'subcategory': _selectedSubcategory,
        'status': 'available',
        'timeAdded': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully')),
      );

      _nameController.clear();
      _priceController.clear();
      _quantityController.clear();
      setState(() {
        _selectedImage = null;
        _imageBytes = null;
        _selectedCategory = null;
        _selectedSubcategory = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload product: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      child: Scaffold(
      appBar: AppBar(
      title: Text(
      'Add Products',
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
        backgroundColor: const Color(0xFF1D1E33),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              color: const Color(0xFF0A0E21),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                width: MediaQuery.of(context).size.width * 0.8,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Product',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  onTap: _resetInactivityTimer,
                                  style: GoogleFonts.poppins(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Product Name',
                                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.white),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[800],
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a product name';
                                    }
                                    if (value.length < 5) {
                                      return 'Name must be at least 5 characters';
                                    }
                                    if (RegExp(r'^[0-9]+$').hasMatch(value)) {
                                      return 'Name cannot be purely numeric';
                                    }
                                    if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(value)) {
                                      return 'Name can only contain letters and numbers';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _priceController,
                                  onTap: _resetInactivityTimer,
                                  style: GoogleFonts.poppins(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Price',
                                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                                    hintText: 'e.g. 500',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.white),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[800],
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a price';
                                    }
                                    if (!RegExp(r'^\d+$').hasMatch(value)) {
                                      return 'Price must be a valid number';
                                    }
                                    if (double.parse(value) <= 0) {
                                      return 'Price must be greater than 0';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _quantityController,
                                  onTap: _resetInactivityTimer,
                                  style: GoogleFonts.poppins(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Quantity',
                                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.white),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[800],
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a quantity';
                                    }
                                    if (!RegExp(r'^\d+$').hasMatch(value)) {
                                      return 'Quantity must be a valid number';
                                    }
                                    if (int.parse(value) < 1) {
                                      return 'Quantity must be 1 or more';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  onTap: _resetInactivityTimer,
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
                                    });
                                    _resetInactivityTimer();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.white),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[800],
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                  validator: (value) =>
                                  value == null ? 'Please select a category' : null,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedSubcategory,
                                  onTap: _resetInactivityTimer,
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
                                    _resetInactivityTimer();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Subcategory',
                                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.white),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[800],
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                  validator: (value) =>
                                  value == null ? 'Please select a subcategory' : null,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: _imageBytes != null
                                      ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                      : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'No Image',
                                          style: GoogleFonts.poppins(color: Colors.grey),
                                        ),
                                        Text(
                                          'JPG, JPEG, PNG, WEBP',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          'Supported',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _pickImage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0A0E21),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'Pick Image',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _uploadProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008000),
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isUploading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                            'Upload Product',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}