import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sms_security/sms_history_screen.dart';
import 'sms_security/whitelist_management_sheet.dart';
import 'theme/app_colors.dart';

// SMS Security Screen - Implements the UI for SMS security features
class SmsSecurityScreen extends ConsumerStatefulWidget {
  const SmsSecurityScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SmsSecurityScreen> createState() => _SmsSecurityScreenState();
}

class _SmsSecurityScreenState extends ConsumerState<SmsSecurityScreen> {
  // State variables
  bool _isSmsScanning = false;
  bool _isLinkScanning = false;
  int _messagesScanned = 0;
  int _suspiciousLinksFound = 0;
  List<Map<String, dynamic>> _whitelistedNumbers = [];
  bool _isLoading = true;

  // Platform channel for native code communication
  static const platform = MethodChannel('com.zrelxr06.malwirus/sms_security');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load data from native code
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check SMS permission
      final hasPermission = await platform.invokeMethod<bool>('checkSmsPermission') ?? false;
      
      if (hasPermission) {
        // Get SMS stats
        final stats = await platform.invokeMethod<Map<dynamic, dynamic>>('getSmsStats');
        if (stats != null) {
          setState(() {
            _isSmsScanning = stats['isEnabled'] as bool;
            _messagesScanned = stats['messagesScanned'] as int;
            _suspiciousLinksFound = stats['suspiciousLinksFound'] as int;
          });
        }

        // Get whitelist
        final whitelist = await platform.invokeMethod<List<dynamic>>('getWhitelistedNumbers');
        if (whitelist != null) {
          setState(() {
            _whitelistedNumbers = whitelist.cast<Map<String, dynamic>>();
          });
        }

        // Get preferences
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _isLinkScanning = prefs.getBool('link_scanning_enabled') ?? true;
        });
      } else {
        // Request permission if not granted
        await platform.invokeMethod('requestSmsPermission');
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Toggle SMS scanning with confirmation dialog when disabling
  Future<void> _toggleSmsScanning(bool value) async {
    try {
      if (value) {
        // Enable scanning - no confirmation needed
        final success = await platform.invokeMethod<bool>('startSmsScanning') ?? false;
        if (success) {
          setState(() {
            _isSmsScanning = true;
          });
        }
        
        // Save preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('sms_scanning_enabled', value);
      } else {
        // Show confirmation dialog when disabling
        final confirmed = await _showDisableConfirmationDialog(
          'Disable SMS Scanning?',
          'Disabling SMS scanning will stop protection against spam and phishing messages. Are you sure you want to disable this feature?'
        );
        
        if (confirmed) {
          await platform.invokeMethod('stopSmsScanning');
          
          // When turning off SMS scanning, also turn off link scanning
          bool wasLinkScanningEnabled = _isLinkScanning;
          setState(() {
            _isSmsScanning = false;
            // Auto-disable link scanning when SMS scanning is disabled
            _isLinkScanning = false;
          });
          
          // Save SMS scanning preference
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('sms_scanning_enabled', value);
          
          // If link scanning was enabled, also update its preferences
          if (wasLinkScanningEnabled) {
            await prefs.setBool('link_scanning_enabled', false);
            // Communicate with native code to update Kotlin preference
            await platform.invokeMethod('setLinkScanningEnabled', {'enabled': false});
            debugPrint('Auto-disabled link scanning because SMS scanning was turned off');
          }
        } else {
          // User canceled, revert the switch
          setState(() {
            _isSmsScanning = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling SMS scanning: $e');
    }
  }

  // Toggle link scanning with confirmation dialog when disabling
  Future<void> _toggleLinkScanning(bool value) async {
    try {
      if (value) {
        // Enable scanning - no confirmation needed
        setState(() {
          _isLinkScanning = value;
        });
        
        // Save preference in multiple stores to ensure synchronization
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('link_scanning_enabled', value);
        
        // Communicate with native code to update Kotlin preference
        await platform.invokeMethod('setLinkScanningEnabled', {'enabled': value});
      } else {
        // Show confirmation dialog when disabling
        final confirmed = await _showDisableConfirmationDialog(
          'Disable Link Scanning?',
          'Disabling link scanning will stop protection against malicious URLs in messages. Are you sure you want to disable this feature?'
        );
        
        if (confirmed) {
          setState(() {
            _isLinkScanning = value;
          });
          
          // Save preference in multiple stores to ensure synchronization
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('link_scanning_enabled', value);
          
          // Communicate with native code to update Kotlin preference
          await platform.invokeMethod('setLinkScanningEnabled', {'enabled': value});
        } else {
          // User canceled, revert the switch
          setState(() {
            _isLinkScanning = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling link scanning: $e');
    }
  }
  
  // Show confirmation dialog when disabling a security feature
  Future<bool> _showDisableConfirmationDialog(String title, String message) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground(context),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF34C759),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Disable'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Build the SMS Security Status Card
  Widget _buildStatusCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isSmsScanning ? const Color(0xFF34C759) : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMS Scanning: ${_isSmsScanning ? "Enabled" : "Disabled"}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSmsScanning
                          ? 'Your messages are being scanned for threats'
                          : 'Enable scanning to protect against SMS threats',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  isDarkMode,
                  Icons.message,
                  _messagesScanned.toString(),
                  'Messages Scanned',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem(
                  isDarkMode,
                  Icons.warning,
                  _suspiciousLinksFound.toString(),
                  'Suspicious Links',
                  isWarning: _suspiciousLinksFound > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build a stat item for the status card
  Widget _buildStatItem(bool isDarkMode, IconData icon, String value, String label,
      {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isWarning
                    ? Colors.orange
                    : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isWarning
                  ? Colors.orange
                  : (isDarkMode ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // Build the Feature Control Panel
  Widget _buildFeatureControlPanel(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feature Control',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          // Toggle Message Scanning
          _buildToggleOption(
            isDarkMode,
            'Enable SMS Scanning',
            'Scans incoming messages and extracts text for ML-based threat detection.',
            _isSmsScanning,
            _toggleSmsScanning,
          ),
          const Divider(),
          // Toggle Auto Link Scanning - disabled if SMS scanning is off
          _buildToggleOption(
            isDarkMode,
            'Enable Auto Link Scan',
            _isSmsScanning
                ? 'Scans all SMS messages for embedded links and checks them against a threat database.'
                : 'Enable SMS Scanning first to use this feature.',
            _isLinkScanning,
            _isSmsScanning ? _toggleLinkScanning : null,
          ),
          const Divider(),
          // Whitelist Management Button
          InkWell(
            onTap: () => _showWhitelistManagement(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: const Color(0xFF34C759),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Whitelist',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Messages from these sources won\'t be flagged.',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build a toggle option for the feature control panel
  Widget _buildToggleOption(bool isDarkMode, String title, String description,
      bool value, Function(bool)? onChanged) {
    final bool isEnabled = onChanged != null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isEnabled 
                        ? (isDarkMode ? Colors.white : Colors.black)
                        : (isDarkMode ? Colors.grey[500] : Colors.grey[400]),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: isEnabled ? onChanged : null,
            activeColor: const Color(0xFF34C759),
            inactiveThumbColor: isDarkMode
                ? (isEnabled ? Colors.grey[300] : Colors.grey[700])
                : (isEnabled ? Colors.grey[400] : Colors.grey[300]),
            inactiveTrackColor: isDarkMode
                ? (isEnabled ? Colors.grey[800] : Colors.grey[900])
                : (isEnabled ? Colors.grey[300] : Colors.grey[200]),
          ),
        ],
      ),
    );
  }

  // Build the History Button
  Widget _buildHistoryButton(bool isDarkMode) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SmsHistoryScreen(),
        ),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardBackground(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.history,
                color: Color(0xFF34C759),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View Scan History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'See detected threats and scan results',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  // Show Whitelist Management Dialog
  void _showWhitelistManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => const WhitelistManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'SMS Security',
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SMS Security Status Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12.0),
                    child: _buildStatusCard(isDarkMode),
                  ),
                  // Feature Control Panel
                  Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12.0),
                    child: _buildFeatureControlPanel(isDarkMode),
                  ),
                  // History Button
                  Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12.0),
                    child: _buildHistoryButton(isDarkMode),
                  ),
                ],
              ),
            ),
    );
  }
}
