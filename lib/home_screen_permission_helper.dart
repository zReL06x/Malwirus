import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// Call this in initState or on first app launch to request notification permission automatically
Future<void> requestNotificationPermissionIfNeeded(BuildContext context) async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    final result = await Permission.notification.request();
    if (result.isGranted) {
      // Optionally show a confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permission granted'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    }
  }
}
