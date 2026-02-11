import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'style/theme.dart';
import 'style/icons.dart';
import 'strings.dart';
import 'home_screen.dart';
import 'settings/permissions/permissionHandler.dart';
import 'package:lottie/lottie.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'style/ui/custom_dialog.dart';

/// Permission request widget for onboarding
class PermissionsRequestWidget extends StatefulWidget {
  final VoidCallback? onPermissionsChanged;

  const PermissionsRequestWidget({Key? key, this.onPermissionsChanged})
    : super(key: key);

  @override
  PermissionsRequestWidgetState createState() =>
      PermissionsRequestWidgetState();
}

class PermissionsRequestWidgetState extends State<PermissionsRequestWidget>
    with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _smsGranted = false;
  bool _loadingNotif = false;
  bool _loadingSms = false;
  bool _phoneGranted = false;
  bool _loadingPhone = false;

  bool get allGranted => _notifGranted && _smsGranted && _phoneGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _loadingNotif = true;
      _loadingSms = true;
      _loadingPhone = true;
    });
    final notif = await PermissionHandler.isNotificationPermissionGranted();
    final sms = await PermissionHandler.isSmsPermissionGranted();
    final phone = await PermissionHandler.isPhonePermissionGranted();
    setState(() {
      _notifGranted = notif;
      _smsGranted = sms;
      _phoneGranted = phone;
      _loadingNotif = false;
      _loadingSms = false;
      _loadingPhone = false;
    });
    widget.onPermissionsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.padding.vertical;
    final isSmall = availableHeight < 740;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(AppIcons.settings, size: 56, color: theme.colorScheme.primary),
        SizedBox(height: isSmall ? 16 : 24),
        Text(
          AppStrings.onboardingGrantPermissionsTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.onboardingGrantPermissionsBody,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isSmall ? 20 : 28),
        Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(16),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    AppIcons.notification,
                    color: theme.iconTheme.color,
                  ),
                  title: Text(
                    AppStrings.notificationPermission,
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: Text(AppStrings.permissionSettingsHint),
                  trailing:
                      _notifGranted
                          ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                          : Icon(
                            Icons.info_outline,
                            color: theme.disabledColor,
                          ),
                  onTap:
                      _loadingNotif || _notifGranted
                          ? null
                          : () async {
                            setState(() => _loadingNotif = true);
                            final granted =
                                await PermissionHandler.requestNotificationPermission();
                            setState(() {
                              _notifGranted = granted;
                              _loadingNotif = false;
                            });
                          },
                  enabled: !_notifGranted,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
                ListTile(
                  leading: Icon(
                    AppIcons.smsSecurity,
                    color: theme.iconTheme.color,
                  ),
                  title: Text(
                    AppStrings.smsPermission,
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: Text(AppStrings.smsScanDesc),
                  trailing:
                      _smsGranted
                          ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                          : Icon(
                            Icons.info_outline,
                            color: theme.disabledColor,
                          ),
                  onTap:
                      _loadingSms || _smsGranted
                          ? null
                          : () async {
                            setState(() => _loadingSms = true);
                            final granted =
                                await PermissionHandler.requestSmsPermission();
                            setState(() {
                              _smsGranted = granted;
                              _loadingSms = false;
                            });
                          },
                  enabled: !_smsGranted,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
                ListTile(
                  leading: Icon(AppIcons.phone, color: theme.iconTheme.color),
                  title: Text(
                    AppStrings.phonePermission,
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: Text(AppStrings.phonePermissionDesc),
                  trailing:
                      _phoneGranted
                          ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                          : Icon(
                            Icons.info_outline,
                            color: theme.disabledColor,
                          ),
                  onTap:
                      _loadingPhone || _phoneGranted
                          ? null
                          : () async {
                            setState(() => _loadingPhone = true);
                            final granted =
                                await PermissionHandler.requestPhonePermission();
                            setState(() {
                              _phoneGranted = granted;
                              _loadingPhone = false;
                            });
                          },
                  enabled: !_phoneGranted,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics:
            isSmall
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: content,
      ),
    );
  }
}

/// A template onboarding/introduction screen using introduction_screen package.
/// Strings and icons are centralized for maintainability.
final GlobalKey<PermissionsRequestWidgetState> permissionsKey = GlobalKey();

class IntroductionScreenTemplate extends StatefulWidget {
  const IntroductionScreenTemplate({Key? key}) : super(key: key);

  @override
  State<IntroductionScreenTemplate> createState() =>
      _IntroductionScreenTemplateState();
}

class _IntroductionScreenTemplateState
    extends State<IntroductionScreenTemplate> {
  int _currentPage = 0;

  // Welcome page logo (adaptive to theme)
  Widget _welcomeLogo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;
    final double h = (screenH * 0.48).clamp(220.0, 460.0);
    final String asset =
        isDark ? 'assets/logo/logo_light.png' : 'assets/logo/logo_dark.png';
    return Center(child: Image.asset(asset, height: h, fit: BoxFit.contain));
  }

  // Helper to render .lottie container with graceful fallback
  Widget _dotLottie(
    BuildContext context,
    String assetPath,
    IconData fallbackIcon,
  ) {
    final screenH = MediaQuery.of(context).size.height;
    final double h = (screenH * 0.48).clamp(
      220.0,
      460.0,
    ); // Larger presence with sensible bounds
    return Center(
      child: DotLottieLoader.fromAsset(
        assetPath,
        frameBuilder: (context, dot) {
          if (dot == null) {
            return Icon(
              fallbackIcon,
              size: 56,
              color: Theme.of(context).iconTheme.color,
            );
          }
          final bytes =
              dot.animations.values.isNotEmpty
                  ? dot.animations.values.first
                  : null;
          if (bytes == null) {
            return Icon(
              fallbackIcon,
              size: 56,
              color: Theme.of(context).iconTheme.color,
            );
          }
          return Lottie.memory(bytes, height: h, fit: BoxFit.contain);
        },
        errorBuilder:
            (context, error, stack) => Icon(
              fallbackIcon,
              size: 56,
              color: Theme.of(context).iconTheme.color,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;
    // Transparent navigation bar with correct icon brightness
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
    // Build pages list to compute length dynamically
    final pages = <PageViewModel>[
      // Welcome page
      PageViewModel(
        title: AppStrings.onboardingWelcomeTitle,
        body: AppStrings.onboardingWelcomeBody,
        image: _welcomeLogo(context),
        decoration: PageDecoration(
          titleTextStyle: Theme.of(context).textTheme.titleLarge!,
          bodyTextStyle: Theme.of(context).textTheme.bodyMedium!,
          imageFlex: 4,
          bodyFlex: 1,
        ),
      ),
      // SaaS positioning (Malwirus Security)
      PageViewModel(
        title: AppStrings.onboardingTitle,
        body: AppStrings.onboardingBody,
        image: _dotLottie(
          context,
          'assets/lottie-animation/malwirus-security.lottie',
          AppIcons.securityFeature,
        ),
        decoration: PageDecoration(
          titleTextStyle: Theme.of(context).textTheme.titleLarge!,
          bodyTextStyle: Theme.of(context).textTheme.bodyMedium!,
          imageFlex: 4,
          bodyFlex: 1,
        ),
      ),
      // Device Security
      PageViewModel(
        title: AppStrings.deviceSecurity,
        body: AppStrings.onboardingDeviceBody,
        image: _dotLottie(
          context,
          'assets/lottie-animation/device-security.lottie',
          AppIcons.deviceSecurity,
        ),
        decoration: PageDecoration(
          titleTextStyle: Theme.of(context).textTheme.titleLarge!,
          bodyTextStyle: Theme.of(context).textTheme.bodyMedium!,
          imageFlex: 4,
          bodyFlex: 1,
        ),
      ),
      // SMS Security
      PageViewModel(
        title: AppStrings.smsSecurity,
        body: AppStrings.onboardingSmsBody,
        image: _dotLottie(
          context,
          'assets/lottie-animation/sms-security.lottie',
          AppIcons.smsSecurity,
        ),
        decoration: PageDecoration(
          titleTextStyle: Theme.of(context).textTheme.titleLarge!,
          bodyTextStyle: Theme.of(context).textTheme.bodyMedium!,
          imageFlex: 4,
          bodyFlex: 1,
        ),
      ),
      // Web Security
      PageViewModel(
        title: AppStrings.webSecurity,
        body: AppStrings.onboardingWebBody,
        image: _dotLottie(
          context,
          'assets/lottie-animation/web-security.lottie',
          AppIcons.webSecurity,
        ),
        decoration: PageDecoration(
          titleTextStyle: Theme.of(context).textTheme.titleLarge!,
          bodyTextStyle: Theme.of(context).textTheme.bodyMedium!,
          imageFlex: 4,
          bodyFlex: 1,
        ),
      ),
      // History
      PageViewModel(
        title: AppStrings.onboardingHistoryTitle,
        body: AppStrings.onboardingHistoryBody,
        image: _dotLottie(
          context,
          'assets/lottie-animation/history.lottie',
          AppIcons.history,
        ),
        decoration: PageDecoration(
          titleTextStyle: Theme.of(context).textTheme.titleLarge!,
          bodyTextStyle: Theme.of(context).textTheme.bodyMedium!,
          imageFlex: 4,
          bodyFlex: 1,
        ),
      ),
      // Permissions page (last)
      PageViewModel(
        title: '',
        bodyWidget: PermissionsRequestWidget(
          key: permissionsKey,
          onPermissionsChanged: () => setState(() {}),
        ),
        image: const SizedBox.shrink(),
        // Allow package-level scroll; inner widget disables scrolling on medium-large screens
        useScrollView: true,
        decoration: PageDecoration(
          contentMargin: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          titlePadding: EdgeInsets.zero,
          imageFlex: 1,
          bodyFlex: 0,
        ),
      ),
    ];
    return IntroductionScreen(
      globalBackgroundColor:
          isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight,
      pages: pages,
      // Make controls more compact to prevent overflow on borderline heights
      controlsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      showBackButton: true,
      skip:
          _currentPage == pages.length - 1
              ? const SizedBox.shrink()
              : TextButton(
                onPressed: null, // Default skip advances one page
                child: Text(
                  AppStrings.onboardingSkip,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
      back: AppIcons.getIcon(Icons.arrow_back),
      next: AppIcons.getIcon(Icons.arrow_forward),
      done: Builder(
        builder: (context) {
          final isEnabled = permissionsKey.currentState?.allGranted ?? false;
          final enabledColor = AppTheme.primaryColor;
          return Text(
            AppStrings.onboardingStart,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isEnabled ? enabledColor : Colors.grey,
            ),
          );
        },
      ),
      onDone: () async {
        final isEnabled = permissionsKey.currentState?.allGranted ?? false;
        if (!isEnabled) {
          showAppToast(
            context,
            AppStrings.onboardingPermissionsNotSatisfied,
            duration: const Duration(seconds: 3),
          );
          return;
        }
        // Mark onboarding as completed
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(AppStrings.onboardingCompletedKey, true);
        } catch (_) {}
        // Clear the entire back stack so Home becomes the root and no back button is shown.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      },
      showSkipButton: true,
      showNextButton: true,
      dotsDecorator: DotsDecorator(
        activeColor: AppTheme.primaryColor,
        color: isDark ? Colors.white30 : Colors.black26,
        size: const Size(6.0, 6.0),
        activeSize: const Size(12.0, 6.0),
        spacing: const EdgeInsets.symmetric(horizontal: 4.0),
      ),
      onChange: (index) {
        setState(() {
          _currentPage = index;
        });
      },
    );
  }
}
