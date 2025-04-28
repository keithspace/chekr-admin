import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpBubble extends StatefulWidget {
  final int currentPageIndex;
  final GlobalKey helpButtonKey;

  const HelpBubble({
    required this.currentPageIndex,
    required this.helpButtonKey,
    Key? key,
  }) : super(key: key);

  @override
  _HelpBubbleState createState() => _HelpBubbleState();
}

class _HelpBubbleState extends State<HelpBubble> {
  bool _showHelp = false;

  final List<Map<String, String>> _helpContent = [
    {
      'title': 'Dashboard Help',
      'content': '''
The Dashboard provides an overview of store operations:
- View key metrics: Today's visits, registered users, active carts, and sales
- Check weekly sales trends in the line chart
- See payment method distribution
- Monitor user satisfaction
- Get alerts for low stock products
- View new customer inquiries
'''
    },
    {
      'title': 'Customers Management Help',
      'content': '''
To manage customers:
1. Search for a customer using the search bar
2. Click on a customer tile to view details
3. For active carts:
   - Increase/Decrease product quantity using +/- buttons
   - Remove products using the bin icon
4. View transaction history by clicking on Transaction IDs
'''
    },
    {
      'title': 'Products List Help',
      'content': '''
To manage products:
1. Browse products in grid view or use search
2. Click the eye icon on a product card to expand details
3. Update product information:
   - Edit name, price, quantity, category
   - Upload new product image
4. Download barcode by clicking "Download Barcode"
5. Delete products using the trash icon
'''
    },
    {
      'title': 'Add Product Help',
      'content': '''
To add a new product:
1. Fill in all required fields:
   - Product Name
   - Price
   - Initial Quantity
   - Category and Subcategory
2. Upload a product image
3. Click "Upload Product" to save
4. The system will automatically generate a barcode

Tips:
- Use clear, high-quality product images
- Double-check pricing before saving
- Set reasonable initial quantities
'''
    },
    {
      'title': 'Reports Help',
      'content': '''
Generating Reports:

Sales Reports:
1. Navigate to "Sales Reports"
2. Select date range
3. Apply filters (Payment Method, Search)
4. Click "Generate Report"
5. Download as PDF or export to CSV

Product Reports:
1. Navigate to "Products Reports"
2. View stock levels and popular items
3. Generate out-of-stock alerts
4. Apply filters (Date Range, By Product)
5. Download report

Customer Reports:
1. Navigate to "Customer Reports"
2. Select date range
3. Apply filters (active/inactive)
4. Generate and download report
'''
    },
    {
      'title': 'Profile Help',
      'content': '''
Profile Management:
- View your admin profile details
- Update your personal information
- Change your password
- View your activity log
- Check your assigned role and permissions

Security Tips:
- Use a strong, unique password
- Never share your login credentials
- Log out when not using the admin panel
- Contact the main administrator for role changes
'''
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Stack(
      children: [
        if (_showHelp) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showHelp = false),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),

          Positioned(
            right: isMobile ? 16 : 80,
            top: 80,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: isMobile ? screenWidth * 0.9 : 400,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _helpContent[widget.currentPageIndex]['title']!,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => setState(() => _showHelp = false),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _helpContent[widget.currentPageIndex]['content']!,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        Positioned(
          right: isMobile ? 16 : 80,
          top: 16,
          child: IconButton(
            key: widget.helpButtonKey,
            icon: Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {
              setState(() {
                _showHelp = !_showHelp;
              });
            },
          ),
        ),
      ],
    );
  }
}
