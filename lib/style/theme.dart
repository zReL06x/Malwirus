import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Bottom sheet backgrounds
  static const Color sheetBackgroundLight = Colors.white; // Used in: web_security/web_screen.dart (bgColor), style/ui/bottomsheet.dart (AppBottomSheet), web_security/bottomsheet/manage_dns_bottomsheet.dart, web_security/bottomsheet/manage_app_bottomsheet.dart
  static const Color sheetBackgroundDark = Color(0xFF1A1A1A); // Used in: web_security/web_screen.dart (bgColor), style/ui/bottomsheet.dart (AppBottomSheet), web_security/bottomsheet/manage_dns_bottomsheet.dart, web_security/bottomsheet/manage_app_bottomsheet.dart

  // Dialog backgrounds
  static const Color dialogBackgroundLight = Color(0xFFF8F8F8); // Used in: style/ui/custom_dialog.dart via dialogBackground()
  static const Color dialogBackgroundDark = Color(0xFF232323); // Used in: style/ui/custom_dialog.dart via dialogBackground()

  static Color dialogBackground(bool isDark) =>
      isDark ? dialogBackgroundDark : dialogBackgroundLight; // Used in: style/ui/custom_dialog.dart (AlertDialog.backgroundColor)

  // Colors
  static const Color primaryColor = Color(
    0xFFE53935,
  ); // Red color from reference UI | Used widely: main.dart (themes), web_security/web_screen.dart (buttons, avatars, icons), web_security/bottomsheet/manage_dns_bottomsheet.dart (buttons, avatars, icons), web_security/bottomsheet/manage_app_bottomsheet.dart (outlined button colors, switches), style/ui/custom_dialog.dart (confirm button text), settings/settings_screen.dart (section icons)
  static const Color secondaryColor = Color(
    0xFF212121,
  ); // Dark gray for buttons | Currently only within ThemeData.colorScheme.secondary (no direct references found)
  static const Color successGreen = Color(0xFF4CAF50);
  // Used in: web_security/web_screen.dart (VPN status icons/avatars), sms_security/sms_securityScreen.dart (status coloring)

  // Custom app colors for home_screen.dart
  static const Color gradientLightBlue = Color(
    0xFF90CAF9,
  ); // Gradient blue (bottom)
  static const Color featureGridLight = Color(0xFF3FA9FF); // Feature grid light
  static const Color featureGridDark = Color(0xFF1976D2); // Feature grid dark
  // Note: gradientLightBlue/featureGridLight/featureGridDark currently not referenced in searches; keep for future UI or legacy compatibility.

  // New dark mode orange theme colors
  static const Color featureGridOrange = Color(
    0xFFC05600,
  ); // Orange for feature grid/buttons (dark mode)
  static const Color darkAppBarOrange = Color(
    0xFFC05600,
  ); // Orange for app bar (dark mode)
  static const Color gradientOrange = Color(
    0xFFC05600,
  ); // Orange for gradient start (dark mode)
  static const Color gradientOrangeEnd =
      Colors.black; // Black for gradient end (dark mode)
  // Note: featureGridOrange is used in darkTheme.cardTheme; other orange gradient values are not directly referenced elsewhere currently.

  static Color featureIconColor(bool isDark) => Colors.white; // Currently unused; feature icon colors are computed in AppIcons.getFeatureIcon

  // Overview section backgrounds
  static const Color overviewBackgroundLight = Color(
    0xA6FFFFFF,
  ); // White with opacity
  static const Color overviewBackgroundDark = Color(
    0xCC222B36,
  ); // Subtle dark blue

  // Consistent list/button background for light mode
  static const Color listItemLight = Color(0xFFE6E6E6);

  static Color listItemBackground(bool isDark) =>
      isDark ? Colors.grey[900]! : listItemLight; // Used in: web_security/web_screen.dart (listBg)

  // Light theme
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: Colors.white,
      error: Colors.red,
    ),
    cardTheme: CardThemeData(
      color: Color(0xFFE6E6E6),
      // Subtle light gray for cards (matches home_screen)
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(color: Colors.black),
  ); // Applied in: main.dart (MaterialApp.theme)

  // Dark theme
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: featureGridOrange,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: Colors.grey,
      surface: Color(0xFF212121),
      background: Colors.black,
      error: Colors.redAccent,
    ),
    cardTheme: CardThemeData(
      color: featureGridOrange,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkAppBarOrange,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
  ); // Applied in: main.dart (MaterialApp.darkTheme)

  // Builds the System UI overlay style (status/navigation bars) according
  // to current theme brightness. This ensures the Android navigation bar
  // is transparent while keeping icons readable in both modes.
  static SystemUiOverlayStyle systemUiStyleFor(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );
  } // Used in: main.dart (builder -> SystemChrome.setSystemUIOverlayStyle)
}

