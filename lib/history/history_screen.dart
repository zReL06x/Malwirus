import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../channel/platform_channel.dart';
import '../style/theme.dart';
import '../style/icons.dart';
import '../strings.dart';
import '../style/ui/bottomsheet.dart';
import '../style/ui/custom_dialog.dart';

// Dart model matching Kotlin's SmsHistoryEntry
class SmsHistoryEntry {
  final String id;
  final String senderNumber;
  final int timestamp;
  final bool isSpam;
  final bool isSuspicious;
  final double confidence;
  final bool containsUrl;
  final String? url;
  final String urlScanResult;
  final String threatInfo;

  SmsHistoryEntry({
    required this.id,
    required this.senderNumber,
    required this.timestamp,
    required this.isSpam,
    required this.isSuspicious,
    required this.confidence,
    required this.containsUrl,
    required this.url,
    required this.urlScanResult,
    required this.threatInfo,
  });

  factory SmsHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SmsHistoryEntry(
      id: json['id'] ?? '',
      senderNumber: json['senderNumber'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      isSpam: json['isSpam'] ?? false,
      isSuspicious: json['isSuspicious'] ?? false,
      confidence:
          (json['confidence'] is int)
              ? (json['confidence'] as int).toDouble()
              : (json['confidence'] ?? 0.0).toDouble(),
      containsUrl: json['containsUrl'] ?? false,
      url: json['url'],
      urlScanResult: json['urlScanResult']?.toString() ?? '',
      threatInfo: json['threatInfo'] ?? '',
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SmsHistoryEntry> _history = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  int _lastCount = 0;
  int _lastMaxTimestamp = 0;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      final jsonStr = await HistoryPlatformChannel.getSmsHistory();
      final List<dynamic> jsonList = json.decode(jsonStr);
      final entries = jsonList.map((e) => SmsHistoryEntry.fromJson(e)).toList();
      // Apply same retention filter as _fetchHistory
      final prefs = await SharedPreferences.getInstance();
      final retention = prefs.getInt(AppStrings.retentionKey) ?? 3;
      final retentionMillis = Duration(days: retention).inMilliseconds;
      final now = DateTime.now();
      final filtered = entries
          .where((e) => now.millisecondsSinceEpoch - e.timestamp <= retentionMillis)
          .toList();
      final newCount = filtered.length;
      final newMaxTs = filtered.isEmpty
          ? 0
          : filtered.map((e) => e.timestamp).reduce((a, b) => a > b ? a : b);
      if (newCount != _lastCount || newMaxTs != _lastMaxTimestamp) {
        setState(() {
          _history = filtered;
          _loading = false;
          _error = null;
          _lastCount = newCount;
          _lastMaxTimestamp = newMaxTs;
        });
      }
    } catch (_) {
      // ignore transient errors during polling
    }
  }

