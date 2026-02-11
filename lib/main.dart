import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'style/theme.dart';
import 'strings.dart';
import 'channel/platform_channel.dart';
import 'settings/permissions/permissionHandler.dart';

Future<void> main() async {
  // Initialize Flutter binding first for UI rendering and ensure it's completely initialized
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Preserve the splash screen until fully loaded
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Enable edge-to-edge so system status/navigation bars can be transparent
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Pre-warm rendering pipeline to reduce first frame delay
  binding.scheduleWarmUpFrame();
  // Start the app with a standard ProviderScope
  runApp(const ProviderScope(child: MyApp()));

  // Ensure persistent monitoring notification per user pref
  Future.microtask(() => _ensureMonitoringOnStart());
  // Guard VPN state on cold start to avoid stale "Stop VPN" when not actually running
  Future.microtask(() => _ensureVpnConsistencyOnStart());
}

/// Ensures VPN state is consistent on app start.
/// If native service isn't running but any stored state suggests it is,
/// we trigger a reconciliation on the platform side and optionally send a
/// stop signal to guarantee "vpn_active" is false.
Future<void> _ensureVpnConsistencyOnStart() async {
  try {
    // Short delay to let platform initialize SharedPreferences
    await Future.delayed(const Duration(milliseconds: 50));
    final active = await PlatformChannel.vpnIsActive();
    if (!active) {
      // Best-effort: issue a stop to ensure background state is fully reset
      await PlatformChannel.vpnStop();
    }
  } catch (e) {
    debugPrint('VPN consistency guard failed: $e');
  }
}

/// Ensures the persistent monitoring notification is running on app start
/// when the user has the setting enabled, even after process death or reboot.
Future<void> _ensureMonitoringOnStart() async {
  try {
    // Short delay to avoid racing with OS setup
    await Future.delayed(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    final prefOn = prefs.getBool(AppStrings.monitoringPrefKey) ?? false;
    if (!prefOn) return;

    final active = await PlatformChannel.monitoringIsActive();
    if (active) return;

    // Only start if notification permission is granted
    bool granted = PermissionHandler.notificationGranted.value == true;
    if (!granted) {
      await PermissionHandler.refreshPermissions();
      granted = PermissionHandler.notificationGranted.value == true;
    }
    if (granted) {
      await PlatformChannel.monitoringStart();
    }
  } catch (e) {
    debugPrint('Monitoring start guard failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      // Follows system theme setting
      builder: (context, child) {
        // Keep system bars transparent and icons visible based on theme
        final brightness = Theme.of(context).brightness;
        SystemChrome.setSystemUIOverlayStyle(
          AppTheme.systemUiStyleFor(brightness),
        );
        // Add a global bottom inset equal to the system navigation bar height
        // so that floating controls (e.g., Next buttons) are not obscured when
        // using edge-to-edge with a transparent navigation bar. When the
        // keyboard is open, we don't add this extra spacing.
        final mq = MediaQuery.of(context);
        final keyboardOpen = mq.viewInsets.bottom > 0;
        final bottomInset = keyboardOpen ? 0.0 : mq.viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: child!,
        );
      },
      home: const SplashArt(),
    );
  }
}
