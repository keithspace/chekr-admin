import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductCard extends StatelessWidget {
  final String productId;
  final String productName;
  final double productPrice;
  final String productImage;
  final int productQuantity;
  final VoidCallback onTap;

  const ProductCard({
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productImage,
    required this.productQuantity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: const Color(0xFF0A0E21),
        elevation: 5,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(productImage),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  // Product Name
                  Text(
                    productName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: constraints.maxWidth * 0.045,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  // Product Price
                  Text(
                    'KES ${productPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: constraints.maxWidth * 0.04,
                    ),
                  ),
                  SizedBox(height: 4),
                  // Product Quantity
                  Text(
                    'Qty: $productQuantity',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: constraints.maxWidth * 0.035,
                    ),
                  ),
                  SizedBox(height: 8),
                  // Barcode Icon
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.barcode_reader,
                      color: Colors.white70,
                      size: constraints.maxWidth * 0.06,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}