class AppStrings {
  // ---Settings ---
  static const String settings = 'Settings';
  static const String permissions = 'Permissions';
  static const String notificationPermission = 'Notification Permission';
  static const String smsPermission = 'SMS Permission';
  static const String phonePermission = 'Phone & Call Permission';
  static const String permissionGranted = 'Granted';
  static const String permissionDenied = 'Denied';
  static const String dataPrivacy = 'Data Privacy';
  static const String dataPrivacyDesc = 'Learn about how your data is handled.';
  static const String phonePermissionDesc =
      'Needed to detect incoming call state and identify incoming numbers for soft-block alerts.';
  static const String noDataRetrieved =
      'No data is being retrieved. Your privacy is protected.';
  static const String appVersionLabel = 'App Version';
  static const String versionLoading = 'Loading...';

  // Debug Mode (session-scoped)
  static const String debugModeEnabled = 'Debug Mode Enabled';
  static const String debugModeDisabled = 'Debug Mode Disabled';
  static const String debugOptionsHeader = 'Debug Options';
  static const String debugSimulateSms = 'Simulate SMS Message';
  static const String debugSimulateSmsDesc =
      '[TEST ONLY] Create a fake SMS input for parser.';
  static const String debugEnableLogcats = 'Enable Logcats';
  static const String debugEnableLogcatsDesc =
      '[TEST ONLY] Turn on in-app logs.';
  static const String debugViewLogs = 'View Logs';
  static const String debugNoLogs = 'No logs captured yet.';
  static const String debugSmsSender = 'Sender';
  static const String debugSmsBody = 'Message body';
  static const String debugSendToApp = 'Send to App';
  static const String debugSmsSimulated = 'Simulated SMS sent to parser.';
  static const String debugDefaultSender = 'GCASH';
  static const String debugInvalidSenderFormat =
      'Invalid sender format. Use 4–8 digit short code or 3–11 character alphanumeric ID.';

  // Help Center
  static const String helpCenter = 'Help Center';
  static const String helpCenterDesc = 'Find FAQs and contact support.';
  static const String helpSearchPlaceholder = 'Search for help articles...';
  static const String helpCategories = 'Categories';
  static const String helpLatestArticles = 'Latest Help Articles';
  static const String helpSeeMore = 'See More Articles >';
  static const String helpSeeAll = 'See All >';
  static const String helpRelatedArticles = 'Related articles';

  static const String helpDidntFind = "Didn't find what you're looking for?";
  static const String helpContactSupport = 'Contact Support';
  static const String helpAllArticles = 'All Help Articles';
  static const String helpUnderDevelopment = 'Under development';
  static const String helpNoResults = 'No articles found';

  static String helpResultsFor(String q) => "Results for '" + q + "'";

  // Contact Support form
  static const String supportEmail = 'rpangilinan22-0610@cca.edu.ph';
  static const String supportYourEmail = 'Your email';
  static const String supportSubject = 'Subject';
  static const String supportDescribeIssue = 'Describe your issue';
  static const String supportSend = 'Send';
  static const String supportCancel = 'Cancel';
  static const String supportInvalidEmail =
      'Please enter a valid email address';
  static const String supportOpenEmailFailed = 'Could not open your email app.';
  static const String supportDefaultSubject = 'Support Request';
  static const String supportSubtitle =
      'Tell us what went wrong or how we can help.';
  static const String supportReplyEta = 'We typically reply within 3-5 days.';
  static const String supportEmailLabel = 'Support email';

  // Help Center: Contact Support article body
  static const String bodyContactSupportGuide =
      'You can reach us directly from the app.\n\n'
          'How to contact support:\n'
          '1. Open Help Center and tap "' +
      helpContactSupport +
      '".\n'
          '2. Enter your email, a short subject, and describe the issue.\n'
          '3. Tap Send — your mail app opens with everything pre‑filled.\n\n'
          'How messages are sent:\n'
          '- Malwirus uses your device\'s email app to send a message to ' +
      supportEmail +
      '.\n'
          '- The email body is prepared locally; you review and send it from your mail app.\n'
          '- We do not store your message content inside the app.\n\n'
          'Response time:\n'
          '- Expect a reply within 3–5 business days.';

  // Help Center: Category titles
  static const String helpCatSmsSecurity = 'SMS Security';
  static const String helpCatDeviceSecurity = 'Device Security';
  static const String helpCatWebSecurity = 'Web Security';
  static const String helpCatOthers = 'Others';

  // Help Center: Quick links per category
  static const String helpQuickFilterSpamSms = 'Filter spam SMS';
  static const String helpQuickReportPhishing = 'Report phishing';
  static const String helpQuickWhySmsBlocked = 'Why SMS blocked?';

