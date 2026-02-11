import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For whitelist persistence
import '../../style/ui/bottomsheet.dart';
import '../../strings.dart';
import '../../style/ui/custom_dialog.dart';
import '../../channel/platform_channel.dart';
import '../../style/icons.dart';

// Local data model replacing FreeRASP's SuspiciousAppInfo
class MaliciousAppInfo {
  final String packageName;
  final String reason;
  const MaliciousAppInfo({required this.packageName, required this.reason});
}

class MaliciousAppsBottomSheet extends StatelessWidget {
  final List<MaliciousAppInfo> detectedMalware;
  final VoidCallback? onWhitelistUpdated;

  const MaliciousAppsBottomSheet({Key? key, required this.detectedMalware, this.onWhitelistUpdated})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppBottomSheet(
      title: AppStrings.maliciousApps,
      icon: AppIcons.threat,
      sliverChildren: [
        _MaliciousAppsSliverList(
          detectedMalware: detectedMalware,
          isDarkMode: isDarkMode,
          onWhitelistUpdated: onWhitelistUpdated,
        ),
      ],
    );
  }
}

class _MaliciousAppsSliverList extends StatefulWidget {
  final List<MaliciousAppInfo> detectedMalware;
  final bool isDarkMode;
  final VoidCallback? onWhitelistUpdated;

  const _MaliciousAppsSliverList({
    Key? key,
    required this.detectedMalware,
    required this.isDarkMode,
    this.onWhitelistUpdated,
  }) : super(key: key);

  @override
  State<_MaliciousAppsSliverList> createState() =>
      _MaliciousAppsSliverListState();
}

