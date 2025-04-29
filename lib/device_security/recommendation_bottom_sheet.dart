import 'package:flutter/material.dart';
import 'package:freerasp/freerasp.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'threat_state.dart';
import 'threat_state.dart';
import 'package:malwirus/theme/app_colors.dart';

/// Bottom sheet widget that displays security recommendations based on detected threats
class _RecommendationItem {
  final IconData icon;
  final String title;
  final String description;
  final bool canOpenSettings;
  final AndroidIntent? settingsIntent;

  const _RecommendationItem({
    required this.icon,
    required this.title,
    required this.description,
    this.canOpenSettings = false,
    this.settingsIntent,
  });
}

class RecommendationBottomSheet extends StatelessWidget {
  final Set<Threat> detectedThreats;
  const RecommendationBottomSheet({
    required this.detectedThreats,
    super.key,
  });

  // Map each threat to its recommendation, label, and whether it can open settings
  List<_RecommendationItem> _getRecommendationItems() {
    final items = <_RecommendationItem>[];
    for (final threat in detectedThreats) {
      switch (threat) {
        case Threat.debug:
          items.add(_RecommendationItem(
            icon: Icons.bug_report,
            title: 'Debugger',
            description: 'Detach any debugging tools from your device.',
          ));
          break;
        case Threat.hooks:
          items.add(_RecommendationItem(
            icon: Icons.extension,
            title: 'System Hooks',
            description: 'Check for unauthorized apps or frameworks that may use system hooks.',
          ));
          break;
        case Threat.simulator:
          items.add(_RecommendationItem(
            icon: Icons.phone_android,
            title: 'Simulator/Emulator',
            description: 'Use the app on a real device for better security.',
          ));
          break;
        case Threat.screenshot:
          items.add(_RecommendationItem(
            icon: Icons.camera,
            title: 'Screenshot Detected',
            description: 'Be cautious of unauthorized screenshots. You may review app permissions in settings.',
          ));
          break;
        case Threat.screenRecording:
          items.add(_RecommendationItem(
            icon: Icons.videocam,
            title: 'Screen Recording',
            description: 'Be cautious of unauthorized screen recording. You may review app permissions in settings.',
          ));
          break;
        case Threat.passcode:
          items.add(_RecommendationItem(
            icon: Icons.lock,
            title: 'Screen Lock',
            description: 'Enable a screen lock to protect your device.',
            canOpenSettings: true,
            settingsIntent: const AndroidIntent(
              action: 'android.settings.SECURITY_SETTINGS',
              flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
            ),
          ));
          break;
        case Threat.deviceId:
          items.add(_RecommendationItem(
            icon: Icons.perm_device_information,
            title: 'Device ID',
            description: 'Check your device identifier settings for integrity.',
          ));
          break;
        case Threat.appIntegrity:
          items.add(_RecommendationItem(
            icon: Icons.verified_user,
            title: 'App Integrity',
            description: 'Reinstall the app from an official store to ensure its integrity.',
          ));
          break;
        case Threat.obfuscationIssues:
          items.add(_RecommendationItem(
            icon: Icons.code,
            title: 'Code Obfuscation',
            description: 'Update the app to a version with improved code protection.',
          ));
          break;
        case Threat.deviceBinding:
          items.add(_RecommendationItem(
            icon: Icons.link,
            title: 'Device Binding',
            description: 'Avoid unauthorized app cloning or device transfers.',
          ));
          break;
        case Threat.unofficialStore:
          items.add(_RecommendationItem(
            icon: Icons.store,
            title: 'Unofficial Store',
            description: 'Only install apps from official app stores.',
          ));
          break;
        case Threat.privilegedAccess:
          items.add(_RecommendationItem(
            icon: Icons.security,
            title: 'Root/Jailbreak',
            description: 'Avoid rooting or jailbreaking your device.',
          ));
          break;
        case Threat.secureHardwareNotAvailable:
          items.add(_RecommendationItem(
            icon: Icons.hardware,
            title: 'Secure Hardware',
            description: 'Use devices with secure hardware for better cryptographic protection.',
          ));
          break;
        case Threat.systemVPN:
          items.add(_RecommendationItem(
            icon: Icons.vpn_lock,
            title: 'System VPN',
            description: 'Review VPN usage and ensure it is trusted.',
          ));
          break;
        case Threat.devMode:
          items.add(_RecommendationItem(
            icon: Icons.developer_mode,
            title: 'Developer Mode',
            description: 'Disable developer mode for better security.',
            canOpenSettings: true,
            settingsIntent: const AndroidIntent(
              action: 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
              flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
            ),
          ));
          break;
        case Threat.adbEnabled:
          items.add(_RecommendationItem(
            icon: Icons.usb,
            title: 'ADB Enabled',
            description: 'Disable Android Debug Bridge (ADB) when not needed.',
            canOpenSettings: true,
            settingsIntent: const AndroidIntent(
              action: 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
              flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
            ),
          ));
          break;
        case Threat.systemVPN:
          items.add(_RecommendationItem(
            icon: Icons.vpn_lock,
            title: 'System VPN',
            description: 'Review VPN usage and ensure it is trusted.',
            canOpenSettings: true,
            settingsIntent: const AndroidIntent(
              action: 'android.net.vpn.SETTINGS',
              flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
            ),
          ));
          break;
        case Threat.hooks:
          items.add(_RecommendationItem(
            icon: Icons.extension,
            title: 'System Hooks',
            description: 'Check for unauthorized apps or frameworks that may use system hooks.',
          ));
          break;
        default:
          items.add(_RecommendationItem(
            icon: Icons.shield,
            title: 'Security',
            description: 'Review your device security settings.',
          ));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final items = _getRecommendationItems();
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Security Recommendations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
               Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'No recommendations. Your device is secure!',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: items.length,
                        itemBuilder: (_, idx) {
                          final item = items[idx];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Icon(item.icon, color: isDarkMode ? Colors.white : Colors.black),
                              title: Text(
                                '${item.title}:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                item.description,
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              trailing: item.canOpenSettings
                                  ? IconButton(
                                      icon: Icon(Icons.arrow_forward_ios, color: isDarkMode ? Colors.white : Colors.black),
                                      onPressed: () async {
                                        await item.settingsIntent?.launch();
                                      },
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