  static const String bodyQuickWhySmsBlocked =
      'Malwirus does not block or delete any of your SMS messages.\n\n'
      'Instead, it scans messages for suspicious content such as malicious links or phishing attempts and notifies you if something looks unsafe.\n\n'
      'All messages still arrive in your inbox — Malwirus only helps you identify potential threats.\n\n'
      'If you notice SMS not being delivered, it may be due to:\n'
      '- Another app with SMS blocking features interfering.\n'
      '- Your default SMS app having the sender marked as blocked.\n\n'
      'In such cases, check your SMS app settings or other security apps installed on your device.';

  static const String helpQuickWebFilteringExplained =
      'Web filtering explained';
  static const String bodyQuickWebFilteringExplained =
      'Our Web Security uses an on-device connection (local VPN) to inspect DNS lookups from your apps.\n\n'
      '- When an app tries to reach a website, we check the domain against curated blocklists and your own rules.\n'
      '- If the domain is unsafe (malware, phishing, trackers) the connection is blocked before it loads.\n'
      '- You can apply rules for all apps or set per‑app filters to control which apps are filtered.\n'
      '\n'
      'This happens on your device. We do not store your browsing content. Basic statistics (like number of blocked requests) are available in Web Security to help you understand protection activity.';

  static const String helpQuickWhySiteBlocked = 'Why a site is blocked?';
  static const String bodyQuickWhySiteBlocked =
      'A site may be blocked for these reasons:\n\n'
      '- It matches a domain you added to Manage Blocked Domains (your blocklist).\n'
      '- It’s included in the Pre‑listed Domains set that’s enabled under Web Security > Manage Blocked Domains > Pre‑listed Domains.';

  static const String helpQuickSettingsGuide = 'Settings guide';
  static const String helpQuickDeviceSecurityGuide = 'Device Security guide';
  static const String helpQuickSmsSecurityGuide = 'SMS Security guide';
  static const String helpQuickWebSecurityGuide = 'Web Security guide';
  static const String helpQuickTroubleshoot = 'Troubleshooting errors';
  static const String helpQuickContactSupport = 'Contact support';

  // Help Center: New FAQ titles (Quick) and bodies
  // Device Security: how we determine device/app state
  static const String helpQuickHowDeviceStateDetected =
      'How does Device Security detect app and device state?';
  static const String bodyQuickHowDeviceStateDetected =
      'Device Security monitors the integrity of your device using Talsec protection.\n\n'
      '- It checks for root/jailbreak, emulator, and debugger risks.\n'
      '- It verifies if the device is running in a secure environment.\n'
      '- It listens to system security signals to alert you of issues.\n'
      '- No personal files or content are scanned; only the device\'s security state is evaluated.';

  // Device Security: why restarting can be faster for re-scan
  static const String helpQuickWhyRestartFasterDeviceScan =
      'Why is restarting the app faster for device scan?';
  static const String bodyQuickWhyRestartFasterDeviceScan =
      'Malwirus uses Talsec to detect and monitor device state (e.g., hooks, debuggers, rooted indicators). A full app relaunch forces a fresh initialization of native protections and listeners, which can refresh integrity checks faster than an in‑app background re‑scan.\n\n'
      'Background re‑scan is safe and convenient, but it may take longer since running services and caches are refreshed incrementally.';

  // SMS: enabling scanning
  static const String helpQuickEnableSmsScanning = 'How to enable SMS scanning';
  static const String bodyQuickEnableSmsScanning =
      'To enable SMS scanning, grant the required permissions in Settings and open SMS Security.\n\n'
      'When enabled, incoming messages are analyzed on-device for suspicious links and patterns. You can manage whitelist entries for trusted senders or sites.';

  // SMS: auto link scan
  static const String helpQuickWhatIsAutoLinkScan = 'What is Auto Link Scan?';
  static const String bodyQuickWhatIsAutoLinkScan =
      'Auto Link Scan automatically extracts links from SMS messages and analyzes them for safety.\n\n'
      '- First, the link is checked locally using built-in security patterns.\n'
      '- If it passes local checks, it is then verified with Google Safe Browsing for additional protection.\n\n'
      'If a link is considered risky, you will be warned before opening it.';

  // SMS: manage whitelist
  static const String helpQuickManageSmsWhitelist =
      'How to manage SMS whitelist';
  static const String bodyQuickManageSmsWhitelist =
      'The SMS whitelist lets you exclude trusted numbers from security checks.\n\n'
      '- Messages from numbers on the whitelist will be ignored and not scanned by Malwirus.\n'
      '- You can add numbers from the whitelist screen.\n'
      '- Remove them at any time to restore normal scanning.';

