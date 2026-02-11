import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'style/theme.dart';
import 'home_screen.dart';
import 'device_security/device_securityScreen.dart';
import 'introduction_screen.dart';
import 'strings.dart';

class SplashArt extends StatefulWidget {
  const SplashArt({super.key});

  @override
  State<SplashArt> createState() => _SplashArtState();
}

class _SplashArtState extends State<SplashArt> {
  @override
  void initState() {
    super.initState();
    // Remove the native splash screen after a short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      FlutterNativeSplash.remove();
    });

    // Navigate based on onboarding completion after a delay
    Future.delayed(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted =
          prefs.getBool(AppStrings.onboardingCompletedKey) ?? false;
      if (!mounted) return;
      // If onboarding not completed, show intro first
      if (!isCompleted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const IntroductionScreenTemplate(),
          ),
        );
        return;
      }

      // Otherwise go to Home. Any post-restart deep-linking to Device Security
      // will be handled by HomeScreen in its initState to avoid using a
      // disposed Splash context.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Force check system brightness to ensure proper theme
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final logoAsset =
        isDark ? 'assets/logo/logo_light.png' : 'assets/logo/logo_dark.png';
    // Switch Android logo based on theme - light logo in dark mode and dark logo in light mode
    final androidLogoAsset =
        isDark
            ? 'assets/logo/android_light.png'
            : 'assets/logo/android_dark.png';

    // Get appropriate background color based on brightness
    // Dark mode matches the onboarding dark background; light mode is full white
    final backgroundColor = isDark ? AppTheme.sheetBackgroundDark : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Main content area (centered) takes most of the space
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Image.asset(
                      logoAsset,
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    // SpinKit animation - white in dark mode, black in light mode
                    SpinKitDancingSquare(
                      color: isDark ? Colors.white : Colors.black,
                      size: 40.0,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom branding area
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Branding text
                  Text(
                    AppStrings.splashBranding,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Subtitle and Android logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.splashSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Image.asset(
                        androidLogoAsset,
                        width: 12,
                        height: 12,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
