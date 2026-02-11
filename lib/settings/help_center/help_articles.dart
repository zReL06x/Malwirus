import 'package:flutter/material.dart';
import '../../strings.dart';

// Optional per-article visual sections (image + short text)
class HelpSection {
  final String title;
  final String imageAsset;
  final String description;

  const HelpSection({
    required this.title,
    required this.imageAsset,
    required this.description,
  });
}

// Central article model
class HelpArticle {
  final String id;
  final String title;
  final String category; // e.g., SMS, Device, Web, Others
  final String body; // Fallback/plain body
  final List<HelpSection>? sections; // Optional structured content

  const HelpArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.body,
    this.sections,
  });
}

// Static repository of articles
class HelpArticlesRepo {
  static final List<HelpArticle> all = [
    // Map quick links to articles
    HelpArticle(
      id: 'web-whitelist',
      title: AppStrings.helpArtBlockedWebsitesWhitelist,
      category: AppStrings.helpCatWebSecurity,
      body: AppStrings.bodyArtBlockedWebsitesWhitelist,
    ),
    HelpArticle(
      id: 'sms-why-blocked',
      title: AppStrings.helpQuickWhySmsBlocked,
      category: AppStrings.helpCatSmsSecurity,
      body: AppStrings.bodyQuickWhySmsBlocked,
    ),
    HelpArticle(
      id: 'why-some-recommendation-have-actions',
      title: AppStrings.helpQuickRecommendationAction,
      category: AppStrings.helpCatDeviceSecurity,
      body: AppStrings.bodyQuickRecommendationAction,
    ),
    HelpArticle(
      id: 'web-filtering-explained',
      title: AppStrings.helpQuickWebFilteringExplained,
      category: AppStrings.helpCatWebSecurity,
      body: AppStrings.bodyQuickWebFilteringExplained,
    ),
    HelpArticle(
      id: 'web-why-site-blocked',
      title: AppStrings.helpQuickWhySiteBlocked,
      category: AppStrings.helpCatWebSecurity,
      body: AppStrings.bodyQuickWhySiteBlocked,
    ),
    HelpArticle(
      id: 'web-why-domain-filter-not-working',
      title: AppStrings.helpWhyDomainFilterNotWorking,
      category: AppStrings.helpCatWebSecurity,
      body: AppStrings.bodyWhyDomainFilterNotWorking,
    ),
    // Newly added FAQs
    HelpArticle(
      id: 'device-state-detected',
      title: AppStrings.helpQuickHowDeviceStateDetected,
      category: AppStrings.helpCatDeviceSecurity,
      body: AppStrings.bodyQuickHowDeviceStateDetected,
    ),
    HelpArticle(
      id: 'sms-enable-scanning',
      title: AppStrings.helpQuickEnableSmsScanning,
      category: AppStrings.helpCatSmsSecurity,
      body: AppStrings.bodyQuickEnableSmsScanning,
    ),
    HelpArticle(
      id: 'sms-auto-link-scan',
      title: AppStrings.helpQuickWhatIsAutoLinkScan,
      category: AppStrings.helpCatSmsSecurity,
      body: AppStrings.bodyQuickWhatIsAutoLinkScan,
    ),
    HelpArticle(
      id: 'sms-manage-whitelist',
      title: AppStrings.helpQuickManageSmsWhitelist,
      category: AppStrings.helpCatSmsSecurity,
      body: AppStrings.bodyQuickManageSmsWhitelist,
    ),
    HelpArticle(
      id: 'what-is-malicious-apps',
      title: AppStrings.helpQuickMaliciousApps,
      category: AppStrings.helpCatDeviceSecurity,
      body: AppStrings.bodyQuickMaliciousApps,
    ),
    HelpArticle(
      id: 'sms-block-number',
      title: AppStrings.helpQuickBlockNumber,
      category: AppStrings.helpCatSmsSecurity,
      body: AppStrings.bodyQuickBlockNumber,
    ),
    HelpArticle(
      id: 'sms-what-happens-when-blocking',
      title: AppStrings.helpQuickWhatHappensWhenBlocking,
      category: AppStrings.helpCatSmsSecurity,
      body: AppStrings.bodyQuickWhatHappensWhenBlocking,
    ),
    HelpArticle(
      id: 'dns-universal',
      title: AppStrings.helpQuickUniversalDnsFiltering,
      category: AppStrings.helpCatWebSecurity,
      body: AppStrings.bodyQuickUniversalDnsFiltering,
    ),
    HelpArticle(
      id: 'dns-per-app',
      title: AppStrings.helpQuickPerAppDnsFiltering,
      category: AppStrings.helpCatWebSecurity,
      body: AppStrings.bodyQuickPerAppDnsFiltering,
    ),
    // Device scan performance (Talsec re-init)
    HelpArticle(
      id: 'device-restart-faster-scan',
      title: AppStrings.helpQuickWhyRestartFasterDeviceScan,
      category: AppStrings.helpCatDeviceSecurity,
      body: AppStrings.bodyQuickWhyRestartFasterDeviceScan,
    ),
    HelpArticle(
      id: 'privacy-does-send-data',
      title: AppStrings.helpQuickDoesSendData,
      category: AppStrings.helpCatOthers,
      body: AppStrings.bodyQuickDoesSendData,
    ),
    HelpArticle(
      id: 'contact-support',
      title: AppStrings.helpQuickContactSupport,
      category: AppStrings.helpCatOthers,
      body: AppStrings.bodyContactSupportGuide,
    ),
    // Device Security Guide (category: Device Security)
    HelpArticle(
      id: 'device-security-guide',
      title: AppStrings.helpQuickDeviceSecurityGuide,
      category: AppStrings.helpCatDeviceSecurity,
      body: '',
      sections: [
        HelpSection(
          title: AppStrings.deviceGuideOverviewSafeTitle,
          imageAsset: 'assets/help_center/device_security/overview_safe.png',
          description: AppStrings.deviceGuideOverviewSafeDesc,
        ),
        HelpSection(
          title: AppStrings.deviceGuideOverviewThreatsTitle,
          imageAsset: 'assets/help_center/device_security/overview_threats.png',
          description: AppStrings.deviceGuideOverviewThreatsDesc,
        ),
        HelpSection(
          title: AppStrings.deviceGuideDetectedThreatsTitle,
          imageAsset: 'assets/help_center/device_security/detected_threats.png',
          description: AppStrings.deviceGuideDetectedThreatsDesc,
        ),
        HelpSection(
          title: AppStrings.deviceGuideActionButtonsTitle,
          imageAsset: 'assets/help_center/device_security/action_buttons.png',
          description: AppStrings.deviceGuideActionButtonsDesc,
        ),
      ],
    ),
    // SMS Security Guide
    HelpArticle(
      id: 'sms-security-guide',
      title: AppStrings.helpQuickSmsSecurityGuide,
      category: AppStrings.helpCatSmsSecurity,
      body: '',
      sections: [
        HelpSection(
          title: AppStrings.smsGuideOverviewTitle,
          imageAsset: 'assets/help_center/sms_security/overview.png',
          description: AppStrings.smsGuideOverviewDesc,
        ),
        HelpSection(
          title: AppStrings.smsGuideFeatureControlTitle,
          imageAsset: 'assets/help_center/sms_security/feature_control.png',
          description: AppStrings.smsGuideFeatureControlDesc,
        ),
        HelpSection(
          title: AppStrings.smsGuideManageListsTitle,
          imageAsset:
              'assets/help_center/sms_security/manage_whitelist_blocklist.png',
          description: AppStrings.smsGuideManageListsDesc,
        ),
      ],
    ),
    // Web Security Guide
    HelpArticle(
      id: 'web-security-guide',
      title: AppStrings.helpQuickWebSecurityGuide,
      category: AppStrings.helpCatWebSecurity,
      body: '',
      sections: [
        HelpSection(
          title: AppStrings.webGuideOverviewTitle,
          imageAsset: 'assets/help_center/web_security/vpn_overview.png',
          description: AppStrings.webGuideOverviewDesc,
        ),
        HelpSection(
          title: AppStrings.webGuideBlockingMethodTitle,
          imageAsset: 'assets/help_center/web_security/blocking_method.png',
          description: AppStrings.webGuideBlockingMethodDesc,
        ),
        HelpSection(
          title: AppStrings.webGuideFeatureControlTitle,
          imageAsset: 'assets/help_center/web_security/feature_control.png',
          description: AppStrings.webGuideFeatureControlDesc,
        ),
        HelpSection(
          title: AppStrings.webGuideDnsBlocklistTitle,
          imageAsset: 'assets/help_center/web_security/dns_blocklist.png',
          description: AppStrings.webGuideDnsBlocklistDesc,
        ),
        HelpSection(
          title: AppStrings.webGuideBlockedDomainsTitle,
          imageAsset: 'assets/help_center/web_security/blocked_domains.png',
          description: AppStrings.webGuideBlockedDomainsDesc,
        ),
      ],
    ),
    // Settings Guide (Others) with images per section
    HelpArticle(
      id: 'settings-guide',
      title: AppStrings.helpQuickSettingsGuide,
      category: AppStrings.helpCatOthers,
      body: '',
      sections: [
        HelpSection(
          title: AppStrings.permissions,
          imageAsset: 'assets/help_center/settings/permission.png',
          description: AppStrings.settingsGuidePermissionsDesc,
        ),
        HelpSection(
          title: AppStrings.autoBlockSpamSenders,
          imageAsset: 'assets/help_center/settings/auto_block_spam.png',
          description: AppStrings.settingsGuideAutoBlockSpamDesc,
        ),
        HelpSection(
          title: AppStrings.manageAppWhitelist,
          imageAsset: 'assets/help_center/settings/whitelisted_app.png',
          description: AppStrings.settingsGuideWhitelistedAppsDesc,
        ),
        HelpSection(
          title: AppStrings.monitoringTitle,
          imageAsset: 'assets/help_center/settings/persistent.png',
          description: AppStrings.settingsGuideMonitoringDesc,
        ),
        HelpSection(
          title: AppStrings.webStatsSettings,
          imageAsset: 'assets/help_center/settings/web_stats.png',
          description: AppStrings.settingsGuideWebStatsDesc,
        ),
        HelpSection(
          title: AppStrings.retentionPeriod,
          imageAsset: 'assets/help_center/settings/history_deletion.png',
          description: AppStrings.settingsGuideHistoryDeletionDesc,
        ),
        HelpSection(
          title: AppStrings.settingsShowIntro,
          imageAsset: 'assets/help_center/settings/show_introduction.png',
          description: AppStrings.settingsGuideShowIntroDesc,
        ),
        HelpSection(
          title: AppStrings.helpCenter,
          imageAsset: 'assets/help_center/settings/help_center.png',
          description: AppStrings.settingsGuideHelpCenterDesc,
        ),
        HelpSection(
          title: AppStrings.dataPrivacy,
          imageAsset: 'assets/help_center/settings/data_privacy.png',
          description: AppStrings.settingsGuideDataPrivacyDesc,
        ),
      ],
    ),
  ];

  static List<HelpArticle> search(String keyword) {
    final q = keyword.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (a) =>
              a.title.toLowerCase().contains(q) ||
              a.category.toLowerCase().contains(q),
        )
        .toList();
  }

  static HelpArticle? byId(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // Returns up to [max] related articles in the same category, excluding the given [current].
  static List<HelpArticle> relatedTo(HelpArticle current, {int max = 3}) {
    return all
        .where((a) => a.category == current.category && a.id != current.id)
        .take(max)
        .toList();
  }
}