  // SMS: block number
  static const String helpQuickBlockNumber = 'How to block a number in SMS';
  static const String bodyQuickBlockNumber =
      'Open SMS Security on the homescreen and tap "Manage Blocklist" to add a number.\n\n'
      'Messages from numbers in your blocklist will still arrive, but Malwirus will notify you when they are received.\n\n'
      'You can remove numbers from the blocklist at any time from the same screen.';

  // SMS: what happens when blocking a number
  static const String helpQuickWhatHappensWhenBlocking =
      'What does Malwirus do when blocking a number?';
  static const String bodyQuickWhatHappensWhenBlocking =
      'When you add a number to the blocklist, Malwirus will notify you if a call from that number is received.\n\n'
      'Calls are not blocked, but they will be flagged as coming from a blocked caller.\n\n'
      'You can manage or remove numbers from the blocklist at any time.';

  // DNS Filtering overview
  static const String helpQuickUniversalDnsFiltering =
      'What is Universal DNS filtering?';
  static const String bodyQuickUniversalDnsFiltering =
      'Universal DNS Filtering applies protection to all apps on your device.\n\n'
      'Domains are checked against blocklists and your rules; unsafe lookups are blocked before content loads.';

  static const String helpQuickPerAppDnsFiltering =
      'What is Per‑App DNS filtering?';
  static const String bodyQuickPerAppDnsFiltering =
      'Per‑App DNS Filtering lets you choose which apps are protected or exempted.\n\n'
      'This is useful when an app requires specific connections while you still want protection for others.';

  // Privacy and data
  static const String helpQuickDoesSendData = 'Does Malwirus send my data?';
  static const String bodyQuickDoesSendData =
      'Scanning is performed on your device.\n\n'
      'We do not store your message content or browsing data. Only minimal, non‑personal information may be used for functionality (ex. GoogleSafeBrowsingAPiv4).';

  // Help Center: Settings Guide section descriptions (keep it simple)
  static const String settingsGuidePermissionsDesc =
      'Overview of app permissions. Grant notifications, SMS, and phone access so protection and alerts work properly.';
  static const String settingsGuideAutoBlockSpamDesc =
      'Automatically adds suspicious 11‑digit senders to your blocklist to reduce spam without manual work.';
  static const String settingsGuideWhitelistedAppsDesc =
      'Exclude trusted apps from Device Security detections if you are confident they are safe.';
  static const String settingsGuideMonitoringDesc =
      'Shows a persistent notification with live SMS and VPN status. Enable it to keep protections visible.';
  static const String settingsGuideWebStatsDesc =
      'View Web Security counters and tap Reset DNS Stats to clear them.';
  static const String settingsGuideHistoryDeletionDesc =
      'Choose how long to keep security history. Older entries are deleted automatically.';
  static const String settingsGuideShowIntroDesc =
      'Reopen the onboarding screens to quickly revisit how Malwirus works.';
  static const String settingsGuideHelpCenterDesc =
      'Open the Help Center for FAQs, guides, and support options.';
  static const String settingsGuideDataPrivacyDesc =
      'Read a short note explaining that your message content and browsing data are not stored.';

  // Help Center: Device Security Guide
  static const String deviceGuideOverviewSafeTitle = 'Overview: Safe';
  static const String deviceGuideOverviewThreatsTitle = 'Overview: Threats';
  static const String deviceGuideDetectedThreatsTitle = 'Detected threats';
  static const String deviceGuideActionButtonsTitle = 'Action buttons';

  static const String deviceGuideOverviewSafeDesc =
      'Shows the secure state when no risks are found.';
  static const String deviceGuideOverviewThreatsDesc =
      'Shows the at‑risk state when issues need your attention.';
  static const String deviceGuideDetectedThreatsDesc =
      'Lists issues detected by Talsec with their severity.';
  static const String deviceGuideActionButtonsDesc =
      'Quick access to App Installers & Sideloaded Apps and Recommendations.';

  // Help Center: SMS Security Guide
  static const String smsGuideOverviewTitle = 'Overview';
  static const String smsGuideFeatureControlTitle = 'Feature Control';
  static const String smsGuideManageListsTitle = 'Manage Whitelist & Blocklist';

  static const String smsGuideOverviewDesc =
      'Shows scanning status, counts, and a quick summary of SMS protection.';
  static const String smsGuideFeatureControlDesc =
      'Enable SMS scanning, Auto Link Scan, and access other controls.';
  static const String smsGuideManageListsDesc =
      'Add trusted numbers to whitelist or block unwanted callers/senders.';

