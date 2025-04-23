import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'admin_response.dart';

class HelpCenterPage extends StatefulWidget {
  final int initialTab;
  final bool showAdminResponses;

  const HelpCenterPage({
    Key? key,
    this.initialTab = 0,
    this.showAdminResponses = false,
  }) : super(key: key);

  @override
  _HelpCenterPageState createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AdminResponse> _adminResponses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _fetchAdminResponses();

    if (widget.showAdminResponses) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(1);
      });
    }
  }

  Future<void> _fetchAdminResponses() async {
    final userId = firebase.FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('feedback')
          .where('userId', isEqualTo: userId)
          .where('response', isNotEqualTo: null)
          .orderBy('responseTime', descending: true)
          .get();

      setState(() {
        _adminResponses = snapshot.docs.map((doc) {
          final data = doc.data();
          return AdminResponse(
            title: data['title'],
            description: data['description'] ?? 'No description',
            response: data['response'],
            timestamp: (data['responseTime'] as Timestamp).toDate(),
            respondedBy: data['respondedBy'] ?? 'Admin',
            isNew: data['isNew'] ?? false,
          );
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Help Center'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'FAQ'),
            Tab(text: 'Support'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFAQSection(),
          _buildSupportSection(),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    return ListView(
      children: [
        ExpansionTile(
          title: const Text('Refunds', style: TextStyle(fontWeight: FontWeight.w500)),
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'The return policy is limited to within 48 business hours since purchase. The item(s) should be tagged and in good condition. Refunds are done in-store with the receipt.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('Warranty', style: TextStyle(fontWeight: FontWeight.w500)),
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Clothing items are not warranted. Some accessories, like Bags and Bracelets, have warranties where applicable.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('How do I change my phone number?', style: TextStyle(fontWeight: FontWeight.w500)),
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'You can change your contact number in the Account details on your Profile.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('How can I see my invoices?', style: TextStyle(fontWeight: FontWeight.w500)),
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'You can always see your past receipts and transactions on your profile under Activity.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('Why use Chekr?', style: TextStyle(fontWeight: FontWeight.w500)),
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Chekr allows you to quickly scan, pay, and go without standing in lengthy queues.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return ListView(
      children: [
        ListTile(
          title: Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold)),
          onTap: () => _showContactSupportBottomSheet(context), // ✅ Correct
        ),

        ListTile(
          title: Text('Lodge Complaint/Feedback/Inquiry', style: TextStyle(fontWeight: FontWeight.bold)),
          onTap: () => _showFeedbackForm(context), // ✅ Correct
        ),


        if (_adminResponses.isNotEmpty) ...[
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Admin Responses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._adminResponses.map((response) => Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text(response.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your message: ${response.description}'),
                  const SizedBox(height: 4),
                  Text('Response: ${response.response}'),
                  const SizedBox(height: 4),
                  Text(
                    '${response.timestamp.day}/${response.timestamp.month}/${response.timestamp.year} by ${response.respondedBy}',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              trailing: response.isNew
                  ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              )
                  : null,
            ),
          )),
        ],
      ],
    );
  }

  void _showContactSupportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Contact Support',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.email, color: Colors.green),
                title: const Text('chekr@mail.com'),
              ),
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: const Text('+123 456 7890'),
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.instagram, color: Colors.green),
                title: const Text('chekrapp'),
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.xTwitter, color: Colors.green),
                title: const Text('@shopwithchekrapp'),
              ),
            ],
          ),
        );
      },
    );
  }



  void _showFeedbackForm(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final _titleController = TextEditingController();
    final _descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'If you are experiencing any issue, please let us know. We will try to solve them as soon as possible.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Title',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter a title...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Explain the problem',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      hintText: 'Describe your issue...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    validator: (value) => value == null || value.isEmpty ? 'Please provide details' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final firebase.User? user = firebase.FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance.collection('feedback').add({
                                'userId': user.uid,
                                'feedbackId': DateTime.now().millisecondsSinceEpoch.toString(),
                                'title': _titleController.text,
                                'description': _descriptionController.text,
                                'timestamp': Timestamp.now(),
                              });

                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Feedback submitted successfully!'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 1),
                                ),
                              );

                              // Close the modal after submission
                              Navigator.pop(context);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Submit', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
