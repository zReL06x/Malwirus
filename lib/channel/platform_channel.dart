import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../style/ui/custom_dialog.dart';
import '../strings.dart';

class PlatformChannel {
  static const MethodChannel _channel = MethodChannel('malwirus/platform');
  static bool _initialized = false;
  static bool _dartDebugLogsEnabled = false; // session-scoped for Flutter logs
  static bool _debugModeEnabled = false; // session-scoped Debug Mode (UI)

  // -----------------------------
  // Talsec device security bridge
  // -----------------------------
  static final StreamController<List<String>> _talsecThreatsController =
      StreamController<List<String>>.broadcast();

  static Stream<List<String>> get talsecThreatsStream =>
      _talsecThreatsController.stream;

  static void _ensureInitialized() {
    if (_initialized) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'talsecThreatsChanged':
          try {
            final List<dynamic> list =
                call.arguments is List ? call.arguments : const [];
            _talsecThreatsController.add(
              list.map((e) => e.toString()).toList(),
            );
          } catch (_) {}
          break;
        default:
          // No-op for unknown callbacks
          break;
      }
      return null;
    });
    _initialized = true;
  }

  // --- Debug logs (session-scoped) ---
  static Future<bool> setDebugLogsEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setDebugLogsEnabled', {
        'enabled': enabled,
      });
      _dartDebugLogsEnabled = enabled; // keep Flutter side in sync
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> getDebugLogsEnabled() async {
    try {
      final res = await _channel.invokeMethod('getDebugLogsEnabled');
      final on = res == true;
      _dartDebugLogsEnabled = on;
      return on;
    } catch (_) {
      return false;
    }
  }

  // --- Flutter-side gated logger ---
  static void setDartDebugLogsEnabled(bool enabled) {
    _dartDebugLogsEnabled = enabled;
  }

  static void dLog(String message) {
    if (_dartDebugLogsEnabled) {
      debugPrint(message);
    }
  }

  // --- Debug Mode (Flutter-only, session scoped) ---
  static void setDebugModeEnabled(bool enabled) {
    _debugModeEnabled = enabled;
  }

  static bool getDebugModeEnabled() {
    return _debugModeEnabled;
  }

  // --- SMS Simulation ---
  static Future<bool> simulateSms({required String sender, required String body}) async {
    try {
      await _channel.invokeMethod('simulateSms', {
        'sender': sender,
        'body': body,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Start observing device security threats from native and emit current snapshot immediately.
  static Future<bool> talsecObserveThreats() async {
    try {
      _ensureInitialized();
      final res = await _channel.invokeMethod('talsecObserveThreats');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> talsecGetThreats() async {
    try {
      final List<dynamic> list = await _channel.invokeMethod(
        'talsecGetThreats',
      );
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<bool> talsecClearThreat(String threat) async {
    try {
      final ok = await _channel.invokeMethod('talsecClearThreat', {
        'threat': threat,
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> talsecClearAllThreats() async {
    try {
      final ok = await _channel.invokeMethod('talsecClearAllThreats');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> talsecRescan() async {
    try {
      final ok = await _channel.invokeMethod('talsecRescan');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> talsecGetSuspiciousPackages() async {
    try {
      final List<dynamic> list = await _channel.invokeMethod(
        'talsecGetSuspiciousPackages',
      );
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<bool> talsecClearSuspiciousPackage(String packageName) async {
    try {
      final ok = await _channel.invokeMethod('talsecClearSuspiciousPackage', {
        'packageName': packageName,
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> talsecClearAllSuspiciousPackages() async {
    try {
      final ok = await _channel.invokeMethod(
        'talsecClearAllSuspiciousPackages',
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> talsecSetAllowedInstallerPackages(
    List<String> stores,
  ) async {
    try {
      final ok = await _channel.invokeMethod(
        'talsecSetAllowedInstallerPackages',
        {'stores': stores},
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> talsecSetScreenCaptureBlocked(bool enable) async {
    try {
      final ok = await _channel.invokeMethod('talsecSetScreenCaptureBlocked', {
        'enable': enable,
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Opens an Android settings page based on the intent action string.
  static Future<void> openAndroidSettings(String intentAction) async {
    try {
      await _channel.invokeMethod('openAndroidSettings', {
        'intentAction': intentAction,
      });
    } catch (e) {
      // Handle error (optional: log or show a snackbar)
    }
  }

  // --- Pre-listed (Bloom) filter controls ---
  static Future<bool> vpnSetPrelistedEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('vpnSetPrelistedEnabled', {
        'enabled': enabled,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, int>> vpnGetPrelistedInfo() async {
    try {
      final Map<dynamic, dynamic> res = await _channel.invokeMethod(
        'vpnGetPrelistedInfo',
      );
      final enabled = (res['enabled'] == true) ? 1 : 0;
      final count = (res['count'] as num?)?.toInt() ?? 0;
      return {'enabled': enabled, 'count': count};
    } catch (_) {
      return {'enabled': 1, 'count': 0};
    }
  }

  static Future<void> openAppInfo(
    String packageName, {
    required BuildContext context,
  }) async {
    try {
      await _channel.invokeMethod('openAppInfo', {'packageName': packageName});
    } catch (e) {
      try {
        showAppToast(context, AppStrings.failedOpenAppInfo);
      } catch (_) {}
    }
  }

  static Future<int> getMessagesScanned() async {
    try {
      final int count = await _channel.invokeMethod('getMessagesScanned');
      return count;
    } catch (e) {
      return 0; // Default to 0 on error
    }
  }

  static Future<int> getSuspiciousLinksFound() async {
    try {
      final int count = await _channel.invokeMethod('getSuspiciousLinksFound');
      return count;
    } catch (e) {
      return 0; // Default to 0 on error
    }
  }

  static Future<void> setLinkScanningEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setLinkScanningEnabled', {
        'enabled': enabled,
      });
    } catch (e) {
      // Handle error
    }
  }

  static Future<void> setSmsScanningEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setSmsScanningEnabled', {
        'enabled': enabled,
      });
    } catch (e) {
      // Handle error
    }
  }

  static Future<List<String>> getWhitelist() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getWhitelist');
      return result.cast<String>();
    } catch (e) {
      return <String>[];
    }
  }

  static Future<bool> addToWhitelist(String number) async {
    try {
      final bool result = await _channel.invokeMethod('addToWhitelist', {
        'number': number,
      });
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeFromWhitelist(String number) async {
    try {
      final bool result = await _channel.invokeMethod('removeFromWhitelist', {
        'number': number,
      });
      return result;
    } catch (e) {
      return false;
    }
  }

  // --- Blocklist (Calls) ---
  static Future<List<String>> getBlocklist() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getBlocklist');
      return result.cast<String>();
    } catch (e) {
      return <String>[];
    }
  }

  static Future<bool> addToBlocklist(String number) async {
    try {
      final bool result = await _channel.invokeMethod('addToBlocklist', {
        'number': number,
      });
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeFromBlocklist(String number) async {
    try {
      final bool result = await _channel.invokeMethod('removeFromBlocklist', {
        'number': number,
      });
      return result;
    } catch (e) {
      return false;
    }
  }

  // --- SMS Auto-block Spam Senders preference ---
  static Future<bool> getAutoBlockSpamSendersEnabled() async {
    try {
      final res = await _channel.invokeMethod('getAutoBlockSpamSendersEnabled');
      return res == true;
    } catch (_) {
      return true; // default enabled
    }
  }

  static Future<bool> setAutoBlockSpamSendersEnabled(bool enabled) async {
    try {
      final res = await _channel.invokeMethod('setAutoBlockSpamSendersEnabled', {
        'enabled': enabled,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  // Reasons map for blocklist entries (e.g., auto-added spam)
  static Future<Map<String, String>> getBlocklistReasons() async {
    try {
      final Map<dynamic, dynamic> res =
          await _channel.invokeMethod('getBlocklistReasons');
      return res.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  // --- Web Security VPN ---
  static Future<bool> vpnPrepare() async {
    try {
      final result = await _channel.invokeMethod('vpnPrepare');
      return (result == true);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> vpnStart() async {
    try {
      await _channel.invokeMethod('vpnStart');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> vpnStop() async {
    try {
      await _channel.invokeMethod('vpnStop');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> vpnIsActive() async {
    try {
      final res = await _channel.invokeMethod('vpnIsActive');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> vpnSetBlockedPackages(List<String> packages) async {
    try {
      await _channel.invokeMethod('vpnSetBlockedPackages', {
        'packages': packages,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> vpnSetDnsBlocklist(List<String> domains) async {
    try {
      await _channel.invokeMethod('vpnSetDnsBlocklist', {'domains': domains});
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, int>> vpnGetCounters() async {
    try {
      final Map<dynamic, dynamic> res = await _channel.invokeMethod(
        'vpnGetCounters',
      );
      return res.map(
        (key, value) => MapEntry(key as String, (value as num).toInt()),
      );
    } catch (_) {
      return {'bytesIn': 0, 'bytesOut': 0, 'dnsQueries': 0, 'dnsBlocked': 0};
    }
  }

  static Future<bool> vpnResetCounters() async {
    try {
      final ok = await _channel.invokeMethod('vpnResetCounters');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> vpnResetDnsCounters() async {
    try {
      final ok = await _channel.invokeMethod('vpnResetDnsCounters');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  // --- Universal DNS filtering ---
  static Future<bool> vpnSetUniversalDnsEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('vpnSetUniversalDnsEnabled', {
        'enabled': enabled,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> vpnGetUniversalDnsEnabled() async {
    try {
      final res = await _channel.invokeMethod('vpnGetUniversalDnsEnabled');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, String>>> getInstalledApps({
    String? type,
  }) async {
    try {
      final result = await _channel.invokeMethod('getInstalledApps', {
        if (type != null) 'type': type,
      });
      if (result is List) {
        return result.cast<Map<Object?, Object?>>().map((app) {
          return {
            'packageName': app['packageName']?.toString() ?? '',
            'appName': app['appName']?.toString() ?? '',
            'appType': app['appType']?.toString() ?? 'user',
          };
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // --- Persistent Monitoring Notification (Foreground Service) ---
  static Future<bool> monitoringStart() async {
    try {
      final res = await _channel.invokeMethod('monitoringStart');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> monitoringStop() async {
    try {
      final res = await _channel.invokeMethod('monitoringStop');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> monitoringIsActive() async {
    try {
      final res = await _channel.invokeMethod('monitoringIsActive');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  // --- App installer/source checks ---
  /// Returns true if this app was installed from Google Play (com.android.vending).
  static Future<bool> isInstalledFromPlayStore() async {
    try {
      final res = await _channel.invokeMethod('isInstalledFromPlayStore');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the current app package name on Android. On other platforms returns an empty string.
  static Future<String> getPackageName() async {
    try {
      final String pkg = await _channel.invokeMethod('getPackageName');
      return pkg;
    } catch (_) {
      return '';
    }
  }

  /// Returns true if the specified package was installed from Google Play Store.
  static Future<bool> isPackageFromPlayStore(String packageName) async {
    try {
      final res = await _channel.invokeMethod('isPackageFromPlayStore', {
        'packageName': packageName,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// Performs a full native cold restart using AlarmManager.
  /// Returns true if the relaunch was scheduled.
  static Future<bool> hardRestartApp() async {
    try {
      final res = await _channel.invokeMethod('hardRestartApp');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// Kills the app process without scheduling a relaunch.
  /// Used when you want the user to manually relaunch via the launcher icon
  /// to allow a clean cold start (e.g., to force Talsec to re-scan).
  static Future<bool> killAppNoRelaunch() async {
    try {
      final res = await _channel.invokeMethod('killAppNoRelaunch');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  // --- Installer-capable apps + trusted installers ---
  static Future<List<Map<String, dynamic>>> getInstallerCapableApps() async {
    try {
      final result = await _channel.invokeMethod('getInstallerCapableApps');
      if (result is List) {
        return result
            .cast<Map<Object?, Object?>>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> getTrustedInstallers() async {
    try {
      final List<dynamic> list = await _channel.invokeMethod(
        'getTrustedInstallers',
      );
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<bool> addTrustedInstaller(String packageName) async {
    try {
      final res = await _channel.invokeMethod('addTrustedInstaller', {
        'packageName': packageName,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> removeTrustedInstaller(String packageName) async {
    try {
      final res = await _channel.invokeMethod('removeTrustedInstaller', {
        'packageName': packageName,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getInstallerPackage(String packageName) async {
    try {
      final res = await _channel.invokeMethod('getInstallerPackage', {
        'packageName': packageName,
      });
      if (res == null) return null;
      return res.toString();
    } catch (_) {
      return null;
    }
  }

  /// Returns user-installed apps that are NOT installed via Google Play Store.
  static Future<List<Map<String, String>>> getNonPlayUserInstalledApps() async {
    try {
      final result = await _channel.invokeMethod('getNonPlayUserInstalledApps');
      if (result is List) {
        return result.cast<Map<Object?, Object?>>().map((app) => {
              'packageName': app['packageName']?.toString() ?? '',
              'appName': app['appName']?.toString() ?? '',
            }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
