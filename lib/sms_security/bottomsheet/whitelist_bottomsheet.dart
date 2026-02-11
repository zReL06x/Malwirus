import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../channel/platform_channel.dart';
import '../../style/ui/bottomsheet.dart';
import '../../style/icons.dart';
import '../../strings.dart';

class WhitelistManagementSheet extends StatefulWidget {
  const WhitelistManagementSheet({Key? key}) : super(key: key);

  @override
  State<WhitelistManagementSheet> createState() =>
      _WhitelistManagementSheetState();
}

class _WhitelistManagementSheetState extends State<WhitelistManagementSheet> {
  List<String> _whitelist = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWhitelist();
  }

  Future<void> _loadWhitelist() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await PlatformChannel.getWhitelist();
      setState(() {
        _whitelist = list;
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
              title: Text(AppStrings.addWhitelistEntry),
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
                            if (_whitelist.any((n) => n == value)) {
                              setStateDialog(() {
                                errorText = AppStrings.whitelistEntryExists;
                              });
                              return;
                            }
                            setStateDialog(() {
                              adding = true;
                            });
                            final ok = await PlatformChannel.addToWhitelist(
                              value,
                            );
                            setStateDialog(() {
                              adding = false;
                            });
                            if (ok) {
                              Navigator.of(context).pop();
                              _loadWhitelist();
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
    final ok = await PlatformChannel.removeFromWhitelist(number);
    if (ok) {
      _loadWhitelist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBottomSheet(
      title: AppStrings.whitelist,
      icon: AppIcons.whitelist,
      actions:
          _whitelist.isNotEmpty
              ? [
                IconButton(
                  tooltip: AppStrings.addWhitelistEntry,
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
            'Error loading whitelist: $_error',
            style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_whitelist.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              AppStrings.noWhitelistedNumbers,
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
            itemCount: _whitelist.length,
            itemBuilder: (context, index) {
              final number = _whitelist[index];
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
        label: Text(AppStrings.addWhitelistEntry),
      ),
    );
  }
}