  // Help Center: Web Security Guide
  static const String webGuideOverviewTitle = 'VPN Overview';
  static const String webGuideBlockingMethodTitle = 'Blocking Method';
  static const String webGuideFeatureControlTitle = 'Feature Control';
  static const String webGuideDnsBlocklistTitle = 'DNS Blocklist';
  static const String webGuideBlockedDomainsTitle = 'Blocked Domains';
  static const String webGuideWhitelistBlocklistTitle = 'Whitelist & Blocklist';

  static const String webGuideOverviewDesc =
      'Start/stop the local VPN to enable domain filtering protection.';
  static const String webGuideBlockingMethodDesc =
      'Choose Universal DNS filtering or Per‑App DNS filters.';
  static const String webGuideFeatureControlDesc =
      'Apply changes live and view connection status.';
  static const String webGuideDnsBlocklistDesc =
      'Manage the list of domains to block through DNS filtering.';
  static const String webGuideBlockedDomainsDesc =
      'See which domains are blocked and manage them as needed.';
  static const String webGuideWhitelistBlocklistDesc =
      'Control allowed/blocked domains for specific needs.';

  // Help Center: Featured articles
  static const String helpArtRealtimeDeviceScanning =
      'Understanding real-time device scanning';
  static const String helpArtBlockedWebsitesWhitelist =
      'Blocked websites and how to whitelist them';
  static const String bodyArtBlockedWebsitesWhitelist =
      'Blocked websites are managed under Web Security > Manage Blocked Domains.\n\n'
      '- If you added a website yourself, you can remove it anytime by tapping the delete button.\n'
      '- If the website is part of the pre-listed protection domains, it cannot be individually whitelisted because it is handled by a secure Bloom filter with over 300,000 entries.\n\n'
      'To allow a site, make sure it is not listed in your custom blocked domains.';

  static const String helpQuickRecommendationAction =
      'Why do some recommendations have quick actions while others do not?';

  static const String bodyQuickRecommendationAction =
      'Some recommendations include a quick action button that can take you directly to the relevant system settings.\n\n'
      'However, not all recommendations can offer this. For certain security checks (such as simulator detection, device binding, secure hardware, or root access), apps are not allowed to open those settings directly.\n\n'
      'In those cases, you will need to review the recommendation and take action manually based on the guidance provided.';

  static const String helpQuickMaliciousApps =
      'What does App Installers & Sideloaded Apps mean in Device Security?';

  static const String bodyQuickMaliciousApps =
      'App Installers & Sideloaded helps identify apps that may be risky based on their installation source.\n\n'
      '\n\n'
      'If you trust a flagged app, you can whitelist it to stop it from appearing in detections.\n\n'
      'To manage whitelisted apps, you can navigate to settings in Home Screen.';

  static const String helpWhyDomainFilterNotWorking =
      'Why isn’t domain filtering blocking websites even though VPN is active?';

  static const String bodyWhyDomainFilterNotWorking =
      'If domain filtering does not seem to work, it may be due to the following reasons:\n\n'
      '1. Per-app filtering is enabled, but the wrong apps were selected. Make sure the apps you want to protect are included.\n\n'
      '2. Secure DNS is still active in your default browser. Malwirus relies on VPN with NXDomain responses to block websites, and it cannot process traffic when Secure DNS is enabled.\n'
      '   - Some browsers, such as Opera, automatically disable Secure DNS when VPN is active, so domain filtering will work correctly there.\n'
      '   - In most other browsers (e.g., Chrome, Firefox, Edge, Brave), Secure DNS can be found under **Settings > Security & Privacy**. You may need to turn it off manually.\n\n'
      'To fix this, adjust your per-app filter list and disable Secure DNS in browsers that keep it enabled.';

  static const String onboardingSkip = 'Skip';
  static const String onboardingExit = 'Exit';
  static const String permissionSettingsHint =
      'You can grant permissions later in system settings for full protection.';

  // Onboarding/Introduction
  static const String onboardingWelcomeTitle = 'Welcome to Malwirus';
  static const String onboardingWelcomeBody =
      'Your Android security companion.';