class _MaliciousAppsSliverListState extends State<_MaliciousAppsSliverList>
    with WidgetsBindingObserver {
  // Cached whitelist for quick comparisons
  Set<String> _whitelist = {};
  // Trusted installer packages (e.g., com.android.vending)
  Set<String> _trustedInstallers = {};
  // Installer-capable apps discovered on device
  List<Map<String, dynamic>> _installerApps = [];

  // Utility method to add an app to the whitelist using SharedPreferences (JSON array)
  Future<void> _addToWhitelist(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = AppStrings.whitelistKey;
    final whitelistJson = prefs.getString(key);
    List<String> whitelist = [];
    if (whitelistJson != null) {
      try {
        whitelist = List<String>.from(json.decode(whitelistJson));
      } catch (_) {
        whitelist = [];
      }
    }
    if (!whitelist.contains(packageName)) {
      whitelist.add(packageName);
      await prefs.setString(key, json.encode(whitelist));
    }
    // Debug print to check the current whitelist JSON
    final debugJson = prefs.getString(key);
    PlatformChannel.dLog('[Whitelist Debug] Current whitelist JSON: ' + (debugJson ?? 'null'));
    // Update local cache and UI immediately so the change reflects to the user
    _whitelist = whitelist.toSet();
    if (mounted) {
      setState(() {
        _apps.removeWhere((a) => a.packageName == packageName);
      });
    }
  }

  // Loads whitelist from SharedPreferences and updates cache
  Future<void> _loadWhitelist() async {
    final prefs = await SharedPreferences.getInstance();
    final key = AppStrings.whitelistKey;
    final whitelistJson = prefs.getString(key);
    if (whitelistJson == null) {
      _whitelist = {};
      return;
    }
    try {
      _whitelist = List<String>.from(json.decode(whitelistJson)).toSet();
    } catch (_) {
      _whitelist = {};
    }
  }

  // Load trusted installer packages from native prefs
  Future<void> _loadTrustedInstallers() async {
    final list = await PlatformChannel.getTrustedInstallers();
    _trustedInstallers = list.toSet();
  }

  // Load installer-capable apps for UI chips
  Future<void> _loadInstallerApps() async {
    final list = await PlatformChannel.getInstallerCapableApps();
    if (!mounted) return;
    setState(() {
      _installerApps = list;
    });
  }

  // Load all user-installed apps that are NOT from Google Play Store
  Future<void> _loadNonPlayApps() async {
    try {
      final list = await PlatformChannel.getNonPlayUserInstalledApps();
      final items = list
          .map((e) => MaliciousAppInfo(
                packageName: e['packageName'] ?? '',
                reason: AppStrings.notFromPlayStore,
              ))
          .where((m) => m.packageName.isNotEmpty)
          .toList();
      // Assign raw items first, then filter against whitelist, Play Store,
      // trusted installers, and self if applicable. Avoid flashing unfiltered data.
      _apps = items;
      await _filterWhitelistedApps();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apps = [];
      });
    }
  }

  // Filters out apps that are already whitelisted
  Future<void> _filterWhitelistedApps() async {
    await _loadWhitelist();
    await _loadTrustedInstallers();
    // Also exclude our own package if installed from Google Play Store
    bool installedFromPlay = false;
    String selfPackage = '';
    try {
      installedFromPlay = await PlatformChannel.isInstalledFromPlayStore();
      selfPackage = await PlatformChannel.getPackageName();
    } catch (_) {}
    // Build a new list excluding whitelisted, self (if Play-installed), and any Play-installed packages
    List<MaliciousAppInfo> filtered = [];
    for (final app in _apps) {
      final pkg = app.packageName;
      if (_whitelist.contains(pkg)) continue;
      if (installedFromPlay && selfPackage.isNotEmpty && pkg == selfPackage) continue;
      bool isFromPlay = false;
      try {
        isFromPlay = await PlatformChannel.isPackageFromPlayStore(pkg);
      } catch (_) {}
      if (isFromPlay) continue;
      // If installed by a trusted installer (user-maintained), ignore
      try {
        final installer = await PlatformChannel.getInstallerPackage(pkg);
        if (installer != null && _trustedInstallers.contains(installer)) {
          continue;
        }
      } catch (_) {}
      filtered.add(app);
    }
    if (!mounted) return;
    setState(() {
      _apps = filtered;
    });
  }

  void _showMaliciousAppDialog(
    BuildContext context,
    String packageName,
    String reason,
    int index,
  ) {
    showCustomDialog(
      context: context,
      title: '',
      message: '',
      contentWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.whitelistDialogMessage,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              packageName,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                color: Theme.of(context).colorScheme.secondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
      confirmText: AppStrings.whitelist,
      onConfirm: () async {
        await _addToWhitelist(packageName);
        if (mounted) {
          Navigator.of(context).pop();
          if (widget.onWhitelistUpdated != null) {
            widget.onWhitelistUpdated!();
          }
          showAppToast(context, AppStrings.whitelistSuccess);
        }
      },
      cancelText: AppStrings.openAppInfo,
      onCancel: () {
        Navigator.of(context).pop();
        _openAppInfoAndCheck(packageName, index);
      },
    );
  }

  late List<MaliciousAppInfo> _apps;
  static const platform = MethodChannel('com.zrelxr06.malwirus/sms_security');

  @override
  void initState() {
    super.initState();
    _apps = List.from(widget.detectedMalware);
    WidgetsBinding.instance.addObserver(this);
    _loadNonPlayApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Refresh the list on resume to reflect any app changes
      await _loadNonPlayApps();
    }
  }

  Future<void> _openAppInfoAndCheck(String packageName, int index) async {
    try {
      await PlatformChannel.openAppInfo(packageName, context: context);
      // Wait for user to possibly uninstall, then check if still installed
      await Future.delayed(const Duration(seconds: 2));
      final exists = await platform.invokeMethod<bool>('checkAppInstalled', {
        'packageName': packageName,
      });
      if (exists == false) {
        setState(() {
          _apps.removeAt(index);
        });
      }
    } catch (e) {
      debugPrint('Error opening/checking app info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_apps.isEmpty) {
      return Center(
        child: Text(
          AppStrings.noSuspiciousApps,
          style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            AppStrings.untrustedAppsTitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _apps.length,
          itemBuilder: (context, index) {
            final malware = _apps[index];
            const Widget appIcon = Icon(Icons.apps, color: Colors.redAccent, size: 28);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: appIcon,
                title: Text(
                  malware.packageName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  '${AppStrings.reason}: ${malware.reason}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showMaliciousAppDialog(
                  context,
                  malware.packageName,
                  malware.reason,
                  index,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

