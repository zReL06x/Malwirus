import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../style/theme.dart';
import '../style/icons.dart';
import '../strings.dart';
import 'permissions/permissionHandler.dart';
import '../introduction_screen.dart';
import '../channel/platform_channel.dart';
import 'help_center/help_screen.dart';
import 'whitelisted/whitelisted_apps_bottomsheet.dart';
import '../style/ui/custom_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  int _retentionDays = 3;
  bool _monitoringEnabled = false;
  bool _monitoringInitLoading = true;
  bool _autoBlockSpam = false;
  bool _autoBlockLoading = true;
  bool _debugMode = false; // session-only
  bool _logcatsEnabled = false; // session-only
  Timer? _versionLongPressTimer;

  Future<int> _getRetentionDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppStrings.retentionKey) ?? 3;
  }

  Future<void> _initAutoBlockSpamToggle() async {
    try {
      final enabled = await PlatformChannel.getAutoBlockSpamSendersEnabled();
      if (!mounted) return;
      setState(() {
        _autoBlockSpam = enabled;
        _autoBlockLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _autoBlockSpam = false;
        _autoBlockLoading = false;
      });
    }
  }

  Future<void> _setAutoBlockSpam(bool enabled) async {
    setState(() => _autoBlockLoading = false);
    final ok = await PlatformChannel.setAutoBlockSpamSendersEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _autoBlockSpam = ok ? enabled : _autoBlockSpam;
      _autoBlockLoading = false;
    });
  }

  Future<void> _initMonitoringToggle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(AppStrings.monitoringPrefKey);
      final active = await PlatformChannel.monitoringIsActive();
      final effective = saved ?? active;
      // If user preference is ON but service isn't active (e.g., after reboot or user stopped), start it
      if ((saved ?? false) && !active) {
        // Attempt to start without UI noise; ensure permission silently
        bool granted = PermissionHandler.notificationGranted.value == true;
        if (!granted) {
          await PermissionHandler.refreshPermissions();
          granted = PermissionHandler.notificationGranted.value == true;
        }
        if (granted) {
          await PlatformChannel.monitoringStart();
        }
      }
      if (mounted) {
        setState(() {
          _monitoringEnabled = effective;
          _monitoringInitLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _monitoringEnabled = false;
          _monitoringInitLoading = false;
        });
      }
    }
  }

  Future<void> _setMonitoringEnabled(bool enabled) async {
    // Ensure permission when enabling
    if (enabled) {
      bool granted = PermissionHandler.notificationGranted.value == true;
      if (!granted) {
        // Try to refresh quickly
        await PermissionHandler.refreshPermissions();
        granted = PermissionHandler.notificationGranted.value == true;
      }
      if (!granted) {
        final ok = await PermissionHandler.requestNotificationPermission();
        granted = ok;
      }
      if (!granted) {
        if (!mounted) return;
        showAppToast(context, AppStrings.monitoringPermissionNeeded);
        setState(() => _monitoringEnabled = false);
        return;
      }
      final ok = await PlatformChannel.monitoringStart();
      if (!ok) {
        if (!mounted) return;
        setState(() => _monitoringEnabled = false);
        return;
      }
    } else {
      await PlatformChannel.monitoringStop();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppStrings.monitoringPrefKey, enabled);
    if (!mounted) return;
    setState(() => _monitoringEnabled = enabled);
  }

  Future<void> _showRetentionPicker() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(AppStrings.retentionKey) ?? 3;
    final options = [3, 7, 30];
    final labels = [
      AppStrings.retention3days,
      AppStrings.retention7days,
      AppStrings.retention30days,
    ];
    int selected = options.indexOf(current);
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? AppTheme.sheetBackgroundDark
              : AppTheme.sheetBackgroundLight,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                AppStrings.retentionPickerTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...List.generate(
              options.length,
              (i) => RadioListTile<int>(
                value: i,
                groupValue: selected,
                onChanged: (val) async {
                  await prefs.setInt(AppStrings.retentionKey, options[i]);
                  setState(() {
                    _retentionDays = options[i];
                  });
                  Navigator.of(context).pop();
                  showAppToast(context, AppStrings.retentionChanged);
                },
                title: Text(labels[i]),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchPermissions();
    _initMonitoringToggle();
    _initAutoBlockSpamToggle();
    // Sync Debug Mode and Logcats state for this session
    _debugMode = PlatformChannel.getDebugModeEnabled();
    if (_debugMode) {
      PlatformChannel.getDebugLogsEnabled().then((on) {
        if (!mounted) return;
        setState(() => _logcatsEnabled = on);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _versionLongPressTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncMonitoringFromPlatform();
      // Keep Debug Mode UI persistent across navigations
      final dm = PlatformChannel.getDebugModeEnabled();
      if (dm != _debugMode) {
        setState(() => _debugMode = dm);
      }
      if (_debugMode) {
        PlatformChannel.getDebugLogsEnabled().then((on) {
          if (!mounted) return;
          if (on != _logcatsEnabled) {
            setState(() => _logcatsEnabled = on);
          }
        });
      }
    }
  }

  Future<void> _syncMonitoringFromPlatform() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefOn = prefs.getBool(AppStrings.monitoringPrefKey) ?? false;
      final active = await PlatformChannel.monitoringIsActive();
      // If preference is ON but service not active (e.g., process killed), try to start it
      if (prefOn && !active) {
        bool granted = PermissionHandler.notificationGranted.value == true;
        if (!granted) {
          await PermissionHandler.refreshPermissions();
          granted = PermissionHandler.notificationGranted.value == true;
        }
        if (granted) {
          final ok = await PlatformChannel.monitoringStart();
          if (ok) {
            // Update active after starting
          }
        }
      }

      if (active != _monitoringEnabled) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppStrings.monitoringPrefKey, active);
        if (!mounted) return;
        setState(() => _monitoringEnabled = active);
      }
    } catch (_) {
      // Ignore sync errors silently
    }
  }

  Future<void> _fetchPermissions() async {
    setState(() => _loading = true);
    await PermissionHandler.refreshPermissions();
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showDataPrivacyDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(AppIcons.privacy, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  AppStrings.dataPrivacy,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            content: Text(
              AppStrings.noDataRetrieved,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                child: Text(
                  AppStrings.close,
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        // Prevent Material 3 from changing the AppBar color when content scrolls under it
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        title: Text(
          AppStrings.settings,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      backgroundColor: bgColor,
      body:
          _loading
              ? Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 0),
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                AppIcons.permission,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppStrings.permissions,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 0),
                          ValueListenableBuilder<bool?>(
                            valueListenable:
                                PermissionHandler.notificationGranted,
                            builder: (context, granted, _) {
                              final isGranted = granted == true;
                              return ListTile(
                                leading: Icon(
                                  AppIcons.notification,
                                  color: isGranted ? Colors.green : Colors.red,
                                ),
                                title: Text(AppStrings.notificationPermission),
                                subtitle: Text(
                                  isGranted
                                      ? AppStrings.permissionGranted
                                      : AppStrings.permissionDenied,
                                ),
                                enabled: !isGranted,
                              );
                            },
                          ),
                          ValueListenableBuilder<bool?>(
                            valueListenable: PermissionHandler.smsGranted,
                            builder: (context, granted, _) {
                              final isGranted = granted == true;
                              return ListTile(
                                leading: Icon(
                                  AppIcons.sms,
                                  color: isGranted ? Colors.green : Colors.red,
                                ),
                                title: Text(AppStrings.smsPermission),
                                subtitle: Text(
                                  isGranted
                                      ? AppStrings.permissionGranted
                                      : AppStrings.permissionDenied,
                                ),
                                enabled: !isGranted,
                                onTap:
                                    isGranted
                                        ? null
                                        : () async {
                                          final ok =
                                              await PermissionHandler.requestSmsPermission();
                                          if (!mounted) return;
                                          if (ok) {
                                            showAppToast(
                                              context,
                                              '${AppStrings.smsPermission}: ${AppStrings.permissionGranted}',
                                            );
                                          }
                                        },
                              );
                            },
                          ),
                          ValueListenableBuilder<bool?>(
                            valueListenable: PermissionHandler.phoneGranted,
                            builder: (context, granted, _) {
                              final isGranted = granted == true;
                              return ListTile(
                                leading: Icon(
                                  AppIcons.phone,
                                  color: isGranted ? Colors.green : Colors.red,
                                ),
                                title: Text(AppStrings.phonePermission),
                                subtitle: Text(
                                  isGranted
                                      ? AppStrings.permissionGranted
                                      : AppStrings.permissionDenied,
                                ),
                                enabled: !isGranted,
                                onTap:
                                    isGranted
                                        ? null
                                        : () async {
                                          final ok =
                                              await PermissionHandler.requestPhonePermission();
                                          if (!mounted) return;
                                          if (ok) {
                                            showAppToast(
                                              context,
                                              '${AppStrings.phonePermission}: ${AppStrings.permissionGranted}',
                                            );
                                          } else {
                                            showAppToast(
                                              context,
                                              AppStrings.phonePermissionDesc,
                                            );
                                          }
                                        },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // --- Auto-block Spam Senders (SMS) ---
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        AppIcons.blocklist,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(AppStrings.autoBlockSpamSenders),
                      subtitle: Text(AppStrings.autoBlockSpamSendersDesc),
                      trailing:
                          _autoBlockLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Switch(
                                value: _autoBlockSpam,
                                onChanged: (val) => _setAutoBlockSpam(val),
                              ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // --- Manage Whitelisted Apps (Device Security) ---
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        AppIcons.whitelist,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(AppStrings.manageAppWhitelist),
                      subtitle: Text(AppStrings.manageAppWhitelistDesc),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.sheetBackgroundDark
                                  : AppTheme.sheetBackgroundLight,
                          builder:
                              (context) => const WhitelistedAppsBottomSheet(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  // --- Persistent Monitoring Notification Toggle ---
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        AppIcons.notification,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(AppStrings.monitoringTitle),
                      subtitle: Text(AppStrings.monitoringDesc),
                      trailing:
                          _monitoringInitLoading
                              ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Switch(
                                value: _monitoringEnabled,
                                onChanged: (val) async {
                                  await _setMonitoringEnabled(val);
                                },
                              ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // --- Web Stats (DNS counters) ---
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        AppIcons.status,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(AppStrings.webStatsSettings),
                      subtitle: Text(AppStrings.resetDnsStatsDesc),
                      trailing: Text(
                        AppStrings.resetDnsStats,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onTap: () async {
                        final ok = await PlatformChannel.vpnResetDnsCounters();
                        if (!mounted) return;
                        if (ok) {
                          showAppToast(context, AppStrings.resetDnsDone);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  // --- Message Retention Setting ---
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        AppIcons.history,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(AppStrings.retentionPeriod),
                      subtitle: Text(AppStrings.retentionPeriodDesc),
                      trailing: FutureBuilder<int>(
                        future: _getRetentionDays(),
                        builder: (context, snapshot) {
                          final days = snapshot.data ?? 7;
                          String label;
                          switch (days) {
                            case 3:
                              label = AppStrings.retention3days;
                              break;
                            case 30:
                              label = AppStrings.retention30days;
                              break;
                            case 7:
                            default:
                              label = AppStrings.retention7days;
                          }
                          return Text(
                            label,
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        },
                      ),
                      onTap: _showRetentionPicker,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // --- Revisit Introduction ---
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        AppIcons.settings,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(AppStrings.settingsShowIntro),
                      subtitle: Text(AppStrings.settingsShowIntroDesc),
                      onTap: () {
                        // Use pushReplacement so Settings is removed from the stack.
                        // This prevents navigating back to Settings after finishing the introduction.
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder:
                                (context) => const IntroductionScreenTemplate(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  // --- Help Center ---
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        AppIcons.help,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(AppStrings.helpCenter),
                      subtitle: Text(AppStrings.helpCenterDesc),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const HelpScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        AppIcons.privacy,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(AppStrings.dataPrivacy),
                      subtitle: Text(AppStrings.dataPrivacyDesc),
                      onTap: _showDataPrivacyDialog,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // --- App Version (from pubspec.yaml via package_info_plus) ---
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPressStart: (_) {
                        _versionLongPressTimer?.cancel();
                        _versionLongPressTimer = Timer(const Duration(seconds: 3), () async {
                          if (!mounted) return;
                          HapticFeedback.lightImpact();
                          final toggled = !_debugMode;
                          setState(() => _debugMode = toggled);
                          PlatformChannel.setDebugModeEnabled(toggled);
                          showAppToast(
                            context,
                            toggled
                                ? AppStrings.debugModeEnabled
                                : AppStrings.debugModeDisabled,
                          );
                          if (!toggled) {
                            await PlatformChannel.setDebugLogsEnabled(false);
                            setState(() => _logcatsEnabled = false);
                          } else {
                            final current = await PlatformChannel.getDebugLogsEnabled();
                            if (!mounted) return;
                            setState(() => _logcatsEnabled = current);
                          }
                        });
                      },
                      onLongPressEnd: (_) {
                        _versionLongPressTimer?.cancel();
                      },
                      child: ListTile(
                        leading: Icon(
                          AppIcons.settings,
                          color: AppTheme.primaryColor,
                        ),
                        title: Text(AppStrings.appVersionLabel),
                        trailing: FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            final versionText = snapshot.hasData
                                ? snapshot.data!.version
                                : AppStrings.versionLoading;
                            return Text(
                              versionText,
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_debugMode) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        AppStrings.debugOptionsHeader,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Simulate SMS Message
                    Card(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Icon(
                          AppIcons.sms,
                          color: AppTheme.primaryColor,
                        ),
                        title: Text(AppStrings.debugSimulateSms),
                        subtitle: Text(AppStrings.debugSimulateSmsDesc),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              final senderController = TextEditingController(text: 'GCASH');
                              final bodyController = TextEditingController();
                              return AlertDialog(
                                backgroundColor: Theme.of(context).dialogBackgroundColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Text(AppStrings.debugSimulateSms),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: senderController,
                                      decoration: InputDecoration(labelText: AppStrings.debugSmsSender),
                                    ),
                                    TextField(
                                      controller: bodyController,
                                      decoration: InputDecoration(labelText: AppStrings.debugSmsBody),
                                      maxLines: 4,
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text(AppStrings.cancel),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final sender = senderController.text.trim();
                                      final body = bodyController.text.trim();
                                      // Validate sender: phone number, short code, or alphanumeric ID
                                      final phoneRx = RegExp(r'^\+?\d{10,15}$');
                                      final shortCodeRx = RegExp(r'^\d{4,8}$');
                                      final alphaIdRx = RegExp(r'^[A-Z][A-Z0-9]{2,10}$');
                                      final sUpper = sender.toUpperCase();
                                      final valid = phoneRx.hasMatch(sender) || shortCodeRx.hasMatch(sender) || alphaIdRx.hasMatch(sUpper);
                                      if (!valid) {
                                        showAppToast(context, AppStrings.debugInvalidSenderFormat);
                                        return;
                                      }
                                      Navigator.of(context).pop();
                                      final ok = await PlatformChannel.simulateSms(sender: sender, body: body);
                                      if (!mounted) return;
                                      if (ok) {
                                        showAppToast(context, AppStrings.debugSmsSimulated);
                                      } else {
                                        showAppToast(context, 'Failed to send simulated SMS');
                                      }
                                    },
                                    child: Text(AppStrings.debugSendToApp),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Enable Logcats
                    Card(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Icon(
                          AppIcons.status,
                          color: AppTheme.primaryColor,
                        ),
                        title: Text(AppStrings.debugEnableLogcats),
                        subtitle: Text(AppStrings.debugEnableLogcatsDesc),
                        trailing: Switch(
                          value: _logcatsEnabled,
                          onChanged: (v) async {
                            final ok = await PlatformChannel.setDebugLogsEnabled(v);
                            if (!mounted) return;
                            setState(() => _logcatsEnabled = ok ? v : _logcatsEnabled);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
    );
  }
}
