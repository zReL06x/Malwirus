import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:malwirus/theme/app_colors.dart';

class SmsHistoryScreen extends StatefulWidget {
  const SmsHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SmsHistoryScreen> createState() => _SmsHistoryScreenState();
}

class _SmsHistoryScreenState extends State<SmsHistoryScreen> {
  // Filter state
  String? _selectedStatus = 'All';
  String? _selectedCategory = 'All';

  // Delete a history entry (by id)
  Future<void> _deleteHistoryEntry(Map<String, dynamic> entry) async {
    try {
      await platform.invokeMethod('deleteSmsHistoryEntry', {
        'id': entry['id'],
      });
      setState(() {
        _historyEntries.removeWhere((e) => e['id'] == entry['id']);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History entry deleted')),
      );
    } catch (e) {
      debugPrint('Error deleting history entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete entry')),
      );
    }
  }

  // Capitalizes the first letter of a string
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  List<Map<String, dynamic>> _historyEntries = [];
  bool _isLoading = true;

  // Platform channel for native code communication
  static const platform = MethodChannel('com.zrelxr06.malwirus/sms_security');

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Load SMS history from native code
  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await platform.invokeMethod<List<dynamic>>('getSmsHistory');
      if (history != null) {
        setState(() {
          // Convert each map properly to avoid type casting issues
          _historyEntries = history.map((item) {
            final map = Map<String, dynamic>.from({});
            if (item is Map) {
              item.forEach((key, value) {
                if (key is String) {
                  map[key] = value;
                }
              });
            }
            return map;
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading SMS history: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Format a timestamp to a readable date and time
  String _formatDateTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }
  
  // Get detailed status text based on URL scan result
  String _getStatusText(Map<String, dynamic> entry) {
    final urlScanResult = entry['urlScanResult'] as String? ?? 'UNKNOWN';
    final threatInfo = entry['threatInfo'] as String? ?? '';

    // Determine if the result is from local analysis
    final isLocalAnalysis = threatInfo.toLowerCase().contains("random character sequence") ||
        threatInfo.toLowerCase().contains("suspicious domain") ||
        threatInfo.toLowerCase().contains("top-level domain") ||
        threatInfo.toLowerCase().contains("direct ip address") ||
        threatInfo.toLowerCase().contains("hexadecimal ip address") ||
        threatInfo.toLowerCase().contains("url shortener");

    String getSourceLabel() => isLocalAnalysis ? "Local Analysis" : "SafeBrowsing";

    switch (urlScanResult) {
      case 'MALICIOUS':
        if (threatInfo.isNotEmpty) {
          // Use threatInfo as the reason, no source or prefix inside
          // Remove any existing (Local Analysis) or (SafeBrowsing) from the reason to avoid duplication
          final cleanReason = threatInfo.replaceAll(RegExp(r'\s*\((Local Analysis|SafeBrowsing)\)', caseSensitive: false), '');
          return 'Link Status: Malicious - Reason: ${_capitalizeFirst(cleanReason.trim())} (${getSourceLabel()})';
        }
        return 'Link Status: Malicious (${getSourceLabel()})';
        
      case 'SAFE':
        return 'Link Status: Safe (${getSourceLabel()})';
        
      case 'ERROR':
        return 'Link Status: Scan error - unable to verify';
        
      case 'NOT_SCANNED':
        // Check if there's a reason in the threat info, like scanning being disabled
        if (threatInfo.toLowerCase().contains("link scanning is disabled")) {
          return 'Link Status: Not scanned (Link scanning is disabled)';
        }
        return 'Link Status: Not scanned';
        
      case 'UNKNOWN':
      default:
        if (!entry['containsUrl']) {
          return 'Link Status: No URL detected';
        }
        return 'Link Status: Not scanned';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Deduplicate history entries by senderNumber+url before displaying
    final List<Map<String, dynamic>> dedupedEntries = () {
      final map = <String, Map<String, dynamic>>{};
      for (final entry in _historyEntries) {
        final key = '${entry['senderNumber']}_${entry['url']}';
        if (!map.containsKey(key)) {
          map[key] = entry;
        }
      }
      return map.values.toList();
    }();

    // Filtering controls
    final List<String> statusFilters = ['All', 'Safe', 'Malicious', 'Error', 'Not Scanned'];
    final List<String> categoryFilters = ['All', 'Spam', 'Suspicious'];
    String selectedStatus = _selectedStatus ?? 'All';
    String selectedCategory = _selectedCategory ?? 'All';

    List<Map<String, dynamic>> filteredEntries = dedupedEntries.where((entry) {
      final urlScanResult = (entry['urlScanResult'] ?? '').toString().toUpperCase();
      final isSpam = entry['isSpam'] as bool;
      final confidence = entry['confidence'] as double;
      String messageCategory;
      if (isSpam && confidence > 80) {
        messageCategory = 'Spam';
      } else if (confidence >= 50) {
        messageCategory = 'Suspicious';
      } else {
        messageCategory = 'Ham';
      }
      bool statusMatch = selectedStatus == 'All' ||
        (selectedStatus == 'Safe' && urlScanResult == 'SAFE') ||
        (selectedStatus == 'Malicious' && urlScanResult == 'MALICIOUS') ||
        (selectedStatus == 'Error' && urlScanResult == 'ERROR') ||
        (selectedStatus == 'Not Scanned' && (urlScanResult == 'NOT_SCANNED' || urlScanResult == 'UNKNOWN'));
      bool categoryMatch = selectedCategory == 'All' || messageCategory == selectedCategory;
      return statusMatch && categoryMatch;
    }).toList();

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'SMS Scan History',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No scan history yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Detected threats will appear here',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Builder(
                  builder: (context) => Column(
                    children: [
                    // Filtering controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          // Status filter
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedStatus ?? 'All',
                              onChanged: (value) {
                                setState(() => _selectedStatus = value);
                              },
                              items: statusFilters.map((filter) => DropdownMenuItem(
                                value: filter,
                                child: Text('Link Status: $filter'),
                              )).toList(),
                              isExpanded: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Category filter
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedCategory ?? 'All',
                              onChanged: (value) {
                                setState(() => _selectedCategory = value);
                              },
                              items: categoryFilters.map((filter) => DropdownMenuItem(
                                value: filter,
                                child: Text('Category: $filter'),
                              )).toList(),
                              isExpanded: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = filteredEntries[index];
                            final isSpam = entry['isSpam'] as bool;
                            final isSuspicious = entry.containsKey('isSuspicious') ? entry['isSuspicious'] as bool : false;
                            final confidence = entry['confidence'] as double;
                            final containsUrl = entry['containsUrl'] as bool;
                            final urlScanResult = entry['urlScanResult'] as String;
                            // Determine message category based on confidence level
                            // Ham: < 50%, Suspicious: 50-80%, Spam: > 80%
                            final String messageCategory;
                            if (isSpam && confidence > 80) {
                              messageCategory = 'Spam';
                            } else if (confidence >= 50) {
                              messageCategory = 'Suspicious';
                            } else {
                              messageCategory = 'Ham';
                            }
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: AppColors.cardBackground(context),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header with timestamp and status
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDateTime(entry['timestamp'] as int),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: messageCategory == 'Spam'
                                                ? Colors.red.withOpacity(0.1)
                                                : (messageCategory == 'Suspicious' 
                                                    ? Colors.orange.withOpacity(0.1)
                                                    : const Color(0xFF34C759).withOpacity(0.1)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            messageCategory,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: messageCategory == 'Spam'
                                                  ? Colors.red
                                                  : (messageCategory == 'Suspicious'
                                                      ? Colors.orange
                                                      : const Color(0xFF34C759)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Sender number
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 16,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'From: ${entry['senderNumber']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Confidence
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.analytics_outlined,
                                          size: 16,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Confidence: ${confidence.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // URL information if present
                                    if (containsUrl) ...[
                                      const SizedBox(height: 8),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.link,
                                            size: 16,
                                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'URL: ${entry['url']}',
                                              style: TextStyle(
                                                color: isDarkMode ? Colors.white : Colors.black,
                                              ),
                                              softWrap: true,
                                              maxLines: null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            urlScanResult == 'MALICIOUS'
                                                ? Icons.warning_amber_rounded
                                                : urlScanResult == 'SAFE'
                                                    ? Icons.check_circle_outline
                                                    : urlScanResult == 'ERROR'
                                                        ? Icons.error_outline
                                                        : Icons.info_outline,
                                            size: 16,
                                            color: urlScanResult == 'MALICIOUS'
                                                ? Colors.orange
                                                : urlScanResult == 'SAFE'
                                                    ? const Color(0xFF34C759)
                                                    : urlScanResult == 'ERROR'
                                                        ? Colors.red
                                                        : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _getStatusText(entry),
                                              style: TextStyle(
                                                color: urlScanResult == 'MALICIOUS'
                                                    ? Colors.orange
                                                    : urlScanResult == 'SAFE'
                                                        ? const Color(0xFF34C759)
                                                        : urlScanResult == 'ERROR'
                                                            ? Colors.red
                                                            : (isDarkMode ? Colors.white : Colors.black),
                                                fontWeight: urlScanResult == 'MALICIOUS' || urlScanResult == 'ERROR'
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              softWrap: true,
                                              maxLines: null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    
                                    // Actions
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            // Add to whitelist
                                            platform.invokeMethod('addToWhitelist', {
                                              'number': entry['senderNumber'],
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Number added to whitelist'),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.shield_outlined,
                                            size: 16,
                                            color: Color(0xFF34C759),
                                          ),
                                          label: const Text(
                                            'Whitelist',
                                            style: TextStyle(
                                              color: Color(0xFF34C759),
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, color: isDarkMode ? Colors.red[300] : Colors.red[400]),
                                          tooltip: 'Delete entry',
                                          onPressed: () async {
                                            await _deleteHistoryEntry(entry);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
    ),
    );
    },
    ),
    ),
    ),
    ],
    ),
    )
    );
  }
}