  // SaaS-oriented intro and per-feature descriptions
  static const String onboardingTitle = 'Malwirus Security';
  static const String onboardingBody =
      'Malwirus delivers device protection with monitoring, cloud-assisted checks, and automatic recommendations, all managed for you.';
  static const String onboardingDeviceBody =
      'Device Integrity checks, malicious app detection, and clear recommendations keep your phone hardened against threats.';
  static const String onboardingSmsBody =
      'Machine Learning-powered SMS scanning extracts text and links to detect phishing, and scams before you tap.';
  static const String onboardingWebBody =
      'Private, on‑device VPN safeguards browsing with DNS filtering, per‑app rules, and customizable blocklists with pre-listed domains.';
  static const String onboardingHistoryTitle = 'Security History';
  static const String onboardingHistoryBody =
      'Review SMS detections and actions. Control or clear data anytime for privacy.';
  static const String onboardingUnderDevTitle = 'Under Development';
  static const String onboardingUnderDevBody =
      'Some features are still being built.';
  static const String onboardingStart = 'Start';

  // Splash screen
  static const String splashBranding = 'Malwirus';
  static const String splashSubtitle = 'Android Security';

  // Home screen
  static const String appName = 'Malwirus';
  static const String scanNow = 'Scan now';
  static const String deviceProtected = 'Your mobile is protected';
  static const String deviceAtRisk = 'Your mobile is at risk';

  // Feature labels
  static const String deviceSecurity = 'Device Security';
  static const String deviceSecurityOptions = 'Device Security Options';
  static const String deviceRescan = 'Rescan';
  static const String deviceRescanTooltip = 'Re-scan device state';
  static const String deviceRescanStarted = 'Re-scan started';
  static const String deviceRescanTriggered = 'Re-scan triggered';
  static const String deviceRescanConfirmTitle = 'Re-scan Device?';
  static const String deviceRescanConfirmBody =
      'Malwirus some time to fully re-scan your device. You can continue using Malwirus while scanning runs in the background.';
  static const String deviceRescanNow = 'Rescan';
  static const String deviceRestartConfirmTitle = 'Restart app to re-scan?';
  static const String deviceRestartConfirmBody =
      'A full app restart is required to accurately re-scan device integrity and malware. Malwirus will close and re-open.';
  static const String deviceRestartNow = 'Restart';
  static const String deviceRestartCancel = 'Cancel';
  static const String deviceRestarting = 'Restarting…';
  static const String deviceScanFinished = 'Device scan is finished.';

  // Rescan choice dialog
  static const String deviceRescanChoiceBody =
      'Re‑scan may take a little time. You can continue using Malwirus while it runs in the background. \n \n Note: relaunching the app can make scanning faster, but it will temporarily stop VPN and monitoring.';
  static const String deviceRescanInBackground = 'Rescan';

  // Common actions
  static const String learnMore = 'Learn more';

  // Manual restart (user relaunch required)
  static const String deviceManualRestartTitle = 'Manual Restart Required';
  static const String deviceManualRestartBody =
      'This will close Malwirus now. Please relaunch the app from your launcher to allow a deep device re-scan.';
  static const String deviceManualRestartNow = 'Close App';

  // Device Security guard
  static const String deviceStateChangedMessage =
      'Device Security detected state changes. Please click Restart to refresh the security scan.';
  static const String devicePrevDevModeKey =
      'device_prev_developer_mode_enabled';
  static const String devicePrevScreenLockKey =
      'device_prev_screen_lock_enabled';
  static const String smsSecurity = 'SMS Security';
  static const String webSecurity = 'Web Security';
  static const String history = 'History';

  // Threat Overview // Home Screen
  static const String threatOverview = 'Device Status';
  static const String threatStatusLow = 'Low';
  static const String threatStatusMedium = 'Medium';
  static const String threatStatusHigh = 'High';
  static const String threatStatusCritical = 'Critical';
  static const String detectedThreats = 'Detected Issues';
  static const String securityStatus = 'Security Status';
  static const String securityFeatures = 'Security Features';

  // Device Security Tab Empty States
  static const String noThreatsDetected = 'No threats detected';
  static const String noSafeChecks = 'No safe checks detected yet';
  static const String pointsLabel = 'Security Points';
  static const String recommendedActions = 'Recommended Actions';
  static const String enabled = 'Enabled';
  static const String disabled = 'Disabled';

  // Malicious Apps
  static const String maliciousApps = 'Sideloaded Apps';
  static const String close = 'Close';
  static const String noSuspiciousApps = 'No suspicious apps detected.';
  static const String reason = 'Reason';
  static const String whitelistDialogMessage =
      'What do you want to do with this app?';
  static const String whitelist = 'Whitelist';
  static const String openAppInfo = 'App Info';
  static const String flaggedByDeviceProtection =
      'Flagged by device protection';

  // Installer-capable apps & trusted installers
  static const String installerAppsTitle = 'Apps that can install other apps';
  static const String installerAppsSubtitle =
      'These apps can install other apps:';
  static const String installerChipsHint =
      'Mark installers you trust. Apps installed by trusted sources will be ignored.';
  static const String untrustedAppsTitle =
      'Apps installed from untrusted sources';
  static const String noInstallerApps = 'No installer-capable apps detected.';
  static const String notFromPlayStore = 'Not installed from Google Play Store';

