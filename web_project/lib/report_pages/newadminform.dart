import 'package:flutter/material.dart';

class _CreateAdminForm extends StatelessWidget {
  final Function(String, String, String, String, String) onCreateAdmin;

  _CreateAdminForm({required this.onCreateAdmin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Admin Form Placeholder'),
        ElevatedButton(
          onPressed: () {
            onCreateAdmin('email', 'password', 'name', 'phone', 'task');
          },
          child: Text('Create Admin'),
        ),
      ],
    );
  }
}
