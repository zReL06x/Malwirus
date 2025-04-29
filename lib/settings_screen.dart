import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'preference_manager.dart';
import 'dart:async';

// Lifecycle observer to detect when app resumes
class LifecycleEventHandler extends WidgetsBindingObserver {
  final Future<void> Function() resumeCallBack;

  LifecycleEventHandler({required this.resumeCallBack});

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await resumeCallBack();
    }
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // App Permissions
  final PreferenceManager _preferenceManager = PreferenceManager();
  bool _smsPermissionEnabled = false;
  bool _notificationPermissionEnabled = false;

  // Notification Settings
  static const MethodChannel _notificationChannel = MethodChannel('com.zrelxr06.malwirus/notification');
  bool _persistentNotificationEnabled = false;

  // Expansion state
  bool _appPermissionsExpanded = false;
  bool _notificationSettingsExpanded = false;
  bool _aboutExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncPermissionsFromSystem();
    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(resumeCallBack: () async {
        await _syncPermissionsFromSystem();
      })
    );
  }

  Future<void> _syncPermissionsFromSystem() async {
    // Check actual permission states
    final smsStatus = await Permission.sms.status;
    final notifStatus = await Permission.notification.status;
    final smsGranted = smsStatus.isGranted;
    final notifGranted = notifStatus.isGranted;
    
    // Sync permissions with preferences
    await _preferenceManager.setPermissionState('sms_permission', smsGranted);
    await _preferenceManager.setPermissionState('notification_permission', notifGranted);
    
    // Load persistent notification preference
    final prefs = await SharedPreferences.getInstance();
    bool persistentNotifPref = prefs.getBool('persistent_notification_enabled') ?? false;
    
    // Check if notification is actually active (overrides preference)
    try {
      final isActive = await _notificationChannel.invokeMethod<bool>('isMonitoringNotificationActive') ?? false;
      
      // If notification is active but preference says it's not, sync them
      if (isActive != persistentNotifPref) {
        await prefs.setBool('persistent_notification_enabled', isActive);
        persistentNotifPref = isActive;
      }
    } catch (e) {
      // If error checking notification state, fall back to stored preference
      debugPrint('Error checking notification state: $e');
    }
    
    setState(() {
      _smsPermissionEnabled = smsGranted;
      _notificationPermissionEnabled = notifGranted;
      _persistentNotificationEnabled = persistentNotifPref;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      LifecycleEventHandler(resumeCallBack: () async {})
    );
    super.dispose();
  }

  Future<void> _toggleSmsPermission(bool value) async {
    if (value) {
      final status = await Permission.sms.request();
      final isGranted = status.isGranted;
      await _preferenceManager.setPermissionState('sms_permission', isGranted);
      setState(() { _smsPermissionEnabled = isGranted; });
      if (!isGranted) {
        _showPermissionDeniedDialog('SMS');
      }
    } else {
      await _preferenceManager.setPermissionState('sms_permission', false);
      setState(() { _smsPermissionEnabled = false; });
      AppSettings.openAppSettings();
      // After returning from settings, check permission again
      final status = await Permission.sms.status;
      final isGranted = status.isGranted;
      await _preferenceManager.setPermissionState('sms_permission', isGranted);
      setState(() { _smsPermissionEnabled = isGranted; });
    }
  }

  Future<void> _toggleNotificationPermission(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      final isGranted = status.isGranted;
      await _preferenceManager.setPermissionState('notification_permission', isGranted);
      setState(() { _notificationPermissionEnabled = isGranted; });
      if (!isGranted) {
        _showPermissionDeniedDialog('Notification');
      }
    } else {
      await _preferenceManager.setPermissionState('notification_permission', false);
      setState(() { _notificationPermissionEnabled = false; });
      AppSettings.openAppSettings();
      // After returning from settings, check permission again
      final status = await Permission.notification.status;
      final isGranted = status.isGranted;
      await _preferenceManager.setPermissionState('notification_permission', isGranted);
      setState(() { _notificationPermissionEnabled = isGranted; });
    }
  }

  void _showPermissionDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text('This feature requires $permissionName permission. Please enable it in app settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePersistentNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (value) {
        // Enable notification
        await _notificationChannel.invokeMethod('enableMonitoringNotification');
        
        // Verify notification is actually active after enabling
        final isActive = await _notificationChannel.invokeMethod<bool>('isMonitoringNotificationActive') ?? false;
        await prefs.setBool('persistent_notification_enabled', isActive);
        setState(() { _persistentNotificationEnabled = isActive; });
      } else {
        // Disable notification
        await _notificationChannel.invokeMethod('disableMonitoringNotification');
        
        // Verify notification is actually disabled after disabling
        final isActive = await _notificationChannel.invokeMethod<bool>('isMonitoringNotificationActive') ?? false;
        await prefs.setBool('persistent_notification_enabled', isActive);
        setState(() { _persistentNotificationEnabled = isActive; });
      }
    } catch (e) {
      debugPrint('Error toggling notification: $e');
      // Check actual state to recover from errors
      try {
        final isActive = await _notificationChannel.invokeMethod<bool>('isMonitoringNotificationActive') ?? false;
        await prefs.setBool('persistent_notification_enabled', isActive);
        setState(() { _persistentNotificationEnabled = isActive; });
      } catch (e) {
        debugPrint('Error checking notification state: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // App Permissions Section
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              key: PageStorageKey('app_permissions_tile'),
              onExpansionChanged: (expanded) {
                setState(() { _appPermissionsExpanded = expanded; });
              },
              title: const Text(
                'App Permissions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(
                Icons.security,
                color: Color(0xFF34C759),
              ),
              childrenPadding: EdgeInsets.zero,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                ListTile(
                  title: const Text('SMS Access'),
                  subtitle: const Text('Required for SMS security scanning'),
                  trailing: Switch(
                    value: _smsPermissionEnabled,
                    onChanged: _toggleSmsPermission,
                    activeColor: const Color(0xFF34C759),
                  ),
                ),
                ListTile(
                  title: const Text('Notification Access'),
                  subtitle: const Text('Required for security alerts'),
                  trailing: Switch(
                    value: _notificationPermissionEnabled,
                    onChanged: _toggleNotificationPermission,
                    activeColor: const Color(0xFF34C759),
                  ),
                ),
                ListTile(
                  title: const Text('Internet Access'),
                  subtitle: const Text('Required for security updates'),
                  trailing: const Icon(Icons.check_circle, color: Color(0xFF34C759)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Notification Settings Section
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: _notificationSettingsExpanded,
              onExpansionChanged: (expanded) {
                setState(() { _notificationSettingsExpanded = expanded; });
              },
              title: const Text(
                'Notification Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF34C759),
              ),
              childrenPadding: EdgeInsets.zero,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                ListTile(
                  title: const Text('Persistent Notification'),
                  subtitle: const Text('Show ongoing security monitoring notification'),
                  trailing: Switch(
                    value: _persistentNotificationEnabled,
                    onChanged: _togglePersistentNotification,
                    activeColor: const Color(0xFF34C759),
                  ),
                ),
              ],
            ),
          ),

                 // About Section
                 Theme(
                   data: Theme.of(context).copyWith(
                     dividerColor: Colors.transparent,
                   ),
                   child: ExpansionTile(
                     initiallyExpanded: _aboutExpanded,
                     onExpansionChanged: (expanded) {
                       setState(() { _aboutExpanded = expanded; });
                     },
                     title: const Text(
                       'About',
                       style: TextStyle(fontWeight: FontWeight.bold),
                     ),
                     leading: const Icon(Icons.info_outline, color: Color(0xFF34C759)),
                     childrenPadding: EdgeInsets.zero,
                     tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                     children: [
                       ListTile(
                         title: const Text('Version'),
                         subtitle: const Text('1.0.0'),
                       ),
                       ListTile(
                         title: const Text('Privacy Policy'),
                         onTap: () {
                           showDialog(
                             context: context,
                             builder: (context) => AlertDialog(
                               title: const Text('Privacy Policy'),
                               content: const Text('We do not collect or store any personal data. Permissions are used only for device security.'),
                               actions: [
                                 TextButton(
                                   onPressed: () => Navigator.of(context).pop(),
                                   child: const Text('OK'),
                                 ),
                               ],
                             ),
                           );
                         },
                       ),
                     ],
                   ),
                 ),
               ],
             ),
    );
  }
}
