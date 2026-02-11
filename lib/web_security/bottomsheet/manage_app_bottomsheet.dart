import 'package:flutter/material.dart';
import 'dart:async';
import '../../style/theme.dart';
import '../../style/icons.dart';
import '../../strings.dart';
import '../../channel/platform_channel.dart';

class ManageAppBottomSheet extends StatefulWidget {
  final List<String> initialItems;
  final bool Function(String) validator;
  final Function(List<String>) onApply;

  const ManageAppBottomSheet({
    Key? key,
    required this.initialItems,
    required this.validator,
    required this.onApply,
  }) : super(key: key);

  @override
  State<ManageAppBottomSheet> createState() => _ManageAppBottomSheetState();
}

enum AppFilter { user, system }

class _ManageAppBottomSheetState extends State<ManageAppBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  late List<String> _blockedApps;
  List<Map<String, String>> _availableApps = [];
  List<Map<String, String>> _filteredApps = [];
  bool _isLoading = true;
  AppFilter _currentFilter = AppFilter.user;
  final Map<AppFilter, List<Map<String, String>>> _appsByType = {};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _blockedApps = List<String>.from(widget.initialItems);
    _loadInstalledApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _currentTypeString() {
    switch (_currentFilter) {
      case AppFilter.user:
        return 'user';
      case AppFilter.system:
        return 'system';
    }
  }

  Future<void> _loadInstalledApps({bool force = false}) async {
    final cached = _appsByType[_currentFilter];
    if (!force && cached != null) {
      setState(() {
        _availableApps = cached;
        _isLoading = false;
      });
      _filterApps();
      return;
    }
    setState(() => _isLoading = true);
    final apps = await PlatformChannel.getInstalledApps(type: _currentTypeString());
    _appsByType[_currentFilter] = apps;
    setState(() {
      _availableApps = apps;
      _isLoading = false;
    });
    _filterApps();
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _availableApps.where((app) {
        final appName = app['appName']?.toLowerCase() ?? '';
        final packageName = app['packageName']?.toLowerCase() ?? '';
        final appType = app['appType'] ?? 'user';
        
        // Apply type filter
        final matchesFilter = switch (_currentFilter) {
          AppFilter.user => appType == 'user',
          AppFilter.system => appType == 'system',
        };
        
        // Apply search filter
        final matchesSearch = query.isEmpty || 
            appName.contains(query) || 
            packageName.contains(query);
        
        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), _filterApps);
  }

  void _toggleFilter() {
    setState(() {
      _currentFilter = switch (_currentFilter) {
        AppFilter.user => AppFilter.system,
        AppFilter.system => AppFilter.user,
      };
    });
    // Load per type with cache; will call _filterApps internally
    _loadInstalledApps();
  }

  String _getFilterLabel() {
    return switch (_currentFilter) {
      AppFilter.user => WebStrings.userApps,
      AppFilter.system => WebStrings.systemApps,
    };
  }

  void _toggleApp(String packageName) {
    setState(() {
      if (_blockedApps.contains(packageName)) {
        _blockedApps.remove(packageName);
      } else {
        _blockedApps.add(packageName);
      }
    });
    // Auto-apply changes without closing the sheet
    widget.onApply(_blockedApps);
  }

  void _removeBlockedApp(String packageName) {
    setState(() => _blockedApps.remove(packageName));
    // Auto-apply changes without closing the sheet
    widget.onApply(_blockedApps);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
                    
                    // Centered title with icon
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.block,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              WebStrings.selectAppsToBlock,
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

                    // Blocked apps chips (if any)
                    if (_blockedApps.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            WebStrings.blockedApps,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Filter toggle and search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Filter toggle button
                          SizedBox(
                            height: 48, // Match TextField height
                            child: OutlinedButton.icon(
                              onPressed: _toggleFilter,
                              icon: Icon(
                                switch (_currentFilter) {
                                  AppFilter.user => Icons.person,
                                  AppFilter.system => Icons.settings,
                                },
                                size: 18,
                              ),
                              label: Text(_getFilterLabel()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: BorderSide(color: AppTheme.primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Search field
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: WebStrings.searchApps,
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onChanged: (_) => _onSearchChanged(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Apps list
              if (_isLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          WebStrings.loadingApps,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredApps.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      WebStrings.noAppsFound,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final app = _filteredApps[index];
                      final packageName = app['packageName'] as String;
                      final appName = app['appName'] as String;
                      final appType = app['appType'] as String? ?? 'user';
                      final isBlocked = _blockedApps.contains(packageName);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              appType == 'system' ? Icons.settings : Icons.apps,
                              color: appType == 'system' 
                                  ? Colors.orange 
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    appName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                                if (appType == 'system')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'SYSTEM',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              packageName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            trailing: Switch(
                              value: isBlocked,
                              onChanged: (_) => _toggleApp(packageName),
                              activeColor: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _filteredApps.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}