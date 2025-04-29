import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// A reusable tile for toggling the persistent notification in settings.
class NotificationSettingsTile extends StatefulWidget {
  const NotificationSettingsTile({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsTile> createState() => _NotificationSettingsTileState();
}

class _NotificationSettingsTileState extends State<NotificationSettingsTile> {
  static const MethodChannel _channel = MethodChannel('com.zrelxr06.malwirus/notification');
  bool _persistentNotificationEnabled = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _persistentNotificationEnabled = prefs.getBool('persistent_notification_enabled') ?? false;
    });
  }

  Future<void> _togglePersistentNotification(bool value) async {
    setState(() { _loading = true; });
    final prefs = await SharedPreferences.getInstance();
    try {
      if (value) {
        await _channel.invokeMethod('enableMonitoringNotification');
      } else {
        await _channel.invokeMethod('disableMonitoringNotification');
      }
      await prefs.setBool('persistent_notification_enabled', value);
      setState(() { _persistentNotificationEnabled = value; });
    } catch (e) {
      // Optionally show error
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      title: const Text('Persistent Notification'),
      subtitle: const Text('Show ongoing security monitoring notification'),
      trailing: _loading
          ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34C759)))
          : Switch(
              value: _persistentNotificationEnabled,
              onChanged: _togglePersistentNotification,
              activeColor: const Color(0xFF34C759),
            ),
      tileColor: Colors.transparent,
      shape: null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
    );
  }
}
