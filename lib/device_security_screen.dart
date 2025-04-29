import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freerasp/freerasp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../preference_manager.dart';
import '../device_security/widgets.dart';
import 'theme/app_colors.dart';
import '../device_security/recommendation_bottom_sheet.dart';
import '../device_security/threat_notifier.dart';
import '../device_security/threat_state.dart';
import '../device_security/malware_bottom_sheet.dart';

/// The device security screen that displays security threats and protection status
class DeviceSecurityScreen extends ConsumerStatefulWidget {
  const DeviceSecurityScreen({super.key});

  @override
  ConsumerState<DeviceSecurityScreen> createState() => _DeviceSecurityScreenState();
}

class _DeviceSecurityScreenState extends ConsumerState<DeviceSecurityScreen> {
  bool _showThreats = true; // Default to showing threats
  
  @override
  void initState() {
    super.initState();
    
    // Track visits to Device Security screen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final prefManager = PreferenceManager();
        final visitCount = await prefManager.incrementDeviceSecurityVisitCount();
        final shouldShow = await prefManager.getShowSecurityScanMessage();
        
        // Show dialog only on second or later visit and if user hasn't disabled it
        if (visitCount > 1 && shouldShow) {
          // ignore: use_build_context_synchronously
          _showSecurityScanDialog(context);
        }
      }
    });
  }
  
  void _showSecurityScanDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Text(
          'Device security scan is performed on app start only.',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () {
              // Don't show again
              PreferenceManager().setShowSecurityScanMessage(false);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF34C759),
            ),
            child: const Text('Don\'t show again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF34C759),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  // Helper methods for the threat level display
  String _getThreatLevel(Set<Threat> threats) {
    final count = threats.length;
    if (count == 0) return 'Low';
    if (count <= 3) return 'Moderate';
    if (count <= 6) return 'High';
    return 'Critical';
  }
  
  Color _getThreatColor(String level) {
    switch (level) {
      case 'Low': return Colors.green;
      case 'Moderate': return Colors.yellow.shade700;
      case 'High': return Colors.orange;
      case 'Critical': return Colors.red;
      default: return Colors.green;
    }
  }
  
  void _showThreatInfoDialog(BuildContext context, Threat threat, bool isDarkMode) {
    final threatName = _getThreatName(threat);
    final isDetected = ref.read(threatProvider).detectedThreats.contains(threat);
    final threatDescription = _getThreatDescription(threat, isDetected);
    final severity = isDetected ? _getThreatSeverity(threat) : 'Safe';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(threatName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: severity == 'Safe' 
                    ? const Color(0xFF34C759).withOpacity(0.2) 
                    : _getSeverityColor(severity).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                severity,
                style: TextStyle(
                  color: severity == 'Safe' 
                      ? const Color(0xFF34C759) 
                      : _getSeverityColor(severity),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              threatDescription,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showSafeThreats() {
    setState(() {
      _showThreats = false;
    });
  }
  
  void _showDetectedThreats() {
    setState(() {
      _showThreats = true;
    });
  }
  
  String _getThreatName(Threat threat) {
    switch (threat) {
      case Threat.debug: return 'Debugger';
      case Threat.simulator: return 'Simulator/Emulator';
      case Threat.passcode: return 'Screen Lock';
      case Threat.deviceId: return 'Device ID';
      case Threat.appIntegrity: return 'App Integrity';
      case Threat.obfuscationIssues: return 'Code Obfuscation';
      case Threat.deviceBinding: return 'Device Binding';
      case Threat.unofficialStore: return 'Unofficial Store';
      case Threat.privilegedAccess: return 'Root/Jailbreak';
      case Threat.secureHardwareNotAvailable: return 'Secure Hardware';
      case Threat.systemVPN: return 'System VPN';
      case Threat.devMode: return 'Developer Mode';
      case Threat.adbEnabled: return 'ADB Enabled';
      case Threat.hooks: return 'System Hooks';
      // Screenshot and Screen Recording items removed as requested
      default: return threat.name.replaceAll('_', ' ');
    }
  }
  
  String _getThreatDescription(Threat threat, bool isDetected) {
    switch (threat) {
      case Threat.debug: 
        return isDetected
            ? 'A debugger is attached to the app, which could allow attackers to extract sensitive information or modify app behavior.'
            : 'Debugger checks verify that no debugging tools are attached to the app, which helps protect against code analysis and tampering.';
      case Threat.simulator: 
        return isDetected
            ? 'The app is running in an emulator/simulator environment, which may be used for reverse engineering.'
            : 'Simulator detection ensures the app is running on a real device, which provides better security than emulated environments.';
      case Threat.passcode: 
        return isDetected
            ? 'Your device does not have a screen lock enabled, making it easier for unauthorized users to access your data.'
            : 'Screen lock is enabled on your device, providing an additional layer of protection against unauthorized physical access.';
      case Threat.deviceId: 
        return isDetected
            ? 'Device identifier integrity issues detected, which may indicate device spoofing.'
            : 'Device identifier integrity is intact, ensuring your device is properly identified by security systems.';
      case Threat.appIntegrity: 
        return isDetected
            ? 'The app has been modified or tampered with, potentially compromising its security.'
            : 'App integrity is verified, confirming that the application code has not been modified or tampered with.';
      case Threat.obfuscationIssues: 
        return isDetected
            ? 'Code obfuscation issues detected, making the app more vulnerable to reverse engineering.'
            : 'Code obfuscation is properly implemented, making it difficult for attackers to analyze or reverse engineer the app.';
      case Threat.deviceBinding: 
        return isDetected
            ? 'Device-app binding security issues detected, which may allow unauthorized app cloning.'
            : 'Device-app binding is secure, preventing unauthorized cloning or transfer of the app to other devices.';
      case Threat.unofficialStore: 
        return isDetected
            ? 'The app was installed from an unofficial source, which may indicate a compromised version.'
            : 'The app was installed from an official app store, ensuring it passed security verification and is not a modified version.';
      case Threat.privilegedAccess: 
        return isDetected
            ? 'Your device is rooted/jailbroken, which significantly reduces system security protections.'
            : 'Your device is not rooted or jailbroken, maintaining the full security protections provided by the operating system.';
      case Threat.secureHardwareNotAvailable: 
        return isDetected
            ? 'Secure hardware features are not available on this device, reducing cryptographic security.'
            : 'Secure hardware features are available and active on your device, providing enhanced cryptographic security.';
      case Threat.systemVPN: 
        return isDetected
            ? 'A system-wide VPN is active, which could potentially intercept network traffic.'
            : 'No system-wide VPN is active, reducing the risk of network traffic interception.';
      case Threat.devMode: 
        return isDetected
            ? 'Developer mode is enabled on your device, which allows installing untrusted apps.'
            : 'Developer mode is disabled on your device, preventing the installation of untrusted applications.';
      case Threat.adbEnabled: 
        return isDetected
            ? 'Android Debug Bridge (ADB) is enabled, which allows remote access to your device.'
            : 'Android Debug Bridge (ADB) is disabled, preventing unauthorized remote access to your device.';
      case Threat.hooks: 
        return isDetected
            ? 'System-level hooks detected, which may be used to intercept sensitive information.'
            : 'No system-level hooks detected, ensuring normal system operation without interception of sensitive information.';
      case Threat.screenshot: 
        return isDetected
            ? 'Screenshot protection is not enabled, allowing other apps to capture sensitive information.'
            : 'Screenshot protection is enabled, preventing other apps from capturing sensitive information from your screen.';
      case Threat.screenRecording: 
        return isDetected
            ? 'Screen recording detected, which may be capturing sensitive information.'
            : 'No screen recording detected, ensuring your screen content remains private.';
      default: 
        return isDetected
            ? 'Potential security vulnerability detected.'
            : 'This security check has passed successfully.';
    }
  }
  
  String _getThreatSeverity(Threat threat) {
    switch (threat) {
      case Threat.debug:
      case Threat.simulator:
      case Threat.systemVPN:
        return 'Low';
      case Threat.passcode:
      case Threat.deviceId:
      case Threat.devMode:
      case Threat.adbEnabled:
        return 'Medium';
      case Threat.appIntegrity:
      case Threat.obfuscationIssues:
      case Threat.deviceBinding:
      case Threat.unofficialStore:
      case Threat.secureHardwareNotAvailable:
      case Threat.hooks:
        return 'High';
      case Threat.privilegedAccess:
        return 'Critical';
      default:
        return 'Medium';
    }
  }
  
  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Low': return Colors.green;
      case 'Medium': return Colors.orange;
      case 'High': return Colors.deepOrange;
      case 'Critical': return Colors.red;
      default: return Colors.orange;
    }
  }

  // Helper method to compare two lists of SuspiciousAppInfo
  bool _areListsEqual(List<SuspiciousAppInfo> list1, List<SuspiciousAppInfo> list2) {
    if (list1.length != list2.length) return false;
    
    // Create a set of package names for efficient comparison
    final packageNames1 = list1.map((app) => app.packageInfo.packageName).toSet();
    final packageNames2 = list2.map((app) => app.packageInfo.packageName).toSet();
    
    // Direct manual comparison instead of setEquals
    return packageNames1.length == packageNames2.length &&
           packageNames1.every((element) => packageNames2.contains(element));
  }



  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final threatState = ref.watch(threatProvider);
    final detectedThreats = threatState.detectedThreats
        .where((threat) => threat != Threat.screenshot && threat != Threat.screenRecording)
        .toSet();
    // Only display threats from the provider
    final isDetectingThreats = detectedThreats.isNotEmpty;
    final visibleThreats = _showThreats ? detectedThreats : <Threat>{};
    
    // Calculate threat level based on actual detected threats from the provider
    final threatLevel = _getThreatLevel(detectedThreats);
    final threatColor = _getThreatColor(threatLevel);
    
    // Count safe vs threat checks (excluding screenshot and screen recording)
    final totalChecks = Threat.values.length - 2; // Subtract 2 for screenshot and screen recording
    final threatChecks = detectedThreats.length;
    final safeChecks = totalChecks - threatChecks;
    

    // Store current malware detection state in a local variable to be used by didUpdateWidget
    final malwareApps = threatState.detectedMalware;
    final hasThreats = detectedThreats.isNotEmpty;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Device Security',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Summary Card
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? threatColor.withOpacity(0.15) : threatColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Centered count
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
                            child: Center(
                              child: Text(
                                '${detectedThreats.length}/$totalChecks',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          
                          // Device status
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  detectedThreats.isNotEmpty ? Icons.warning_amber_rounded : Icons.shield,
                                  color: threatColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Device Status: $threatLevel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: threatColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Underlined tabs
                          Row(
                            children: [
                              // Threats Tab
                              Expanded(
                                child: InkWell(
                                  onTap: _showDetectedThreats,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Text(
                                          'Threats (${threatChecks})',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _showThreats 
                                                ? threatColor 
                                                : isDarkMode ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                      ),
                                      // Colored underline when active
                                      Container(
                                        height: 3,
                                        color: _showThreats ? threatColor : Colors.transparent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Safe Tab
                              Expanded(
                                child: InkWell(
                                  onTap: _showSafeThreats,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Text(
                                          'Safe (${safeChecks})',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: !_showThreats 
                                                ? Colors.green 
                                                : isDarkMode ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                      ),
                                      // Underline for Safe tab
                                      Container(
                                        height: 3,
                                        color: !_showThreats ? Colors.green : Colors.transparent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Dedicated Malicious Apps section - only show when malware is detected
                    if (malwareApps.isNotEmpty) 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _showMalwareBottomSheet(context, malwareApps);
                            },
                            borderRadius: BorderRadius.circular(12),
                            highlightColor: Colors.red.withOpacity(0.1),
                            splashColor: Colors.red.withOpacity(0.1),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Malicious Apps',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Recommendations button - only show when threats are detected
                    if (detectedThreats.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => RecommendationBottomSheet(
                                  detectedThreats: detectedThreats,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            highlightColor: Colors.green.withOpacity(0.08),
                            splashColor: Colors.green.withOpacity(0.08),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Recommendations',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.recommend, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    // Content based on selected tab
                    if (_showThreats) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'Detected Issues',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        child: detectedThreats.isNotEmpty ? ListView.builder(
                          itemCount: threatState.detectedThreats.where(
                            (threat) => threat != Threat.screenshot && threat != Threat.screenRecording
                          ).length,
                          itemBuilder: (context, index) {
                            // Regular threat items
                            final filteredThreats = threatState.detectedThreats.where(
                              (threat) => threat != Threat.screenshot && threat != Threat.screenRecording
                            ).toList();
                            final threat = filteredThreats[index];
                            final threatName = _getThreatName(threat);
                            final severity = _getThreatSeverity(threat);
                            final severityColor = _getSeverityColor(severity);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          threatName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: severityColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            severity,
                                            style: TextStyle(
                                              color: severityColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.info_outline, size: 20),
                                    onPressed: () => _showThreatInfoDialog(context, threat, isDarkMode),
                                  ),
                                ],
                              ),
                            );
                          },
                        ) : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.security,
                                size: 64,
                                color: const Color(0xFF34C759).withOpacity(0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Security Issues Detected',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF34C759),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your device is currently secure',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[  
                      // Safe section
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'All Safe',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      
                      Expanded(
                        child: ListView.builder(
                          itemCount: safeChecks,
                          itemBuilder: (context, index) {
                            // Get all threats that are not detected, excluding screenshot and screen recording
                            final safeThreats = Threat.values.where(
                              (threat) => !threatState.detectedThreats.contains(threat) && 
                                         threat != Threat.screenshot && 
                                         threat != Threat.screenRecording
                            ).toList();
                            
                            if (index < safeThreats.length) {
                              final threat = safeThreats[index];
                              final threatName = _getThreatName(threat);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground(context),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            threatName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                              color: isDarkMode ? Colors.white : Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDarkMode ? const Color(0xFF34C759).withOpacity(0.15) : const Color(0xFF34C759).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Safe',
                                              style: TextStyle(
                                                color: Color(0xFF34C759),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.info_outline, size: 20),
                                      onPressed: () => _showThreatInfoDialog(context, threat, isDarkMode),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Bottom space
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}


/// Shows a bottom sheet with malware information
void _showMalwareBottomSheet(
  BuildContext context,
  List<SuspiciousAppInfo> suspiciousApps,
) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Allow drag-to-dismiss and default background
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return MalwareBottomSheet(
          suspiciousApps: suspiciousApps,
        );
      },
    );
  });
}

/// Represents current state of the threats detectable by freeRASP
final threatProvider =
    NotifierProvider.autoDispose<ThreatNotifier, ThreatState>(() {
  return ThreatNotifier();
});