  // Device Security menu button title
  static const String deviceInstallersButtonTitle =
      'App Installers & Sideloaded Apps';

  // Recommendation
  static const String securityRecommendations = "Recommendations";
  static const String noRecommendations =
      'No recommendations. Your device is secure!';

  // Recommendation details (Home Screen)
  static const String recEnableSms =
      'Enable SMS Security to detect phishing and malicious messages.';
  static const String recEnableWeb =
      'Enable Web Security to protect against unsafe links and domains.';
  static const String recCheckMaliciousApps =
      'Malicious apps detected. Check Device Security > Malicious Apps for details.';
  static const String recCheckDeviceThreats =
      'Device risks detected. Open Device Security to review and resolve.';
  static const String recSmsSuspiciousDetected =
      'Suspicious SMS messages detected. Review details in SMS Security.';
  static const String recDeviceThreatsDetected =
      'Device Security has detected threats. Please resolve the issues.';
  static const String recReviewDetectedIssues =
      'Review and resolve detected issues from the Device Security screen.';
  static const String recOsUpdate =
      'Keep your device updated. Install the latest OS and security patches.';
  static const String recAllGood =
      'Your device is well protected. No action needed.';

  // SharedPreferences keys
  static const String whitelistKey =
      'whitelisted_apps'; // Used for storing whitelisted app package names as JSON array
  static const String onboardingCompletedKey = 'onboarding_completed';

  // Onboarding permission texts (centralized)
  static const String onboardingGrantPermissionsTitle = 'Grant Permissions';
  static const String onboardingGrantPermissionsBody =
      'Allow required permissions to enable real‑time protection and monitoring.';
  static const String onboardingPermissionsNotSatisfied =
      'You have not satisfied the permissions required for the app to function properly.';

  static const String whitelistSuccess = 'App successfully whitelisted.';

  // --- History Retention ---
  static const String retentionPeriod = 'History Deletion Period';
  static const String retentionPeriodDesc =
      'Automatically delete history entry older than your selected period.';
  static const String retention3days = '3 days';
  static const String retention7days = '7 days';
  static const String retention30days = '30 days';
  static const String retentionPickerTitle = 'Keep messages for:';
  static const String retentionChanged = 'History Deletion Period updated.';
  static const String retentionKey = 'history_retention_days';

  static const String featureControl = 'Feature Control';
  static const String webStatsSettings = 'Web Stats';
  static const String resetDnsStats = 'Reset DNS Stats';
  static const String resetDnsStatsDesc = 'Clear Web Security counters.';
  static const String resetDnsDone = 'DNS stats cleared.';

  // --- Persistent Monitoring Notification ---
  static const String monitoringTitle = 'Persistent Notification';
  static const String monitoringDesc =
      'Show ongoing notification with live SMS and VPN status.';
  static const String monitoringEnabled = 'Monitoring enabled';
  static const String monitoringDisabled = 'Monitoring disabled';
  static const String monitoringPermissionNeeded =
      'Notification permission required to start monitoring.';
  static const String monitoringPrefKey = 'monitoring_notification_enabled';
  static const String launchDeviceSecurityAfterRestartKey =
      'launch_device_security_after_restart';

  // Generic toast messages
  static const String failedOpenAppInfo = 'Failed to open app info.';

  // Overall device security state cached from Talsec callbacks
  static const String securityIsSecureKey = 'security_is_secure';

  // --- Settings: Onboarding ---
  static const String settingsShowIntro = 'Show Introduction';
  static const String settingsShowIntroDesc =
      'Display the introduction screen again.';

  // --- SMS Security Screen ---
  static const String smsScanning = 'SMS Scanning';
  static const String smsScanningActiveDesc =
      'Your messages are being scanned for threats';
  static const String smsScanningInactiveDesc =
      'Enable scanning to protect against SMS threats';
  static const String messagesScanned = 'Messages Scanned';
  static const String suspiciousLinks = 'Suspicious Links';
  static const String enableSmsScanning = 'SMS Scanning';
  static const String smsScanDesc =
      'Enabling this option allow malwirus to extract incoming messages.';
  static const String enableAutoLinkScan = 'Auto Link Scan';
  static const String autoLinkScanDesc =
      'Enabling this option allow malwirus to extract links on incoming messages.';
  static const String enableSmsFirstDesc =
      'Enable SMS Scanning first to use this feature.';
  static const String manageWhitelist = 'Manage Whitelist';
  static const String whitelistDesc =
      'Incoming messages from these sources is ignored.';
  static const String whitelistComingSoon =
      'Manage Whitelist feature coming soon';

