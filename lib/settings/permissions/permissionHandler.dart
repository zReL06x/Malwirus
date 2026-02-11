import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../channel/platform_channel.dart';

/// Handles permission checks and requests via platform channel (native Android).
class PermissionHandler {
  static const MethodChannel _channel = MethodChannel('malwirus/platform');

  // Observable permission states for reactive UI updates.
  static final ValueNotifier<bool?> notificationGranted = ValueNotifier<bool?>(null);
  static final ValueNotifier<bool?> smsGranted = ValueNotifier<bool?>(null);
  static final ValueNotifier<bool?> phoneGranted = ValueNotifier<bool?>(null);

  /// Refreshes and publishes current permission states to notifiers.
  static Future<void> refreshPermissions() async {
    try {
      final notif = await isNotificationPermissionGranted();
      final sms = await isSmsPermissionGranted();
      final phone = await isPhonePermissionGranted();
      notificationGranted.value = notif;
      smsGranted.value = sms;
      phoneGranted.value = phone;
    } catch (_) {
      // On error, keep existing states; callers may retry.
    }
  }

  /// Checks if notification permission is granted (Android 13+).
  static Future<bool> isNotificationPermissionGranted() async {
    try {
      final bool granted = await _channel.invokeMethod('isNotificationPermissionGranted');
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Requests notification permission (Android 13+).
  static Future<bool> requestNotificationPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('requestNotificationPermission');
      // Notify listeners immediately
      notificationGranted.value = granted;
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Checks if SMS permission is granted.
  static Future<bool> isSmsPermissionGranted() async {
    try {
      final bool granted = await _channel.invokeMethod('isSmsPermissionGranted');
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Requests SMS permission.
  static Future<bool> requestSmsPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('requestSmsPermission');
      // Notify listeners immediately
      smsGranted.value = granted;
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Checks if phone/call permissions are granted.
  static Future<bool> isPhonePermissionGranted() async {
    try {
      final bool granted = await _channel.invokeMethod('isPhonePermissionGranted');
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Requests phone/call permissions (READ_PHONE_STATE, READ_PHONE_NUMBERS, READ_CALL_LOG).
  static Future<bool> requestPhonePermission() async {
    try {
      final bool granted = await _channel.invokeMethod('requestPhonePermission');
      // Notify listeners immediately
      phoneGranted.value = granted;
      return granted;
    } catch (e) {
      return false;
    }
  }
}
