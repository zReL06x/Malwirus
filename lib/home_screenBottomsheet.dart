import 'package:flutter/material.dart';
import 'package:malwirus/style/ui/bottomsheet.dart';
import 'style/icons.dart';
import 'style/theme.dart';
import 'strings.dart';

Widget RecommendationButton(
  BuildContext context, {
  required List<String> recommendations,
  required bool hasThreats,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final Color bgColor =
      isDark
          ? AppTheme.featureGridDark.withOpacity(0.08)
          : AppTheme.featureGridLight.withOpacity(0.08);
  final Color iconColor = AppTheme.primaryColor;

  // Use provided recommendations list
  final bool hasRecommendations = recommendations.isNotEmpty;
  final String label =
      hasThreats || hasRecommendations
          ? '${AppStrings.securityRecommendations}: Tap to see more.'
          : 'No Recommended Action.';

  void showRecommendationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => AppBottomSheet(
            title: AppStrings.securityRecommendations,
            icon: AppIcons.recommendation,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child:
                  hasRecommendations
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...recommendations.map(
                            (rec) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      rec,
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                      : hasThreats
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Threats detected but no specific recommendations available. Please review your device security settings.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      )
                      : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            AppIcons.recommendation,
                            color: iconColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No Recommended Action.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
    );
  }

  // Remove button animation by using Material + InkWell with no splash/highlight
  return SizedBox(
    height: 48,
    width: double.infinity,
    child: Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: showRecommendationsSheet,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 12),
            Icon(AppIcons.recommendation, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

