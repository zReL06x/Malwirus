import 'package:flutter/material.dart';
import '../../style/theme.dart';
import '../../style/icons.dart';
import '../../strings.dart';
import '../../channel/platform_channel.dart';

class ManageDnsBottomSheet extends StatefulWidget {
  final List<String> initialItems;
  final bool Function(String) validator;
  final Function(List<String>) onApply;

  const ManageDnsBottomSheet({
    Key? key,
    required this.initialItems,
    required this.validator,
    required this.onApply,
  }) : super(key: key);

  @override
  State<ManageDnsBottomSheet> createState() => _ManageDnsBottomSheetState();
}

class _ManageDnsBottomSheetState extends State<ManageDnsBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _items;
  bool _prelistedEnabled = true;
  int _prelistedApprox = 0;
  bool _prelistedLoaded = false;

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.initialItems);
    _loadPrelistedInfo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPrelistedInfo() async {
    final info = await PlatformChannel.vpnGetPrelistedInfo();
    if (!mounted) return;
    setState(() {
      _prelistedEnabled = (info['enabled'] ?? 1) == 1;
      _prelistedApprox = info['count'] ?? 0;
      _prelistedLoaded = true;
    });
  }

  Future<void> _togglePrelisted(bool enabled) async {
    setState(() => _prelistedEnabled = enabled);
    await PlatformChannel.vpnSetPrelistedEnabled(enabled);
  }

  void _addItem() {
    final text = _controller.text.trim().toLowerCase();
    if (text.isEmpty || !widget.validator(text)) {
      return;
    }
    if (!_items.contains(text)) {
      setState(() => _items.add(text));
      _controller.clear();
      // Auto-apply changes without closing the sheet
      widget.onApply(_items);
    }
  }

  void _removeItem(String item) {
    setState(() => _items.remove(item));
    // Auto-apply changes without closing the sheet
    widget.onApply(_items);
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
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
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
                            Icons.public_off,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              WebStrings.blockedDomains,
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

                    // Pre-listed Bloom toggle and approx count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                            radius: 18,
                            child: Icon(
                              AppIcons.list,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            WebStrings.prelistedBlocklistTitle,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                          ),
                          subtitle: Text(
                            _prelistedApprox > 0
                                ? WebStrings.prelistedBlocklistApprox(_prelistedApprox)
                                : WebStrings.prelistedBlocklistLoading,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          trailing: _prelistedLoaded
                              ? Switch(
                                  value: _prelistedEnabled,
                                  onChanged: (v) => _togglePrelisted(v),
                                )
                              : SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Add new domain section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WebStrings.addNewDomain,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  decoration: InputDecoration(
                                    hintText: WebStrings.domainHint,
                                    prefixIcon: const Icon(Icons.language),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  onSubmitted: (_) => _addItem(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _addItem,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(AppStrings.add),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Domains list
              if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      WebStrings.noDomainsBlocked,
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
                      final item = _items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.public_off,
                              color: AppTheme.primaryColor,
                            ),
                            title: Text(
                              item,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              onPressed: () => _removeItem(item),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _items.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}