  // Device Apps Whitelist management (Device Security)
  static const String manageAppWhitelist = 'Manage Whitelisted Apps';
  static const String manageAppWhitelistDesc =
      'Apps you trust will be excluded from detections.';
  static const String whitelistedAppsTitle = 'Whitelisted Apps';
  static const String noWhitelistedApps = 'No whitelisted apps.';

  // Blocklist (Calls) management
  static const String manageBlocklist = 'Manage Blocklist';
  static const String blocklistDesc =
      'Incoming Calls from these numbers will alert user.';

  // Auto-block spam senders (Settings)
  static const String autoBlockSpamSenders = 'Auto-block Spam messages';
  static const String autoBlockSpamSendersDesc =
      'Automatically add spam senders to your blocklist.';

  // Whitelist management
  static const String addWhitelistEntry = 'Add Whitelist Number';
  static const String enterNumber = 'Enter number';
  static const String numberInvalid = 'Invalid number format.';
  static const String noWhitelistedNumbers = 'No whitelisted numbers.';
  static const String delete = 'Delete';
  static const String whitelistEntryExists =
      'This number is already whitelisted.';
  static const String add = 'Add';
  static const String cancel = 'Cancel';
  static const String digits = 'digits';

  // Blocklist sheet strings
  static const String addBlocklistEntry = 'Add Blocklist Number';
  static const String noBlockedNumbers = 'No blocklisted numbers.';
  static const String blocklistEntryExists =
      'This number is already in your blocklist.';

  // Blocklist reason subtitles
  static const String reasonSpamMessageLower = 'reason: spam message';

  // --- History Screen Strings ---
  static const String noHistory = 'No History Entry.';
  static const String errorLoadingHistory = 'Could not load history.';
  static const String clearHistory = 'Clear History';
  static const String clearHistoryConfirm =
      'Are you sure you want to clear all SMS scan history? This action cannot be undone.';
  static const String exportHistory = 'Export History';
  static const String exportComingSoon = 'Export feature coming soon!';
  static const String exportNoHistory = 'No history to export.';
  static const String exportFailed = 'Failed to export history.';
  static const String historyOptions = 'History Options';
  static const String confidence = 'Confidence';
  static const String urlScanResult = 'URL Scan';
  static const String threatInfo = 'Threat Info';
  static const String spam = 'SPAM';
  static const String copyNumber = 'Copy Number';
  static const String copyLink = 'Copy Link';
  static const String addToWhitelist = 'Add to Whitelist';
  static const String removeFromWhitelist = 'Remove from Whitelist';
  static const String addToBlocklist = 'Add to Blocklist';
  static const String removeFromBlocklist = 'Remove from Blocklist';
  static const String copiedToClipboard = 'Copied to clipboard';
  static const String addedToWhitelist = 'Added to whitelist';
  static const String removedFromWhitelist = 'Removed from whitelist';
  static const String addedToBlocklist = 'Added to blocklist';
  static const String removedFromBlocklist = 'Removed from blocklist';
  static const String deleteHistoryEntry = 'Delete History';
  static const String deleteHistoryEntryConfirm = 'Delete this history item?';
  static const String historyEntryDeleted = 'History entry deleted';
  static const String historyCleared = 'History cleared';

  // --- Feature Notes (used by feature note dialog) ---
  // Section headers (reused across features)
  static const String featureNoteWhatData = 'What data it checks';
  static const String featureNoteHowItWorks = 'How it works';
  static const String featureNotePrivacy = 'Your privacy';

  // SMS Security
  static const String featureNoteSmsTitle = 'SMS Security';
  static const String featureNoteSmsData =
      'Only the text of your messages and any links they contain.';
  static const String featureNoteSmsHow =
      'Messages are checked on your phone for signs of scams and risky links. When needed, links are verified with Google Safe Browsing for added safety.';
  static const String featureNoteSmsPrivacy =
      'Your messages are not uploaded. If a link is checked online, only the link is sent for verification—nothing else. Nothing is stored on our servers.';

  // Device Security
  static const String featureNoteDeviceTitle = 'Device Security';
  static const String featureNoteDeviceData =
      'Security signals from your device (for example: root or emulator indicators, debugger status) and a list of installed apps to look for risky installers.';
  static const String featureNoteDeviceHow =
      'Uses Talsec protection to watch your device’s integrity and spot risks. It helps you review suspicious apps and provides clear recommendations.';
  static const String featureNoteDevicePrivacy =
      'No personal files or content are scanned. These checks run on your device and are not uploaded.';

