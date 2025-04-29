import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'device_security_screen.dart';
import 'sms_security_screen.dart';
import 'settings_screen.dart';
import 'home_screen_permission_helper.dart';
import 'theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _lastScanDate = 'Never';

  @override
  void initState() {
    super.initState();
    // Request notification permission automatically on first run
    Future.microtask(() {
      requestNotificationPermissionIfNeeded(context);
    });
    // Initialize with a placeholder date
    _updateLastScanDate(DateTime.now().subtract(const Duration(days: 1)));

    // Automatically perform a security scan when the app starts
    // Use a small delay to ensure the UI is built
    Future.delayed(const Duration(milliseconds: 500), () {
      _performInitialScan();
    });
  }

  void _updateLastScanDate(DateTime date) {
    setState(() {
      _lastScanDate = DateFormat('dd/MM/yyyy').format(date);
    });
  }

  void _performInitialScan() {
    // Update last scan date
    _updateLastScanDate(DateTime.now());

    // In a real app, this would perform actual security checks
    // No toast message in main activity
  }

  void _performScan() {
    // Update last scan date only
    _updateLastScanDate(DateTime.now());
    
    // Show scan complete message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scan feature coming soon'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF34C759),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text(
          'Malwirus',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Open settings screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Loading animation
              Expanded(
                flex: 3,
                child: Center(
                  child: DotLottieLoader.fromAsset(
                    'assets/animations/scanning_animation.lottie',
                    frameBuilder: (BuildContext ctx, DotLottie? dotlottie) {
                      if (dotlottie != null) {
                        return Lottie.memory(
                          dotlottie.animations.values.single,
                          width: 180,
                          height: 180,
                          delegates: LottieDelegates(
                            values: [
                              ValueDelegate.color(
                                const ['Rectangle', 'bottom-grad', 'top-grad', 'full', 'trans'],
                                value: const Color(0xFF34C759)
                              )
                            ]
                          )
                        );
                      } else {
                        return const SizedBox.shrink(); // Empty widget instead of icon
                      }
                    },
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(), // Empty widget on error
                  ),
                ),
              ),

              // Last scan date
              Text(
                'Last scan: $_lastScanDate',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),

              // Scan button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _performScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'SCAN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Security options grid
              Expanded(
                flex: 4,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        // Top row
                        Expanded(
                          child: Row(
                            children: [
                              // Top-left: Device Security
                              Expanded(
                                child: _buildSecurityOption(
                                  icon: Icons.shield,
                                  title: 'DEVICE SECURITY',
                                  color: const Color(0xFF34C759),
                                  onTap: () {
                                    // Navigate to device security screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const DeviceSecurityScreen(),
                                      ),
                                    );
                                  },
                                  position: 0,
                                ),
                              ),
                              // Vertical divider
                              Container(
                                width: 1,
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                              ),
                              // Top-right: Web Security
                              Expanded(
                                child: _buildSecurityOption(
                                  icon: Icons.language,
                                  title: 'WEB SECURITY',
                                  color: const Color(0xFF34C759),
                                  onTap: () {
                                    // Show a placeholder message for future implementation
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Web Security feature coming soon'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  position: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Horizontal divider
                        Container(
                          height: 1,
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                        ),
                        // Bottom row
                        Expanded(
                          child: Row(
                            children: [
                              // Bottom-left: SMS Security
                              Expanded(
                                child: _buildSecurityOption(
                                  icon: Icons.chat,
                                  title: 'SMS SECURITY',
                                  color: const Color(0xFF34C759),
                                  onTap: () {
                                    // Navigate to SMS security screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SmsSecurityScreen(),
                                      ),
                                    );
                                  },
                                  position: 2,
                                ),
                              ),
                              // Vertical divider
                              Container(
                                width: 1,
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                              ),
                              // Bottom-right: History
                              Expanded(
                                child: _buildSecurityOption(
                                  icon: Icons.history,
                                  title: 'HISTORY',
                                  color: const Color(0xFF34C759),
                                  onTap: () {
                                    // Show a placeholder message for future implementation
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('History feature coming soon'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  position: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required int position,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: AppColors.cardBackground(context),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: const Color(0xFF34C759),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
