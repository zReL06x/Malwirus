import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:malwirus/settings/settings_screen.dart';
import 'package:malwirus/style/ui/bottomsheet.dart';
import 'package:malwirus/web_security/web_screen.dart';
import 'home_screenBottomsheet.dart';
import 'style/icons.dart';
import 'style/theme.dart';
import 'strings.dart';
import 'device_security/device_securityScreen.dart';
import 'sms_security/sms_securityScreen.dart';
import 'history/history_screen.dart';
import 'security_status_helper.dart';
import 'channel/platform_channel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<List<String>>? _talsecSub;

  void _navigateToSmsSecurity(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SmsSecurityScreen()));
  }

  bool isProtected = true; // Track protection status

  @override
  void initState() {
    super.initState();
    // Push an immediate snapshot so Home reflects current status ASAP
    _pushHomeSecurityStatusUpdate();
    // Handle post-restart deep link to Device Security safely from Home context
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final goDeviceSecurity =
          prefs.getBool(AppStrings.launchDeviceSecurityAfterRestartKey) ??
          false;
      if (goDeviceSecurity && mounted) {
        await prefs.remove(AppStrings.launchDeviceSecurityAfterRestartKey);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => const DeviceSecurityScreen(showScanFinishedSnack: true),
          ),
        );
      }
      // Start observing device threats and push an initial status
      await PlatformChannel.talsecObserveThreats();
      _talsecSub = PlatformChannel.talsecThreatsStream.listen((keys) async {
        await _pushHomeSecurityStatusUpdate(deviceThreatsOverride: keys.length);
      });
      // Prime once with current snapshot if no events yet
      await _pushHomeSecurityStatusUpdate();
    });
  }

  Future<void> _pushHomeSecurityStatusUpdate({int? deviceThreatsOverride}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final smsEnabled = prefs.getBool('sms_scanning_enabled') ?? false;
      final webEnabled = await PlatformChannel.vpnIsActive();
      final deviceThreats = deviceThreatsOverride ?? (await PlatformChannel.talsecGetThreats()).length;
      // Determine if MaliciousAppsBottomSheet would have content
      // Load non‑Play apps and filter by whitelist and trusted installers
      bool hasMaliciousApps = false;
      try {
        final nonPlay = await PlatformChannel.getNonPlayUserInstalledApps();
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
          hasMaliciousApps = true; // At least one will make the sheet show content
          break;
        }
      } catch (_) {
        hasMaliciousApps = false;
      }

      SecurityStatusHelper.updateSecurityStatus(
        deviceThreats: deviceThreats,
        smsThreats: 0,
        webThreats: 0,
        hasMaliciousApps: hasMaliciousApps,
        smsEnabled: smsEnabled,
        webEnabled: webEnabled,
        deviceEnabled: true,
        deviceThreatDetails: const [],
      );
    } catch (_) {
      // Ignore errors; Home will remain with last known status
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset =
        isDark ? 'assets/logo/logo_light.png' : 'assets/logo/logo_dark.png';

    // Set status bar color and icon brightness to match app bar
    final bgColor =
        isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        // Match Android navigation bar with page background to prevent overlap
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        title: Row(
          children: [
            Image.asset(logoAsset, width: 24, height: 24),
            const SizedBox(width: 8),
            Text(
              AppStrings.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              AppIcons.settings,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        maintainBottomViewPadding: true,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              final double bottomSpace = media.viewPadding.bottom;
              final content = Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildThreatOverviewSection(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureGrid(),
                ],
              );
              return SingleChildScrollView(
                clipBehavior: Clip.none,
                padding: EdgeInsets.only(bottom: bottomSpace),
                child: content,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        border: Border.all(color: AppTheme.primaryColor, width: 2),
      ),
      child: Center(
        child: Icon(AppIcons.scan, color: AppTheme.primaryColor, size: 40),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isProtected ? AppIcons.shieldProtected : Icons.warning,
          color: isProtected ? AppTheme.successGreen : AppTheme.primaryColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          isProtected ? AppStrings.deviceProtected : AppStrings.deviceAtRisk,
          style: TextStyle(
            color: isProtected ? AppTheme.successGreen : AppTheme.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final features = [
      {
        'title': AppStrings.deviceSecurity,
        'icon': AppIcons.deviceSecurity,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DeviceSecurityScreen(),
            ),
          );
        },
      },
      {
        'title': AppStrings.smsSecurity,
        'icon': AppIcons.smsSecurity,
        'onTap': () => _navigateToSmsSecurity(context),
      },
      {
        'title': AppStrings.webSecurity,
        'icon': AppIcons.webSecurity,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const WebSecurityScreen()),
          );
        },
      },
      {
        'title': AppStrings.history,
        'icon': AppIcons.history,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const HistoryScreen()),
          );
        },
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children:
          features
              .map(
                (feature) => Card(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildFeatureCard(
                    title: feature['title'] as String,
                    icon: feature['icon'] as IconData,
                    onTap: feature['onTap'] as Function(),
                    color: Theme.of(context).iconTheme.color ?? Colors.black,
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required Function onTap,
    Color color = Colors.white,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 38),
            const SizedBox(height: 10),
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Mock data - in real implementation, this would come from SharedPreferences/TalSec
  int get mockSecurityPoints => 65; // Example point value
  int get mockDetectedThreats => 3; // Example detected threats
  bool get isWebSecurityEnabled => true; // Example status
  bool get isSmsSecurityEnabled => false; // Example status

  // Get threat status based on points
  String getThreatStatus(int points) {
    if (points >= 80) return AppStrings.threatStatusLow;
    if (points >= 60) return AppStrings.threatStatusMedium;
    if (points >= 40) return AppStrings.threatStatusHigh;
    return AppStrings.threatStatusCritical;
  }

  // Get color based on threat status
  Color getThreatStatusColor(String status) {
    switch (status) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.deepOrange;
      case 'Critical':
        return AppTheme.primaryColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  Widget _buildThreatOverviewSection() {
    final initial = SecurityStatusHelper.getCurrentStatus();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<SecurityStatus>(
      stream: SecurityStatusHelper.statusStream,
      initialData: initial,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final detectedThreats = status?.totalThreats ?? 0;
        final isWebSecurityEnabled = status?.webEnabled ?? false;
        final isSmsSecurityEnabled = status?.smsEnabled ?? false;
        final securityScore = status?.score ?? SecurityStatusHelper.calculateSecurityPoints(
          detectedThreats: detectedThreats,
          smsEnabled: isSmsSecurityEnabled,
          webEnabled: isWebSecurityEnabled,
        );
        final threatStatus = status?.statusLabel ?? SecurityStatusHelper.getSecurityStatusLabel(
          securityScore,
        );
        final recommendations = status?.recommendations ?? SecurityStatusHelper.generateRecommendations(
          detectedThreats: detectedThreats,
          smsEnabled: isSmsSecurityEnabled,
          webEnabled: isWebSecurityEnabled,
          deviceThreats: const [],
          smsThreats: const [],
          hasMaliciousApps: status?.hasMaliciousApps ?? false,
        );

        final statusColor =
            threatStatus == 'Safe'
                ? Colors.green
                : threatStatus == 'Warning'
                ? Colors.orange
                : Colors.red;

        return Column(
          children: [
            const SizedBox(height: 10),

            // Threat overview details container
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
                  Text(
                    AppStrings.threatOverview,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Points and Status Row
                  Row(
                    children: [
                      // Security points indicator
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.points, color: Colors.amber, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.pointsLabel,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      '$securityScore/100',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Threat status indicator
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.status, color: statusColor, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.securityStatus,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      threatStatus,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Security Features
                  Text(
                    AppStrings.securityFeatures,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureStatus('Web Security', isWebSecurityEnabled, Icons.public),
                  const SizedBox(height: 8),
                  _buildFeatureStatus('SMS Security', isSmsSecurityEnabled, Icons.sms),
                  const SizedBox(height: 16),

                  // Detected Threats
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.threat,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.detectedThreats,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                detectedThreats.toString(),
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  color:
                                      detectedThreats > 0
                                          ? AppTheme.primaryColor
                                          : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  RecommendationButton(
                    context,
                    recommendations: recommendations,
                    hasThreats: detectedThreats > 0,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureStatus(String title, bool isEnabled, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black54,
        ),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                isEnabled
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isEnabled ? AppStrings.enabled : AppStrings.disabled,
            style: TextStyle(
              color: isEnabled ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(String threatStatus) {
    List<String> recommendations = [];

    // Add recommendations based on threat status
    if (!isWebSecurityEnabled) {
      recommendations.add('Enable Web Security to monitor dangerous websites');
    }

    if (!isSmsSecurityEnabled) {
      recommendations.add('Enable SMS Security to detect phishing attempts');
    }

    if (mockDetectedThreats > 0) {
      recommendations.add('Review and resolve detected threats');
    }

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AppIcons.recommendation, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              AppStrings.recommendedActions,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppTheme.primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recommendations.map(
          (recommendation) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: AppTheme.primaryColor)),
                Expanded(
                  child: Text(
                    recommendation,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
