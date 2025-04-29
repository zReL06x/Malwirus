import 'package:flutter/material.dart';

/// Centralized app colors for consistent theming
class AppColors {
  /// Card/item background color for both day and night mode
  static Color cardBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF222222) : const Color(0xFFF7F7F7);
  }
}
