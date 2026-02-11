import 'package:flutter/material.dart';
import '../../channel/platform_channel.dart';
import '../../style/ui/bottomsheet.dart';
import '../../style/icons.dart';
import '../../strings.dart';

/// Bottom sheet widget that displays security recommendations based on detected threats
class _RecommendationItem {
  final IconData icon;
  final String title;
  final String description;
  final bool canOpenSettings;
  final String? intentAction;

  const _RecommendationItem({
    required this.icon,
    required this.title,
    required this.description,
    this.canOpenSettings = false,
    this.intentAction,
  });
}

class RecommendationBottomSheet extends StatelessWidget {
  // Accept generic threat keys from native side or elsewhere
  final List<String> detectedThreatKeys;

  const RecommendationBottomSheet({required this.detectedThreatKeys, super.key});

  // Map each threat key to its recommendation, label, and whether it can open settings
  List<_RecommendationItem> _getRecommendationItems() {
    final items = <_RecommendationItem>[];
    for (final key in detectedThreatKeys) {
      switch (key) {
        case 'debug':
          items.add(
            _RecommendationItem(
              icon: Icons.bug_report,
              title: 'Debugger',
              description: 'Detach any debugging tools from your device.',
            ),
          );
          break;
        case 'hooks':
          items.add(
            _RecommendationItem(
              icon: Icons.extension,
              title: 'System Hooks',
              description:
                  'Check for unauthorized apps or frameworks that may use system hooks.',
            ),
          );
          break;
        case 'simulator':
          items.add(
            _RecommendationItem(
              icon: Icons.phone_android,
              title: 'Simulator/Emulator',
              description: 'Use the app on a real device for better security.',
            ),
          );
          break;
        case 'deviceId':
          items.add(
            _RecommendationItem(
              icon: Icons.perm_device_information,
              title: 'Device ID',
              description:
                  'Check your device identifier settings for integrity.',
            ),
          );
          break;
        case 'passcode':
          items.add(
            _RecommendationItem(
              icon: Icons.lock,
              title: 'Screen Lock',
              description: 'Enable a screen lock to protect your device.',
              canOpenSettings: true,
              intentAction: 'android.settings.SECURITY_SETTINGS',
            ),
          );
          break;
        case 'appIntegrity':
          items.add(
            _RecommendationItem(
              icon: Icons.verified_user,
              title: 'App Integrity',
              description:
                  'Reinstall the app from an official store to ensure its integrity.',
            ),
          );
          break;
        case 'obfuscationIssues':
          items.add(
            _RecommendationItem(
              icon: Icons.code,
              title: 'Code Obfuscation',
              description:
                  'Update the app to a version with improved code protection.',
            ),
          );
          break;
        case 'deviceBinding':
          items.add(
            _RecommendationItem(
              icon: Icons.link,
              title: 'Device Binding',
              description:
                  'Avoid unauthorized app cloning or device transfers.',
            ),
          );
          break;
        case 'unofficialStore':
          items.add(
            _RecommendationItem(
              icon: Icons.store,
              title: 'Unofficial Store',
              description: 'Only install apps from official app stores.',
            ),
          );
          break;
        case 'privilegedAccess':
          items.add(
            _RecommendationItem(
              icon: Icons.security,
              title: 'Root/Jailbreak',
              description: 'Avoid rooting or jailbreaking your device.',
            ),
          );
          break;
        case 'secureHardwareNotAvailable':
          items.add(
            _RecommendationItem(
              icon: Icons.hardware,
              title: 'Secure Hardware',
              description:
                  'Use devices with secure hardware for better cryptographic protection.',
            ),
          );
          break;
        case 'systemVPN':
          items.add(
            _RecommendationItem(
              icon: Icons.vpn_lock,
              title: 'System VPN',
              description: 'Review VPN usage and ensure it is trusted.',
              canOpenSettings: true,
              intentAction: 'android.net.vpn.SETTINGS',
            ),
          );
          break;
        case 'devMode':
          items.add(
            _RecommendationItem(
              icon: Icons.developer_mode,
              title: 'Developer Mode',
              description: 'Disable developer mode for better security.',
              canOpenSettings: true,
              intentAction: 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
            ),
          );
          break;
        case 'adbEnabled':
          items.add(
            _RecommendationItem(
              icon: Icons.usb,
              title: 'ADB Enabled',
              description:
                  'Disable Android Debug Bridge (ADB) when not needed.',
              canOpenSettings: true,
              intentAction: 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
            ),
          );
          break;
        default:
          items.add(
            _RecommendationItem(
              icon: Icons.shield,
              title: 'Security',
              description: 'Review your device security settings.',
            ),
          );
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _getRecommendationItems();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBottomSheet(
      title: AppStrings.securityRecommendations,
      icon: AppIcons.recommendation,
      sliverChildren:
          items.isEmpty
              ? [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      AppStrings.noRecommendations,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ]
              : items
                  .map(
                    (item) => Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          item.icon,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          item.description,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        trailing:
                            item.canOpenSettings
                                ? const Icon(Icons.arrow_forward_ios, size: 16)
                                : null,
                        onTap:
                            item.canOpenSettings && item.intentAction != null
                                ? () => PlatformChannel.openAndroidSettings(
                                  item.intentAction!,
                                )
                                : null,
                      ),
                    ),
                  )
                  .toList(),
    );
  }
}
