import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

import '../style/icons.dart';
import '../style/theme.dart';
import '../strings.dart';
import '../channel/platform_channel.dart';
import '../settings/help_center/help_screen.dart';
import '../security_status_helper.dart';
import 'bottomsheet/recommendation_bottomsheet.dart';
import 'bottomsheet/maliciousApps_bottomsheet.dart';
import '../style/ui/custom_dialog.dart';
import '../style/ui/feature_note_dialog.dart';

// Local placeholder enum replacing Talsec's Threat for UI purposes
enum Threat {
  hooks,
  debug,
  passcode,
  deviceId,
  simulator,
  appIntegrity,
  obfuscationIssues,
  deviceBinding,
  unofficialStore,
  privilegedAccess,
  secureHardwareNotAvailable,
  devMode,
  adbEnabled,
  screenshot,
  screenRecording,
  systemVPN,
}

class DeviceSecurityScreen extends StatefulWidget {
  final bool showScanFinishedSnack;

  const DeviceSecurityScreen({Key? key, this.showScanFinishedSnack = false})
    : super(key: key);

  @override
  State<DeviceSecurityScreen> createState() => _DeviceSecurityScreenState();
}

class _DeviceSecurityScreenState extends State<DeviceSecurityScreen>
    with SingleTickerProviderStateMixin {
  bool? _hasMaliciousApps;
  bool _didShowSnack = false;
  bool _hasInstallersContent = false;

  // Latest suspicious packages from native
  List<String> _suspiciousPackages = const [];

  // Live native threat keys (SecurityThreat enum names)
  List<String> _threatKeys = const [];
  StreamSubscription<List<String>>? _threatsSub;

  void _refreshMaliciousApps(List detectedMalware) async {
    final result = await _hasNonWhitelistedMaliciousApps(detectedMalware);
    if (mounted) {
      setState(() {
        _hasMaliciousApps = result;
      });
      await _pushSecurityStatusUpdate();
    }
  }
  // Evaluate whether the "App Installers & Sideloaded Apps" sheet would have content
  Future<void> _evaluateInstallersTileVisibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wlJson = prefs.getString(AppStrings.whitelistKey);
      List<String> whitelist = [];
      if (wlJson != null) {
        try {
          whitelist = List<String>.from(json.decode(wlJson));
        } catch (_) {}
      }
      final trustedInstallers = (await PlatformChannel.getTrustedInstallers()).toSet();
      bool installedFromPlay = false;
      String selfPackage = '';
      try {
        installedFromPlay = await PlatformChannel.isInstalledFromPlayStore();
        selfPackage = await PlatformChannel.getPackageName();
      } catch (_) {}
      final nonPlay = await PlatformChannel.getNonPlayUserInstalledApps();
      bool hasContent = false;
      for (final app in nonPlay) {
        final pkg = app['packageName'] ?? '';
        if (pkg.isEmpty) continue;
        if (installedFromPlay && selfPackage.isNotEmpty && pkg == selfPackage) continue;
        if (whitelist.contains(pkg)) continue;
        bool isFromPlay = false;
        try { isFromPlay = await PlatformChannel.isPackageFromPlayStore(pkg); } catch (_) {}
        if (isFromPlay) continue;
        try {
          final installer = await PlatformChannel.getInstallerPackage(pkg);
          if (installer != null && trustedInstallers.contains(installer)) {
            continue;
          }
        } catch (_) {}
        hasContent = true;
        break;
      }
      if (mounted && hasContent != _hasInstallersContent) {
        setState(() {
          _hasInstallersContent = hasContent;
        });
      }
    } catch (_) {
      if (mounted && _hasInstallersContent != false) {
        setState(() {
          _hasInstallersContent = false;
        });
      }
    }
  }

  Future<void> _pushSecurityStatusUpdate() async {
    // Map current native keys to Threats and push to global status helper
    final deviceThreatsList = _mapThreatKeys(_threatKeys);
    // Resolve feature flags
    final prefs = await SharedPreferences.getInstance();
    final smsEnabled = prefs.getBool('sms_scanning_enabled') ?? false;
    final webEnabled = await PlatformChannel.vpnIsActive();
    SecurityStatusHelper.updateSecurityStatus(
      deviceThreats: deviceThreatsList.length,
      smsThreats: 0,
      webThreats: 0,
      hasMaliciousApps: _hasMaliciousApps == true,
      smsEnabled: smsEnabled,
      webEnabled: webEnabled,
      deviceEnabled: true,
      deviceThreatDetails:
          deviceThreatsList.map((t) => _toRecommendationKey(t)).toList(),
    );
  }

  String _toRecommendationKey(Threat t) {
    switch (t) {
      case Threat.hooks:
        return 'hooks';
      case Threat.debug:
        return 'debug';
      case Threat.passcode:
        return 'passcode';
      case Threat.deviceId:
        return 'deviceId';
      case Threat.simulator:
        return 'simulator';
      case Threat.appIntegrity:
        return 'appIntegrity';
      case Threat.obfuscationIssues:
        return 'obfuscationIssues';
      case Threat.deviceBinding:
        return 'deviceBinding';
      case Threat.unofficialStore:
        return 'unofficialStore';
      case Threat.privilegedAccess:
        return 'privilegedAccess';
      case Threat.secureHardwareNotAvailable:
        return 'secureHardwareNotAvailable';
      case Threat.devMode:
        return 'devMode';
      case Threat.adbEnabled:
        return 'adbEnabled';
      case Threat.screenshot:
        return 'screenshot';
      case Threat.screenRecording:
        return 'screenRecording';
      case Threat.systemVPN:
        return 'systemVPN';
    }
  }

  // ------------ Native integration helpers ------------
  Future<void> _loadSuspiciousPackages() async {
    try {
      final pkgs = await PlatformChannel.talsecGetSuspiciousPackages();
      if (!mounted) return;
      setState(() {
        _suspiciousPackages = pkgs;
      });
      // Recompute visibility of installers tile whenever packages snapshot changes
      await _evaluateInstallersTileVisibility();
      final detected =
          pkgs
              .map(
                (e) => MaliciousAppInfo(
                  packageName: e,
                  reason: AppStrings.flaggedByDeviceProtection,
                ),
              )
              .toList();
      _refreshMaliciousApps(detected);
    } catch (_) {}
  }

  List<Threat> _mapThreatKeys(List<String> keys) {
    final List<Threat> list = [];
    for (final k in keys) {
      switch (k) {
        case 'ROOT':
          list.add(Threat.privilegedAccess);
          break;
        case 'DEBUGGER':
          list.add(Threat.debug);
          break;
        case 'EMULATOR':
          list.add(Threat.simulator);
          break;
        case 'TAMPER':
          list.add(Threat.appIntegrity);
          break;
        case 'UNTRUSTED_SOURCE':
          list.add(Threat.unofficialStore);
          break;
        case 'HOOK':
          list.add(Threat.hooks);
          break;
        case 'DEVICE_BINDING':
          list.add(Threat.deviceBinding);
          break;
        case 'OBFUSCATION_ISSUES':
          list.add(Threat.obfuscationIssues);
          break;
        case 'SCREENSHOT':
          list.add(Threat.screenshot);
          break;
        case 'SCREEN_RECORDING':
          list.add(Threat.screenRecording);
          break;
        case 'UNLOCKED_DEVICE':
          list.add(Threat.passcode);
          break;
        case 'NO_HW_KEYSTORE':
          list.add(Threat.secureHardwareNotAvailable);
          break;
        case 'DEVELOPER_MODE':
          list.add(Threat.devMode);
          break;
        case 'ADB_ENABLED':
          list.add(Threat.adbEnabled);
          break;
        case 'SYSTEM_VPN':
          list.add(Threat.systemVPN);
          break;
        // Ignored or represented elsewhere
        case 'MALWARE':
        case 'MULTI_INSTANCE':
        default:
          break;
      }
    }
    return list;
  }

  void _showManualRestartDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.dialogBackground(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                AppIcons.restart,
                color: isDark ? Colors.white70 : AppTheme.primaryColor,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppStrings.deviceManualRestartTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            AppStrings.deviceManualRestartBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppStrings.deviceRestartCancel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.power_settings_new, size: 18),
              label: Text(AppStrings.deviceManualRestartNow),
              onPressed: () async {
                Navigator.of(context).pop();
                // Call native to kill without relaunch; user will tap icon -> cold start
                await PlatformChannel.killAppNoRelaunch();
              },
            ),
          ],
        );
      },
    );
  }

  // Returns true if there is at least one detectedMalware app not in the whitelist
  Future<bool> _hasNonWhitelistedMaliciousApps(List detectedMalware) async {
    // Debug: Print detectedMalware
    PlatformChannel.dLog(
      '[DEBUG] DetectedMalware: ' +
          detectedMalware
              .map((m) => m.packageInfo?.packageName ?? m.packageName)
              .toList()
              .toString(),
    );
    if (detectedMalware.isEmpty) return false;
    // If this app was installed via Google Play, ignore it in detection results
    bool installedFromPlay = false;
    String selfPackage = '';
    try {
      installedFromPlay = await PlatformChannel.isInstalledFromPlayStore();
      selfPackage = await PlatformChannel.getPackageName();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final whitelistJson = prefs.getString(AppStrings.whitelistKey);
    PlatformChannel.dLog('[DEBUG] Whitelist raw: ' + (whitelistJson ?? 'null'));
    List<String> whitelist = [];
    if (whitelistJson != null) {
      try {
        whitelist = List<String>.from(json.decode(whitelistJson));
      } catch (e) {
        PlatformChannel.dLog('[DEBUG] Whitelist JSON decode error: $e');
        whitelist = [];
      }
    }
    PlatformChannel.dLog('[DEBUG] Whitelist parsed: ' + whitelist.toString());
    for (final m in detectedMalware) {
      final pkg = m.packageInfo?.packageName ?? m.packageName;
      PlatformChannel.dLog('[DEBUG] Comparing package: ' + (pkg ?? 'null'));
      // Skip our own package if installed from Play Store
      if (installedFromPlay && pkg == selfPackage) {
        PlatformChannel.dLog(
          '[DEBUG] Skipping self package due to Play Store install: ' + pkg!,
        );
        continue;
      }
      // Skip any package that is installed from Play Store
      if (pkg != null) {
        try {
          final fromPlay = await PlatformChannel.isPackageFromPlayStore(pkg);
          if (fromPlay) {
            PlatformChannel.dLog('[DEBUG] Skipping Play-installed package: ' + pkg);
            continue;
          }
        } catch (_) {}
      }
      if (pkg != null && !whitelist.contains(pkg)) {
        PlatformChannel.dLog('[DEBUG] Not in whitelist: ' + pkg);
        return true;
      } else if (pkg != null) {
        PlatformChannel.dLog('[DEBUG] In whitelist: ' + pkg);
      }
    }
    return false;
  }

  void _showThreatInfoDialog(BuildContext context, Threat threat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isThreatTab = _tabController.index == 0;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.dialogBackground(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isThreatTab ? Icons.warning_amber_rounded : Icons.verified_user,
                color: isThreatTab ? Colors.amber[700] : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getThreatDisplayName(threat),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            isThreatTab
                ? _getThreatDescription(threat)
                : _getSafeThreatDescription(threat),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_circle_outline),
              label: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  bool _switchedToSafeOnStart = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.animation!.value % 1 == 0) {
        setState(() {});
      }
    });

    // Initialize as no malicious apps by default; native side will handle detection.
    _refreshMaliciousApps(const []);

    // Observe native threats and prime with current snapshot
    _loadSuspiciousPackages();
    _evaluateInstallersTileVisibility();
    PlatformChannel.talsecObserveThreats();
    _threatsSub = PlatformChannel.talsecThreatsStream.listen((keys) async {
      if (!mounted) return;
      setState(() {
        _threatKeys = keys;
      });
      await _pushSecurityStatusUpdate();
    });
    // Load current suspicious packages from native and evaluate display condition (already called above)
  }

  @override
  void dispose() {
    _tabController.dispose();
    _threatsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fallback: ensure toast appears on first build if requested
    if (widget.showScanFinishedSnack && !_didShowSnack) {
      _didShowSnack = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppToast(context, AppStrings.deviceScanFinished);
      });
    }
    // Map native threat keys to local Threat enum for display
    final List<Threat> detectedThreats = _mapThreatKeys(_threatKeys);
    final safeChecks = _getSafeChecks(detectedThreats);
    // Only switch to Safe tab ONCE on startup if there are no threats
    if (!_switchedToSafeOnStart &&
        detectedThreats.isEmpty &&
        _tabController.index != 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.index = 1;
      });
      _switchedToSafeOnStart = true;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarColor =
        isDark ? AppTheme.darkAppBarOrange : AppTheme.featureGridLight;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: appBarColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight,
      appBar: AppBar(
        backgroundColor:
            isDark
                ? AppTheme.sheetBackgroundDark
                : AppTheme.sheetBackgroundLight,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppStrings.deviceSecurity,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),

        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            tooltip: AppStrings.learnMore,
            icon: const Icon(Icons.info_outline),
            onPressed: () => FeatureNoteDialog.show(context, FeatureType.device),
          ),
          Tooltip(
            message: AppStrings.deviceRescanTooltip,
            child: IconButton(
              icon: Icon(AppIcons.restart),
              onPressed: () async {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final action = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      backgroundColor: AppTheme.dialogBackground(isDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Row(
                        children: [
                          Icon(
                            AppIcons.restart,
                            color:
                                isDark ? Colors.white70 : AppTheme.primaryColor,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStrings.deviceRescanConfirmTitle,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        AppStrings.deviceRescanChoiceBody,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            // Open Help Center to inform users about relaunch vs background scan
                            Navigator.of(context).pop('cancel');
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HelpScreen(
                                  openArticleId: 'device-restart-faster-scan',
                                ),
                              ),
                            );
                          },
                          child: Text(AppStrings.learnMore),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(AppStrings.deviceRescanInBackground),
                          onPressed: () => Navigator.of(context).pop('rescan'),
                        ),
                      ],
                    );
                  },
                );
                if (action == 'rescan') {
                  // Clear current native threat cache and trigger a rescan; UI will update via stream
                  await PlatformChannel.talsecClearAllThreats();
                  final ok = await PlatformChannel.talsecRescan();
                  if (!mounted) return;
                  showAppToast(
                    context,
                    ok
                        ? AppStrings.deviceRescanTriggered
                        : AppStrings.deviceRescanStarted,
                  );
                  // Refresh suspicious packages list
                  await _loadSuspiciousPackages();
                } else {
                  // Cancelled
                  return;
                }
              },
            ),
          ),
        ],
      ),
      // Conditional scrolling: enable NestedScrollView only on small screens
      body: SafeArea(
        bottom: true,
        child: Builder(
        builder: (context) {
          final media = MediaQuery.of(context);
          final isSmall = media.size.height < 700;
          if (isSmall) {
            return NestedScrollView(
              headerSliverBuilder:
                  (context, innerBoxIsScrolled) => [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ).copyWith(top: 20, bottom: 8),
                      sliver: SliverToBoxAdapter(
                        child: Card(
                          color: Theme.of(context).cardColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 18,
                            ),
                            child: _buildSecurityOverview(
                              context,
                              detectedThreats.length,
                              safeChecks.length,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ).copyWith(bottom: 8),
                      sliver: SliverToBoxAdapter(
                        child: _buildMenuOptions(context),
                      ),
                    ),
                  ],
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16).copyWith(
                  bottom: media.padding.bottom + 8,
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabList(context, detectedThreats, isThreatTab: true),
                    _buildTabList(context, safeChecks, isThreatTab: false),
                  ],
                ),
              ),
            );
          }

          // Larger screens: use original non-scrolling Column layout
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Card(
                    color: Theme.of(context).cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 18,
                      ),
                      child: _buildSecurityOverview(
                        context,
                        detectedThreats.length,
                        safeChecks.length,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildMenuOptions(context),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabList(
                        context,
                        detectedThreats,
                        isThreatTab: true,
                      ),
                      _buildTabList(context, safeChecks, isThreatTab: false),
                    ],
                  ),
                ),
                SizedBox(height: media.padding.bottom + 8),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  /// Build the security overview card with tabs
  Widget _buildSecurityOverview(
    BuildContext context,
    int threatCount,
    int safeCount,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show the count based on which tab is active
    final activeCount = _tabController.index == 0 ? threatCount : safeCount;

    return Column(
      children: [
        // Security score based on active tab
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$activeCount',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color:
                    _tabController.index == 0
                        ? AppTheme.primaryColor
                        : Colors.green,
                shadows: [
                  Shadow(
                    color:
                        isDark ? Colors.black54 : Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            Text(
              '/13',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Custom segmented control (replaces TabBar to eliminate white line)
        Container(
          height: 44,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[100],
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.10),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              // Threats tab
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _tabController.animateTo(0);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color:
                          _tabController.index == 0
                              ? AppTheme.primaryColor.withOpacity(0.18)
                              : Colors.transparent,
                      boxShadow:
                          _tabController.index == 0
                              ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(
                                    0.12,
                                  ),
                                  blurRadius: 6,
                                ),
                              ]
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        'Threats',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              _tabController.index == 0
                                  ? AppTheme.primaryColor
                                  : (isDark ? Colors.white60 : Colors.black45),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Safe tab
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _tabController.animateTo(1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color:
                          _tabController.index == 1
                              ? Colors.green.withOpacity(0.16)
                              : Colors.transparent,
                      boxShadow:
                          _tabController.index == 1
                              ? [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.12),
                                  blurRadius: 6,
                                ),
                              ]
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        'Safe',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              _tabController.index == 1
                                  ? Colors.green
                                  : (isDark ? Colors.white60 : Colors.black45),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build the menu options (Malicious Apps and Recommendations)
  Widget _buildMenuOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppTheme.featureGridOrange
            : AppTheme.featureGridLight;

    final List<Threat> detectedThreats = _mapThreatKeys(_threatKeys);
    final hasThreats = detectedThreats.isNotEmpty;

    return Column(
      children: [
        // App Installers & Sideloaded Apps option (visible only when there is content)
        if (_hasInstallersContent)
          Card(
            color: Theme.of(context).cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                radius: 18,
                child: Icon(
                  AppIcons.threat,
                  color: isDark ? Colors.white : AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              title: Text(
                AppStrings.deviceInstallersButtonTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white70 : Colors.black45,
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => MaliciousAppsBottomSheet(
                    detectedMalware: _suspiciousPackages
                        .map(
                          (pkg) => MaliciousAppInfo(
                            packageName: pkg,
                            reason: AppStrings.flaggedByDeviceProtection,
                          ),
                        )
                        .toList(),
                    onWhitelistUpdated: () async {
                      await _loadSuspiciousPackages();
                      await _evaluateInstallersTileVisibility();
                    },
                  ),
                );
              },
            ),
          ),
        if (_hasInstallersContent) const SizedBox(height: 6),
        // Recommendation Button: only show if there are detected threats
        if (hasThreats)
          Card(
            color: Theme.of(context).cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                radius: 18,
                child: Icon(
                  AppIcons.recommendation,
                  color: isDark ? Colors.white : AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              title: Text(
                AppStrings.securityRecommendations,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white70 : Colors.black45,
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder:
                      (context) => RecommendationBottomSheet(
                        detectedThreatKeys:
                            _mapThreatKeys(
                              _threatKeys,
                            ).map((t) => _toRecommendationKey(t)).toList(),
                      ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Build a unified tab list for threats or safe checks
  Widget _buildTabList(
    BuildContext context,
    List<Threat> items, {
    required bool isThreatTab,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionTitle =
        isThreatTab ? AppStrings.detectedThreats : AppStrings.securityFeatures;
    final emptyText =
        isThreatTab ? AppStrings.noThreatsDetected : AppStrings.noSafeChecks;

    // Return a scrollable list so NestedScrollView can manage overall scroll
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              sectionTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                emptyText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, idx) {
        if (idx == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              sectionTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          );
        }
        final threat = items[idx - 1];
        return Card(
          color: Theme.of(context).cardColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildSecurityItem(context, threat, isDetected: isThreatTab),
        );
      },
    );
  }

  /// Build a security item (threat or safe)
  Widget _buildSecurityItem(
    BuildContext context,
    Threat threat, {
    required bool isDetected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final severity = isDetected ? _getThreatSeverity(threat) : null;
    final severityColor =
        severity == 'High' ? Colors.redAccent : Colors.amber[700];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: CircleAvatar(
        backgroundColor:
            isDetected
                ? severityColor?.withOpacity(0.13)
                : Colors.green.withOpacity(0.13),
        radius: 18,
        child:
            isDetected
                ? Icon(
                  Icons.warning_amber_rounded,
                  color: severityColor,
                  size: 22,
                )
                : Icon(Icons.verified_user, color: Colors.green, size: 20),
      ),
      title: Text(
        _getThreatDisplayName(threat),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.info_outline,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        onPressed: () {
          _showThreatInfoDialog(context, threat);
        },
        splashRadius: 22,
      ),
    );
  }

  /// Get the list of safe checks (threats that are not detected)
  List<Threat> _getSafeChecks(List<Threat> detectedThreats) {
    final allThreats =
        Threat.values
            .where(
              (t) =>
                  t != Threat.screenshot &&
                  t != Threat.screenRecording &&
                  t != Threat.systemVPN,
            )
            .toList();
    return allThreats
        .where((threat) => !detectedThreats.contains(threat))
        .toList();
  }

  /// Get severity level for a threat
  String _getThreatSeverity(Threat threat) {
    // Example severity classification - you could customize this
    final highSeverityThreats = [
      Threat.privilegedAccess,
      Threat.appIntegrity,
      Threat.unofficialStore,
      Threat.obfuscationIssues,
    ];

    if (highSeverityThreats.contains(threat)) {
      return 'High';
    }

    return 'Low';
  }

  /// Get a user-friendly display name for a threat
  String _getThreatDisplayName(Threat threat) {
    switch (threat) {
      case Threat.hooks:
        return 'System Hooks';
      case Threat.debug:
        return 'Debugger';
      case Threat.passcode:
        return 'Screen Lock';
      case Threat.deviceId:
        return 'Device ID';
      case Threat.simulator:
        return 'Simulator/Emulator';
      case Threat.appIntegrity:
        return 'App Integrity';
      case Threat.obfuscationIssues:
        return 'Code Obfuscation';
      case Threat.deviceBinding:
        return 'Device Binding';
      case Threat.unofficialStore:
        return 'Unofficial Store';
      case Threat.privilegedAccess:
        return 'Root/Jailbreak';
      case Threat.secureHardwareNotAvailable:
        return 'Secure Hardware';
      case Threat.devMode:
        return 'Developer Mode';
      case Threat.adbEnabled:
        return 'ADB Enabled';
      default:
        return threat.toString().split('.').last;
    }
  }

  /// Get a description for a threat (not used in this design but kept for future use)
  String _getSafeThreatDescription(Threat threat) {
    switch (threat) {
      case Threat.hooks:
        return 'No system hooks detected.';
      case Threat.debug:
        return 'App is not running in debug mode.';
      case Threat.passcode:
        return 'Device passcode is set.';
      case Threat.deviceId:
        return 'Device ID is intact.';
      case Threat.simulator:
        return 'App is running on a real device.';
      case Threat.appIntegrity:
        return 'App integrity is verified.';
      case Threat.obfuscationIssues:
        return 'App code is properly obfuscated.';
      case Threat.deviceBinding:
        return 'No device binding issues detected.';
      case Threat.unofficialStore:
        return 'App is installed from an official store.';
      case Threat.privilegedAccess:
        return 'Device is not rooted or jailbroken.';
      case Threat.secureHardwareNotAvailable:
        return 'Secure hardware is available.';
      case Threat.devMode:
        return 'Developer mode is disabled.';
      case Threat.adbEnabled:
        return 'Android Debug Bridge is disabled.';
      default:
        return 'No security issues detected.';
    }
  }

  String _getThreatDescription(Threat threat) {
    switch (threat) {
      case Threat.hooks:
        return 'System hooks that could modify app behavior';
      case Threat.debug:
        return 'App is running in debug mode';
      case Threat.passcode:
        return 'Device passcode not set';
      case Threat.deviceId:
        return 'Device ID has been modified';
      case Threat.simulator:
        return 'App is running on a simulator';
      case Threat.appIntegrity:
        return 'App integrity has been compromised';
      case Threat.obfuscationIssues:
        return 'App code obfuscation issues detected';
      case Threat.deviceBinding:
        return 'Device binding issue detected';
      case Threat.unofficialStore:
        return 'App installed from unofficial store';
      case Threat.privilegedAccess:
        return 'Device has privileged access (rooted/jailbroken)';
      case Threat.secureHardwareNotAvailable:
        return 'Secure hardware not available';
      case Threat.devMode:
        return 'Developer mode enabled';
      case Threat.adbEnabled:
        return 'Android Debug Bridge enabled';
      default:
        return 'Unknown security issue';
    }
  }
}
