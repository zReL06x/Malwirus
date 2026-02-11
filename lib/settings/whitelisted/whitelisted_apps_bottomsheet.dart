 import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../style/ui/bottomsheet.dart';
import '../../style/icons.dart';
import '../../strings.dart';
import '../../style/ui/custom_dialog.dart';

/// Bottom sheet for managing Device Security app whitelist.
///
/// This reads and writes a JSON array of package names from SharedPreferences
/// under `AppStrings.whitelistKey`, which is the same storage used by
/// `lib/device_security/bottomsheet/maliciousApps_bottomsheet.dart` when
/// adding an app to the whitelist.
class WhitelistedAppsBottomSheet extends StatefulWidget {
  const WhitelistedAppsBottomSheet({Key? key}) : super(key: key);

  @override
  State<WhitelistedAppsBottomSheet> createState() => _WhitelistedAppsBottomSheetState();
}

class _WhitelistedAppsBottomSheetState extends State<WhitelistedAppsBottomSheet> {
  List<String> _apps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(AppStrings.whitelistKey);
    try {
      final list = jsonStr == null ? <String>[] : List<String>.from(json.decode(jsonStr));
      setState(() {
        _apps = list..sort();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _apps = [];
        _loading = false;
      });
    }
  }

  Future<void> _remove(String pkg) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(AppStrings.whitelistKey);
    List<String> list = [];
    if (jsonStr != null) {
      try {
        list = List<String>.from(json.decode(jsonStr));
      } catch (_) {
        list = [];
      }
    }
    list.removeWhere((e) => e == pkg);
    await prefs.setString(AppStrings.whitelistKey, json.encode(list));
    if (!mounted) return;
    setState(() => _apps = List<String>.from(list)..sort());
    showAppToast(context, AppStrings.removedFromWhitelist);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBottomSheet(
      title: AppStrings.whitelistedAppsTitle,
      icon: AppIcons.whitelist,
      child: _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.whitelist, size: 48, color: isDark ? Colors.white54 : Colors.black54),
            const SizedBox(height: 16),
            Text(
              AppStrings.noWhitelistedApps,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 320),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _apps.length,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.2),
        itemBuilder: (context, index) {
          final pkg = _apps[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
            leading: Icon(Icons.apps, color: isDark ? Colors.white : Colors.black),
            title: Text(
              pkg,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              color: isDark ? Colors.red[300] : Colors.red[700],
              onPressed: () => _remove(pkg),
              tooltip: AppStrings.delete,
            ),
          );
        },
      ),
    );
  }
}
