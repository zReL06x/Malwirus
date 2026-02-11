import 'package:flutter/material.dart';

class AppIcons {
  static const IconData sms = Icons.sms; // Used in: settings/settings_screen.dart (SMS permission list item)
  static const IconData permission = Icons.lock_open; // Used in: settings/settings_screen.dart (Permissions section header)
  static const IconData privacy = Icons.privacy_tip; // Used in: settings/settings_screen.dart (Data Privacy section header icon)
  // Feature Icons - main feature buttons
  static const IconData deviceSecurity = Icons.security; // Currently unused in search results
  static const IconData smsSecurity = Icons.sms; // Used in: sms_security/sms_securityScreen.dart (section icon)
  static const IconData webSecurity = Icons.public; // Currently unused in search results
  static const IconData history = Icons.history; // Currently unused in search results
  static const IconData whitelist = Icons.verified_user; // Used in: web_security/web_screen.dart (DNS blocklist section icon), sms_security/bottomsheet/whitelist_bottomsheet.dart (sheet icon and empty state), settings/whitelisted/whitelisted_apps_bottomsheet.dart (sheet icon and empty state)
  static const IconData blocklist = Icons.block; // Used in: web_security/web_screen.dart (Per-app blocking section icon), sms_security/bottomsheet/blocklist_bottomsheet.dart (sheet icon and empty state)
  static const IconData phone = Icons.phone; // Used in: sms_security/bottomsheet/whitelist_bottomsheet.dart & bottomsheet/blocklist_bottomsheet.dart (list item leading), settings/settings_screen.dart (Phone permission list item)
  static const IconData list = Icons.list_alt; // Used in: web_security/bottomsheet/manage_dns_bottomsheet.dart (ListTile leading icon)
  
  // UI Icons
  static const IconData settings = Icons.settings; // Currently unused in search results
  static const IconData scan = Icons.sync; // Currently unused in search results
  static const IconData shieldProtected = Icons.verified; // Used in: web_security/web_screen.dart (VPN status + toggle), sms_security/sms_securityScreen.dart (status header, tiles)
  static const IconData threat = Icons.warning; // Used in: web_security/web_screen.dart (status when not connected), sms_security/sms_securityScreen.dart (threat indicator)
  static const IconData securityFeature = Icons.security_update_good; // Currently unused in search results
  static const IconData points = Icons.star; // Currently unused in search results
  static const IconData status = Icons.shield; // Used in: sms_security/sms_securityScreen.dart (fallback status icon when disabled)
  static const IconData recommendation = Icons.tips_and_updates; // Used in: style/ui/bottomsheet.dart (example usage in docs)
  static const IconData notification = Icons.notifications; // Used in: settings/settings_screen.dart (Notification permission list item)
  static const IconData help = Icons.help_center; // Currently unused in search results
  static const IconData support = Icons.support_agent; // Currently unused in search results (intended for contact support actions)
  static const IconData restart = Icons.restart_alt; // Currently unused in search results (intended for manual restart action)
  
  // Helper method to get icons with consistent styling
  static Icon getIcon(IconData icon, {Color? color, double size = 24.0}) {
    return Icon(
      icon,
      color: color,
      size: size,
    );
  }
  
  // Helper to get feature icon with proper styling
  static Widget getFeatureIcon(IconData icon, {Color? color, required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? (isDark ? Colors.white : Colors.black);
    
    return Icon(
      icon,
      color: iconColor,
      size: 28.0,
    );
  } // Used in: web_security/web_screen.dart (_sectionHeader, section headers with AppIcons.whitelist/blocklist)
}