  Future<void> _showEntryActionSheet(SmsHistoryEntry entry) async {
    final scaffold = ScaffoldMessenger.of(context);
    // Load lists to know toggle state
    final whitelist = await PlatformChannel.getWhitelist();
    final blocklist = await PlatformChannel.getBlocklist();
    final inWhitelist = whitelist.contains(entry.senderNumber);
    final inBlocklist = blocklist.contains(entry.senderNumber);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: Text(AppStrings.copyNumber),
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: entry.senderNumber),
                    );
                    Navigator.pop(context);
                    showAppToast(context, AppStrings.copiedToClipboard);
                  },
                ),
                if (entry.url != null && entry.url!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(AppStrings.copyLink),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: entry.url!));
                      Navigator.pop(context);
                      showAppToast(context, AppStrings.copiedToClipboard);
                    },
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    AppIcons.whitelist,
                    color: inWhitelist ? Theme.of(context).colorScheme.error : null,
                  ),
                  title: Text(
                    inWhitelist
                        ? AppStrings.removeFromWhitelist
                        : AppStrings.addToWhitelist,
                  ),
                  onTap: () async {
                    bool ok;
                    if (inWhitelist) {
                      ok = await PlatformChannel.removeFromWhitelist(
                        entry.senderNumber,
                      );
                    } else {
                      ok = await PlatformChannel.addToWhitelist(
                        entry.senderNumber,
                      );
                    }
                    Navigator.pop(context);
                    if (ok) {
                      showAppToast(
                        context,
                        inWhitelist
                            ? AppStrings.removedFromWhitelist
                            : AppStrings.addedToWhitelist,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    AppIcons.blocklist,
                    color: inBlocklist ? Theme.of(context).colorScheme.error : null,
                  ),
                  title: Text(
                    inBlocklist
                        ? AppStrings.removeFromBlocklist
                        : AppStrings.addToBlocklist,
                  ),
                  onTap: () async {
                    bool ok;
                    if (inBlocklist) {
                      ok = await PlatformChannel.removeFromBlocklist(
                        entry.senderNumber,
                      );
                    } else {
                      ok = await PlatformChannel.addToBlocklist(
                        entry.senderNumber,
                      );
                    }
                    Navigator.pop(context);
                    if (ok) {
                      showAppToast(
                        context,
                        inBlocklist
                            ? AppStrings.removedFromBlocklist
                            : AppStrings.addedToBlocklist,
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(AppStrings.deleteHistoryEntry),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteHistoryEntry(entry);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _deleteHistoryEntry(SmsHistoryEntry entry) async {
    final confirmed = await showCustomDialog(
      context: context,
      title: AppStrings.deleteHistoryEntry,
      message: AppStrings.deleteHistoryEntryConfirm,
      confirmText: AppStrings.delete,
      onConfirm: () => Navigator.of(context).pop(true),
      cancelText: AppStrings.cancel,
      onCancel: () => Navigator.of(context).pop(false),
    );
    if (confirmed == true) {
      try {
        final jsonStr = await HistoryPlatformChannel.getSmsHistory();
        final List<dynamic> list = json.decode(jsonStr);
        list.removeWhere((e) => (e['id'] ?? '') == entry.id);
        await HistoryPlatformChannel.saveSmsHistory(json.encode(list));
        setState(() {
          _history.removeWhere((h) => h.id == entry.id);
        });
        showAppToast(context, AppStrings.historyEntryDeleted);
      } catch (_) {
        // fallback: refresh list
        await _fetchHistory();
      }
    }
  }

  Future<void> _fetchHistory() async {
    // Use current time to compute retention
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final retention = prefs.getInt(AppStrings.retentionKey) ?? 3;
    final retentionMillis = Duration(days: retention).inMilliseconds;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jsonStr = await HistoryPlatformChannel.getSmsHistory();
      final List<dynamic> jsonList = json.decode(jsonStr);
      final entries = jsonList.map((e) => SmsHistoryEntry.fromJson(e)).toList();
      // Filter out expired entries
      final filtered =
          entries
              .where(
                (e) =>
                    now.millisecondsSinceEpoch - e.timestamp <= retentionMillis,
              )
              .toList();
      // If anything is filtered out, update persistent storage
      if (filtered.length != entries.length) {
        // Remove expired entries from storage
        final filteredJson = json.encode(
          filtered
              .map(
                (e) => {
                  'id': e.id,
                  'senderNumber': e.senderNumber,
                  'timestamp': e.timestamp,
                  'isSpam': e.isSpam,
                  'isSuspicious': e.isSuspicious,
                  'confidence': e.confidence,
                  'containsUrl': e.containsUrl,
                  'url': e.url,
                  'urlScanResult': e.urlScanResult,
                  'threatInfo': e.threatInfo,
                },
              )
              .toList(),
        );
        try {
          // Save filtered list back via platform channel
          await HistoryPlatformChannel.saveSmsHistory(filteredJson);
        } catch (_) {}
      }
      setState(() {
        _history = filtered;
        _loading = false;
        _lastCount = filtered.length;
        _lastMaxTimestamp = filtered.isEmpty
            ? 0
            : filtered.map((e) => e.timestamp).reduce((a, b) => a > b ? a : b);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Clear history handler
  Future<void> _clearHistory() async {
    final confirmed = await showCustomDialog(
      context: context,
      title: AppStrings.clearHistory,
      message: AppStrings.clearHistoryConfirm,
      confirmText: AppStrings.clearHistory,
      onConfirm: () => Navigator.of(context).pop(true),
      cancelText: AppStrings.cancel,
      onCancel: () => Navigator.of(context).pop(false),
    );
    if (confirmed == true) {
      await HistoryPlatformChannel.clearSmsHistory();
      await _fetchHistory();
      // Notify user
      if (mounted) {
        showAppToast(context, AppStrings.historyCleared);
      }
    }
  }

  // Export history handler (dummy, implement as needed)
  Future<void> _exportHistory() async {
    try {
      if (_history.isEmpty) {
        showAppToast(context, AppStrings.exportNoHistory);
        return;
      }

      String _xmlEscape(String input) {
        return input
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&apos;');
      }

      final sb = StringBuffer();
      sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      sb.writeln('<history>');
      for (final e in _history) {
        sb.writeln('  <entry>');
        sb.writeln('    <id>${_xmlEscape(e.id)}</id>');
        sb.writeln('    <senderNumber>${_xmlEscape(e.senderNumber)}</senderNumber>');
        sb.writeln('    <timestamp>${e.timestamp}</timestamp>');
        sb.writeln('    <isSpam>${e.isSpam}</isSpam>');
        sb.writeln('    <isSuspicious>${e.isSuspicious}</isSuspicious>');
        sb.writeln('    <confidence>${e.confidence.toStringAsFixed(1)}</confidence>');
        sb.writeln('    <containsUrl>${e.containsUrl}</containsUrl>');
        sb.writeln('    <url>${e.url != null ? _xmlEscape(e.url!) : ''}</url>');
        sb.writeln('    <urlScanResult>${_xmlEscape(e.urlScanResult)}</urlScanResult>');
        sb.writeln('    <threatInfo>${_xmlEscape(e.threatInfo)}</threatInfo>');
        sb.writeln('  </entry>');
      }
      sb.writeln('</history>');

      // Persist to a temporary .xml file to ensure correct extension when sharing
      final Directory tmpDir = await getTemporaryDirectory();
      final String filePath = '${tmpDir.path}/malwirus-history-export.xml';
      final file = File(filePath);
      await file.writeAsString(sb.toString(), flush: true);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/xml', name: 'malwirus-history-export.xml')],
        text: AppStrings.exportHistory,
      );
    } catch (_) {
      showAppToast(context, AppStrings.exportFailed);
    }
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: AppIcons.getIcon(AppIcons.history),
                  title: Text(AppStrings.clearHistory),
                  onTap: () {
                    Navigator.pop(context);
                    _clearHistory();
                  },
                ),
                ListTile(
                  leading: AppIcons.getIcon(Icons.file_download),
                  title: Text(AppStrings.exportHistory),
                  onTap: () {
                    Navigator.pop(context);
                    _exportHistory();
                  },
                ),
              ],
            ),
          ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getConfidenceColor(double confidence, bool isFlagged, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isFlagged) {
      // Suspicious/Spam: higher -> more red
      if (confidence >= 80) return Colors.redAccent;
      if (confidence >= 65) return isDark ? Colors.deepOrangeAccent : Colors.deepOrange;
      return isDark ? Colors.orangeAccent : Colors.orange;
    } else {
      // HAM: higher -> greener
      if (confidence >= 80) return isDark ? Colors.greenAccent : Colors.green;
      if (confidence >= 65) return isDark ? Colors.lightGreenAccent : Colors.lightGreen;
      return isDark ? Colors.tealAccent : Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.history),
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: AppStrings.historyOptions,
            onPressed: _showOptionsSheet,
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: true,
        child:
            _loading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(AppStrings.errorLoadingHistory))
                : _history.isEmpty
                ? Center(child: Text(AppStrings.noHistory))
                : Builder(
                  builder: (context) {
                    final bottomInset = MediaQuery.of(context).padding.bottom;
                    return RefreshIndicator(
                      onRefresh: _fetchHistory,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
                        itemCount: _history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final entry = _history[idx];
                          return _HistoryEntryCard(
                            entry: entry,
                            onLongPress: () => _showEntryActionSheet(entry),
                          );
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }
}

// Widget for displaying a single history entry
class _HistoryEntryCard extends StatelessWidget {
  final SmsHistoryEntry entry;
  final VoidCallback? onLongPress;

  const _HistoryEntryCard({required this.entry, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final confidenceColor =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.orangeAccent
            : Colors.deepOrangeAccent;
    final bool isFlagged = entry.isSpam || entry.isSuspicious;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcons.getIcon(
                    isFlagged ? AppIcons.phone : AppIcons.shieldProtected,
                    color: isFlagged ? Colors.red : Colors.green,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.senderNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isFlagged) ...[
                    SizedBox(width: 12),
                    Container(
                      margin: EdgeInsets.only(right: 12),
                      // Add margin to separate from the date
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppStrings.spam,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    _formatTimestamp(entry.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (entry.url != null && entry.url!.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.link,
                      color: isDark ? Colors.blue[200] : Colors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.url!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.blue[200] : Colors.blue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${AppStrings.confidence}: ',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${entry.confidence.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _getConfidenceColor(
                        entry.confidence,
                        (entry.isSpam || entry.isSuspicious),
                        context,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (entry.url != null && entry.url!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Text(
                      '${AppStrings.urlScanResult}: ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      entry.urlScanResult,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color:
                            entry.urlScanResult == 'SAFE'
                                ? Colors.green
                                : entry.urlScanResult == 'MALICIOUS'
                                ? Colors.red
                                : Colors.orange,
                      ),
                    ),
                  ],
                ],
              ),
              
              if (entry.url != null && entry.url!.isNotEmpty && entry.threatInfo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${AppStrings.threatInfo}:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  entry.threatInfo,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper for formatting timestamp
  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getConfidenceColor(double confidence, bool isFlagged, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isFlagged) {
      if (confidence >= 80) return Colors.redAccent;
      if (confidence >= 65) return isDark ? Colors.deepOrangeAccent : Colors.deepOrange;
      return isDark ? Colors.orangeAccent : Colors.orange;
    } else {
      if (confidence >= 80) return isDark ? Colors.greenAccent : Colors.green;
      if (confidence >= 65) return isDark ? Colors.lightGreenAccent : Colors.lightGreen;
      return isDark ? Colors.tealAccent : Colors.teal;
    }
  }
}

class HistoryPlatformChannel {
  static Future<void> saveSmsHistory(String json) async {
    try {
      await _channel.invokeMethod('saveSmsHistory', {'json': json});
    } catch (e) {
      // ignore
    }
  }

  static const MethodChannel _channel = MethodChannel('malwirus/platform');

  static Future<String> getSmsHistory() async {
    try {
      final String json = await _channel.invokeMethod('getSmsHistory');
      return json;
    } catch (e) {
      return '[]';
    }
  }

  static Future<void> clearSmsHistory() async {
    try {
      await _channel.invokeMethod('clearSmsHistory');
    } catch (e) {
      // ignore
    }
  }
}