  // Web Security
  static const String featureNoteWebTitle = 'Web Security';
  static const String featureNoteWebData =
      'The website names (domains) your apps try to reach, plus simple protection counters. Page content and searches are not read.';
  static const String featureNoteWebHow =
      'Works through a private, on‑device connection (local VPN). It checks the website names your apps request using DNS (the internet’s address book). If a domain is unsafe, it is blocked by replying with “no address” (like NXDOMAIN), so the connection never starts. You can protect all apps or choose per‑app filters.';
  static const String featureNoteWebPrivacy =
      'Filtering happens on your device. Browsing content is not stored or uploaded. Statistics you see are kept on your phone and can be reset.';
}

// --- Web Security (VPN) Screen Strings ---
class WebStrings {
  static const String title = 'Web Security';
  static const String vpnControls = 'VPN Controls';
  static const String startVpn = 'Start VPN';
  static const String stopVpn = 'Stop VPN';
  static const String blockingMethod = 'Blocking Method';
  static const String addPackage = 'Add Package';
  static const String packageNameHint = 'com.example.app';
  static const String packages = 'Packages';
  static const String dnsBlocklist = 'DNS Blocklist';
  static const String addDomain = 'Add Domain';
  static const String domainHint = 'example.com';

  // Manage (Apps/Domains)
  static const String manageBlockedApps = 'Manage Blocked Apps';

  // New wording: per-app DNS filters management
  static const String manageAppDnsFilters = 'Manage Per-App DNS Filters';
  static const String manageBlockedDomains = 'Manage Blocked Domains';
  static const String noAppsBlocked = 'No apps blocked';

  // New wording for status beneath the tile
  static const String noAppsDnsApplied = 'No apps DNS filter is applied';
  static const String noDomainsBlocked = 'No domains blocked';
  static const String appsBlockedSuffix = 'apps blocked';

  // New suffix for per-app DNS applied count
  static const String appsDnsAppliedSuffix = 'apps DNS filter applied';
  static const String domainsBlockedSuffix = 'domains blocked';
  static const String blockedApps = 'Blocked Apps';
  static const String blockedDomains = 'Blocked Domains';
  static const String addNewApp = 'Add New App';
  static const String addNewDomain = 'Add New Domain';
  static const String enterPackage = 'Enter package name';
  static const String enterDomainName = 'Enter domain';
  static const String selectAppsToBlock = 'Select Apps to Filter';
  static const String searchApps = 'Search apps...';
  static const String loadingApps = 'Loading apps...';
  static const String userApps = 'User Apps';
  static const String systemApps = 'System Apps';
  static const String edit = 'Edit';
  static const String apply = 'Apply';
  static const String saved = 'Saved';
  static const String nothingHere = 'Nothing here yet';
  static const String applyDesc = 'Apply changes to the running VPN (live)';
  static const String status = 'Status';
  static const String vpnReady = 'Ready';
  static const String vpnNotReady = 'Not Ready';
  static const String invalidInput = 'Invalid input';
  static const String noAppsFound = 'No apps found';

  // Status card
  static const String webStats = 'Web Protection Status';
  static const String bytesIn = 'Bytes In';
  static const String bytesOut = 'Bytes Out';
  static const String dnsQueries = 'DNS Queries';
  static const String dnsBlocked = 'DNS Blocked';
  static const String resetCounters = 'Reset Counters';
  static const String connected = 'Connected';
  static const String notConnected = 'Not Connected';
  static const String preparing = 'Preparing…';

  // Universal DNS filtering
  static const String universalDnsFiltering = 'DNS Filtering';
  static const String enableUniversalDns =
      'Malwirus will intercept DNS on All Apllication';
  static const String disableUniversalDns =
      'Disable universal DNS filtering to Manage Per-Apps.';

  // Quick snackbar messages when stopping VPN due to config changes
  static const String vpnStoppingUniversalOff =
      'Universal DNS disabled. Stopping VPN to apply per-app filters.';
  static const String vpnStoppingAppFiltersChanged =
      'Per-app DNS filters changed. Stopping VPN to apply updates.';
  static const String vpnStoppingDnsBlocklistChanged =
      'DNS blocklist changed. Stopping VPN to apply updates.';

  // --- Pre-listed (Bloom) Blocklist ---
  static const String prelistedBlocklistTitle = 'Pre-listed Domains';
  static const String prelistedBlocklistLoading = 'Loading pre-listed Domains…';

  static String prelistedBlocklistApprox(int count) =>
      'Pre-listed Domains: ~${count.toString()}';
}
