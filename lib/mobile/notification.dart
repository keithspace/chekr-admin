import 'package:flutter/material.dart';
import 'admin_response.dart';

class NotificationsPage extends StatelessWidget {
  final List<String> notifications;
  final List<AdminResponse> adminResponses;
  final Function(AdminResponse) onResponseOpened;

  const NotificationsPage({
    Key? key,
    required this.notifications,
    required this.adminResponses,
    required this.onResponseOpened,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: [
          // App Notifications section
          if (notifications.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'App Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ...notifications.map((notification) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.notifications, color: Colors.blue),
              title: Text(notification),
            ),
          )),

          // Admin Responses section
          if (adminResponses.isNotEmpty)
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
          ...adminResponses.map((response) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.green),
              title: Text(response.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(response.response),
                  const SizedBox(height: 4),
                  Text(
                    'Response from ${response.respondedBy}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              onTap: () {
                // Call the onResponseOpened callback when tapped
                onResponseOpened(response);
              },
            ),
          )),

          // No notifications placeholder
          if (notifications.isEmpty && adminResponses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No notifications available',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}