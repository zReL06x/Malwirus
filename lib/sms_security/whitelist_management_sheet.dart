import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import '../theme/app_colors.dart';

class WhitelistManagementSheet extends StatefulWidget {
  const WhitelistManagementSheet({Key? key}) : super(key: key);

  @override
  State<WhitelistManagementSheet> createState() => _WhitelistManagementSheetState();
}

class _WhitelistManagementSheetState extends State<WhitelistManagementSheet> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _whitelistedNumbers = [];
  bool _isLoading = true;

  // Platform channel for native code communication
  static const platform = MethodChannel('com.zrelxr06.malwirus/sms_security');

  @override
  void initState() {
    super.initState();
    _loadWhitelistedNumbers();
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  // Load whitelisted numbers from native code
  Future<void> _loadWhitelistedNumbers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final whitelist = await platform.invokeMethod<List<dynamic>>('getWhitelistedNumbers');
      if (whitelist != null) {
        final formattedList = whitelist.map((item) {
          if (item is Map) {
            return {
              'number': item['number']?.toString() ?? '',
              'dateAdded': item['dateAdded'] is int ? item['dateAdded'] : DateTime.now().millisecondsSinceEpoch
            };
          }
          return <String, dynamic>{};
        }).toList();
        
        setState(() {
          _whitelistedNumbers = formattedList.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error loading whitelisted numbers: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add a number to the whitelist
  Future<void> _addToWhitelist(String number) async {
    try {
      // Check if number is exactly 11 digits
      final digitsOnly = number.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (digitsOnly.length != 11) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number must be 11 digits'))
        );
        return;
      }
      
      // Format the number (we're now using digits only)
      final formattedNumber = digitsOnly;
      
      // Check if number already exists in whitelist
      if (_whitelistedNumbers.any((item) => item['number'] == formattedNumber)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This number is already in the whitelist'))
        );
        return;
      }
      
      await platform.invokeMethod('addToWhitelist', {'number': formattedNumber});
      _phoneNumberController.clear();
      
      // Instead of reloading from native code, add the number to the local list
      setState(() {
        _whitelistedNumbers.add({
          'number': formattedNumber,
          'dateAdded': DateTime.now().millisecondsSinceEpoch
        });
      });
    } catch (e) {
      debugPrint('Error adding to whitelist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding number: ${e.toString()}'))
      );
    }
  }

  // Remove a number from the whitelist
  Future<void> _removeFromWhitelist(String number) async {
    try {
      await platform.invokeMethod('removeFromWhitelist', {'number': number});
      
      // Update local list instead of reloading from native code
      setState(() {
        _whitelistedNumbers.removeWhere((item) => item['number'] == number);
      });
    } catch (e) {
      debugPrint('Error removing from whitelist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing number: ${e.toString()}'))
      );
    }
  }

  // Format a timestamp to a readable date
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Manage Whitelist',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              
              // Add new number form
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneNumberController,
                          decoration: InputDecoration(
                            hintText: 'Enter phone number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            helperText: '11 digits only',
                            helperStyle: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a phone number';
                            }
                            if (value.length != 11) {
                              return 'Phone number must be 11 digits';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _addToWhitelist(_phoneNumberController.text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34C759),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Divider
              Divider(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
              ),
              
              // Whitelisted numbers list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _whitelistedNumbers.isEmpty
                        ? Center(
                            child: Text(
                              'No whitelisted numbers yet',
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _whitelistedNumbers.length,
                            separatorBuilder: (context, index) => Divider(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                            ),
                            itemBuilder: (context, index) {
                              final number = _whitelistedNumbers[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  number['number'],
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  'Added on ${_formatDate(number['dateAdded'])}',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removeFromWhitelist(number['number']),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
