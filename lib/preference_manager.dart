import 'package:shared_preferences/shared_preferences.dart';

class PreferenceManager {
  static const String _showSecurityScanMessageKey = 'show_security_scan_message';
  static const String _deviceSecurityVisitCountKey = 'device_security_visit_count';
  static const String _permissionStatePrefix = 'permission_';
  
  // Singleton instance
  static final PreferenceManager _instance = PreferenceManager._internal();
  
  factory PreferenceManager() {
    return _instance;
  }
  
  PreferenceManager._internal();
  
  // Get whether to show the security scan message
  Future<bool> getShowSecurityScanMessage() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true if not set
    return prefs.getBool(_showSecurityScanMessageKey) ?? true;
  }
  
  // Set whether to show the security scan message
  Future<void> setShowSecurityScanMessage(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSecurityScanMessageKey, show);
  }
  
  // Get the number of times the Device Security screen has been visited
  Future<int> getDeviceSecurityVisitCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_deviceSecurityVisitCountKey) ?? 0;
  }
  
  // Increment and get the Device Security screen visit count
  Future<int> incrementDeviceSecurityVisitCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_deviceSecurityVisitCountKey) ?? 0;
    final newCount = currentCount + 1;
    await prefs.setInt(_deviceSecurityVisitCountKey, newCount);
    return newCount;
  }
  
  // Clear all preferences
  Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  // Get permission state
  Future<bool> getPermissionState(String permissionName) async {
    final prefs = await SharedPreferences.getInstance();
    // Default to false if not set
    return prefs.getBool('$_permissionStatePrefix$permissionName') ?? false;
  }
  
  // Set permission state
  Future<void> setPermissionState(String permissionName, bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_permissionStatePrefix$permissionName', isEnabled);
  }
}
