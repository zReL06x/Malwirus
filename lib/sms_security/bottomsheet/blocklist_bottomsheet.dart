import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../channel/platform_channel.dart';
import '../../style/ui/bottomsheet.dart';
import '../../style/icons.dart';
import '../../strings.dart';

class BlocklistManagementSheet extends StatefulWidget {
  const BlocklistManagementSheet({Key? key}) : super(key: key);

  @override
  State<BlocklistManagementSheet> createState() =>
      _BlocklistManagementSheetState();
}

class _BlocklistManagementSheetState extends State<BlocklistManagementSheet> {
  List<String> _blocklist = [];
  bool _loading = true;
  String? _error;
  Map<String, String> _reasons = {};

  @override
  void initState() {
    super.initState();
    _loadBlocklist();
  }

  Future<void> _loadBlocklist() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await PlatformChannel.getBlocklist();
      final reasons = await PlatformChannel.getBlocklistReasons();
      setState(() {
        _blocklist = list;
        _reasons = reasons;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addEntryDialog() async {
    final controller = TextEditingController();
    String? errorText;
    bool adding = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            int digitCount() => controller.text.length;
            return AlertDialog(
              title: Text(AppStrings.addBlocklistEntry),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: AppStrings.enterNumber,
                      errorText: errorText,
                      counterText: '${digitCount()}/11 ${AppStrings.digits}',
                    ),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                  if (adding)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppStrings.cancel),
                ),
                TextButton(
                  onPressed:
                      adding
                          ? null
                          : () async {
                            final value = controller.text.trim();
                            // Accept only numeric, exactly 11 digits
                            if (!RegExp(r'^[0-9]{11}$').hasMatch(value)) {
                              setStateDialog(() {
                                errorText = AppStrings.numberInvalid;
                              });
                              return;
                            }
                            if (_blocklist.any((n) => n == value)) {
                              setStateDialog(() {
                                errorText = AppStrings.blocklistEntryExists;
                              });
                              return;
                            }
                            setStateDialog(() {
                              adding = true;
                            });
                            final ok = await PlatformChannel.addToBlocklist(
                              value,
                            );
                            setStateDialog(() {
                              adding = false;
                            });
                            if (ok) {
                              Navigator.of(context).pop();
                              _loadBlocklist();
                            } else {
                              setStateDialog(() {
                                errorText = AppStrings.numberInvalid;
                              });
                            }
                          },
                  child: Text(AppStrings.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEntry(String number) async {
    final ok = await PlatformChannel.removeFromBlocklist(number);
    if (ok) {
      _loadBlocklist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBottomSheet(
      title: AppStrings.manageBlocklist,
      icon: AppIcons.blocklist,
      actions:
          _blocklist.isNotEmpty
              ? [
                IconButton(
                  tooltip: AppStrings.addBlocklistEntry,
                  onPressed: _addEntryDialog,
                  icon: const Icon(Icons.add),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 78,
                    height: 78,
                  ),
                ),
              ]
              : null,
      child: _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Error loading blocklist: $_error',
            style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_blocklist.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              AppStrings.noBlockedNumbers,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildAddButton(),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 100, maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _blocklist.length,
            itemBuilder: (context, index) {
              final number = _blocklist[index];
              final reason = _reasons[number];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                leading: Icon(
                  AppIcons.phone,
                  color: isDark ? Colors.white : Colors.black,
                ),
                title: Text(
                  number,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle:
                    (reason == 'spam')
                        ? Text(
                          AppStrings.reasonSpamMessageLower,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        )
                        : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: isDark ? Colors.red[300] : Colors.red[700],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  onPressed: () => _deleteEntry(number),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: _addEntryDialog,
        icon: const Icon(Icons.add),
        label: Text(AppStrings.addBlocklistEntry),
      ),
    );
  }
}
