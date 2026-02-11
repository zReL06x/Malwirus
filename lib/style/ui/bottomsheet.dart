import 'package:flutter/material.dart';
import '../../style/theme.dart';

/// A reusable blank bottom sheet with a centered, modifiable title and custom content.
class AppBottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? child;
  final List<Widget>? sliverChildren;
  final IconData? icon;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<Widget>? actions;
  final bool showClose;
  final EdgeInsetsGeometry contentPadding;
  final Widget? footer;

  /// If passing a scrollable list, use [sliverChildren]. For a single widget, use [child].
  const AppBottomSheet({
    Key? key,
    required this.title,
    this.subtitle,
    this.child,
    this.sliverChildren,
    this.icon,
    this.initialChildSize = 0.6,
    this.minChildSize = 0.4,
    this.maxChildSize = 1.0,
    this.actions,
    this.showClose = false,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.footer,
  }) : assert(
         child != null || sliverChildren != null,
         'Either child or sliverChildren must be provided.',
       ),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Header: responsive centering with balanced action width and fixed height
                          SizedBox(
                            height: 48.0, // keep header height constant to avoid vertical shift
                            child: Builder(builder: (context) {
                              final int actionCount = (actions?.length ?? 0);
                              const double actionButtonSize = 48.0; // IconButton hit area
                              const double extraEdgePadding = 8.0; // 16 (outer padding) + 8 = 24 to match ListTile contentPadding.trailing
                              final double actionSlotWidth = actionCount > 0
                                  ? (actionButtonSize * actionCount) + extraEdgePadding
                                  : 0.0;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left spacer mirrors right action width to keep title centered
                                  SizedBox(width: actionSlotWidth),
                                  // Centered title with icon
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (icon != null)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: Icon(
                                              icon,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        Flexible(
                                          child: Text(
                                            title,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Actual actions placed on the right with extra padding to align with list trailing
                                  if (actions != null && actions!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: extraEdgePadding),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: actions!,
                                      ),
                                    )
                                  else
                                    SizedBox(width: actionSlotWidth),
                                ],
                              );
                            }),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (sliverChildren != null)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => sliverChildren![index],
                    childCount: sliverChildren!.length,
                  ),
                )
              else if (child != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: contentPadding,
                    child: child!,
                  ),
                ),
              if (footer != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: contentPadding.add(const EdgeInsets.only(bottom: 12.0)),
                    child: footer!,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Usage:
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => AppBottomSheet(
///     title: AppStrings.securityRecommendations,
///     icon: AppIcons.recommendation,
///     child: MyCustomContent(scrollController: ...),
///   ),
/// );
