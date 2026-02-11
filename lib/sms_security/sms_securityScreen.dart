import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../style/icons.dart';
import '../style/theme.dart';
import '../strings.dart';
import '../channel/platform_channel.dart';
import '../security_status_helper.dart';
import 'bottomsheet/whitelist_bottomsheet.dart'; 
import 'bottomsheet/blocklist_bottomsheet.dart';
import '../style/ui/custom_dialog.dart';
import '../style/ui/feature_note_dialog.dart';

class SmsSecurityScreen extends StatefulWidget {
  const SmsSecurityScreen({Key? key}) : super(key: key);

  @override
  State<SmsSecurityScreen> createState() => _SmsSecurityScreenState();
}

class _SmsSecurityScreenState extends State<SmsSecurityScreen> {
  bool smsScanningEnabled = false;
  bool autoLinkScanEnabled = false;
  int messagesScanned = 0;
  int suspiciousLinks = 0;
  List<String> whitelistedNumbers = [];
  bool _isInitialized = false;

  void _toggleSmsScanning(bool value) async {
    setState(() {
      smsScanningEnabled = value;
      if (!value) {
        autoLinkScanEnabled = false;
      }
    });
    
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      PlatformChannel.setSmsScanningEnabled(value),
      if (!value) prefs.setBool('auto_link_scan_enabled', false),
      prefs.setBool('sms_scanning_enabled', value),
    ]);
    await _pushSecurityStatusUpdateFromSms();
  }

  void _toggleAutoLinkScan(bool value) async {
    if (!smsScanningEnabled) {
      // If SMS scanning is disabled, ensure the toggle reflects the disabled state
      setState(() {
        autoLinkScanEnabled = false;
      });
      return;
    }
    
    setState(() {
      autoLinkScanEnabled = value;
    });
    
    try {
      await Future.wait([
        PlatformChannel.setLinkScanningEnabled(value),
        SharedPreferences.getInstance().then((prefs) => prefs.setBool('auto_link_scan_enabled', value)),
      ]);
    } catch (e) {
      // If there's an error, revert the UI state
      if (mounted) {
        setState(() {
          autoLinkScanEnabled = !value;
        });
        showAppToast(context, 'Failed to update link scanning: ${e.toString()}');
      }
    }
  }

  // Placeholder helper removed; not needed with current UX

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Load persisted preferences first so initial UI reflects correct states
    final prefs = await SharedPreferences.getInstance();
    final sms = prefs.getBool('sms_scanning_enabled') ?? false;
    // Ensure auto link scan cannot be true if SMS scanning is disabled
    final auto = sms ? (prefs.getBool('auto_link_scan_enabled') ?? false) : false;

    // Fetch stats; do these in parallel
    final results = await Future.wait<int>([
      PlatformChannel.getMessagesScanned(),
      PlatformChannel.getSuspiciousLinksFound(),
    ]);

    if (!mounted) return;
    setState(() {
      smsScanningEnabled = sms;
      autoLinkScanEnabled = auto;
      messagesScanned = results[0];
      suspiciousLinks = results[1];
      _isInitialized = true;
    });
    // Push current flags to the global status helper so Home reflects accurate state
    await _pushSecurityStatusUpdateFromSms();
  }

  Future<void> _pushSecurityStatusUpdateFromSms() async {
    try {
      final webEnabled = await PlatformChannel.vpnIsActive();
      final deviceThreats = (await PlatformChannel.talsecGetThreats()).length;
      final hasMaliciousApps = (await PlatformChannel.talsecGetSuspiciousPackages()).isNotEmpty;
      SecurityStatusHelper.updateSecurityStatus(
        deviceThreats: deviceThreats,
        smsThreats: 0,
        webThreats: 0,
        hasMaliciousApps: hasMaliciousApps,
        smsEnabled: smsScanningEnabled,
        webEnabled: webEnabled,
        deviceEnabled: true,
        deviceThreatDetails: const [],
      );
    } catch (_) {}
  }

  // Legacy loaders removed; initialization handled by _initialize()

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final iconColor =
        smsScanningEnabled
            ? AppTheme.successGreen
            : theme.iconTheme.color?.withOpacity(0.5);
    final shieldIcon =
        smsScanningEnabled ? AppIcons.shieldProtected : AppIcons.status;
    final statusText =
        smsScanningEnabled ? AppStrings.enabled : AppStrings.disabled;
    final statusDesc =
        smsScanningEnabled
            ? AppStrings.smsScanningActiveDesc
            : AppStrings.smsScanningInactiveDesc;
    final statusIconBg =
        smsScanningEnabled
            ? AppTheme.successGreen.withOpacity(0.12)
            : (isDark ? Colors.white10 : Colors.black12);

    // Set status bar and app bar colors to match home screen/device security
    final bgColor = isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
        foregroundColor: theme.textTheme.titleLarge?.color,
        title: Text(
          AppStrings.smsSecurity,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: AppStrings.learnMore,
            icon: const Icon(Icons.info_outline),
            onPressed: () => FeatureNoteDialog.show(context, FeatureType.sms),
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isInitialized
            ? Builder(
          builder: (context) {
            final media = MediaQuery.of(context);
            final isSmall = media.size.height < 700;
            final content = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card (top)
              Card(
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: statusIconBg,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Icon(shieldIcon, color: iconColor, size: 36),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${AppStrings.smsScanning}: $statusText',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  statusDesc,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.smsSecurity,
                                    color: theme.iconTheme.color,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.messagesScanned,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$messagesScanned',
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.threat,
                                    color: theme.iconTheme.color,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.suspiciousLinks,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$suspiciousLinks',
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Feature Control Card
              Card(
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.featureControl,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.enableSmsScanning,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppStrings.smsScanDesc,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: smsScanningEnabled,
                            onChanged: _toggleSmsScanning,
                            activeColor: AppTheme.successGreen,
                            activeTrackColor: AppTheme.successGreen.withOpacity(
                              0.5,
                            ),
                            inactiveThumbColor:
                                isDark ? Colors.grey[800] : Colors.grey[300],
                            inactiveTrackColor:
                                isDark ? Colors.white24 : Colors.black12,
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.enableAutoLinkScan,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color:
                                        smsScanningEnabled
                                            ? theme.textTheme.bodyLarge?.color
                                            : theme.disabledColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: 56,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      smsScanningEnabled
                                          ? AppStrings.autoLinkScanDesc
                                          : AppStrings.enableSmsFirstDesc,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color:
                                                smsScanningEnabled
                                                    ? theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color
                                                    : theme.disabledColor,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: autoLinkScanEnabled,
                            onChanged:
                                smsScanningEnabled ? _toggleAutoLinkScan : null,
                            activeColor: AppTheme.successGreen,
                            activeTrackColor: AppTheme.successGreen.withOpacity(
                              0.5,
                            ),
                            inactiveThumbColor:
                                isDark ? Colors.grey[800] : Colors.grey[300],
                            inactiveTrackColor:
                                isDark ? Colors.white24 : Colors.black12,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Manage Whitelist Card
              Card(
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(AppIcons.shieldProtected, color: theme.iconTheme.color),
                  title: Text(
                    AppStrings.manageWhitelist,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    AppStrings.whitelistDesc,
                    style: theme.textTheme.bodyMedium,
                  ),
                  trailing: Icon(Icons.chevron_right, color: theme.iconTheme.color),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const WhitelistManagementSheet(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Manage Blocklist Card
              Card(
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(AppIcons.blocklist, color: theme.iconTheme.color),
                  title: Text(
                    AppStrings.manageBlocklist,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    AppStrings.blocklistDesc,
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const BlocklistManagementSheet(),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                    );
                  },
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: theme.iconTheme.color,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Ensure safe space at bottom so content never hides behind
              // 3-button navigation bars on some Android devices.
              SizedBox(height: media.padding.bottom + 8),
            ],
          ),
            );
            if (isSmall) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: media.padding.bottom + 8),
                child: content,
              );
            } else {
              return content;
            }
          },
        )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
