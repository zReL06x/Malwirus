import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freerasp/freerasp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'device_security_screen.dart';
import 'sms_security_screen.dart';
import 'device_security/threat_notifier.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  // Initialize Flutter binding first for UI rendering and ensure it's completely initialized
  final binding = WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Sync permission states with preferences to keep toggles accurate
  await syncPermissionsWithSettings();
  // Pre-warm rendering pipeline to reduce first frame delay
  binding.scheduleWarmUpFrame();

  // Start the app immediately with splash screen
  runApp(const ProviderScope(child: MyApp()));
  
  // Defer security initialization by a tiny amount to let UI render first
  Future.microtask(() => _initializeSecurityFeatures());
}

/// Syncs actual SMS/Notification permission state with SharedPreferences so toggles in settings are always accurate
Future<void> syncPermissionsWithSettings() async {
  final prefs = await SharedPreferences.getInstance();
  // SMS
  final smsStatus = await Permission.sms.status;
  final bool smsGranted = smsStatus.isGranted;
  final bool smsPref = prefs.getBool('sms_permission') ?? false;
  if (smsGranted != smsPref) {
    await prefs.setBool('sms_permission', smsGranted);
  }
  // Notification
  final notifStatus = await Permission.notification.status;
  final bool notifGranted = notifStatus.isGranted;
  final bool notifPref = prefs.getBool('notification_permission') ?? false;
  if (notifGranted != notifPref) {
    await prefs.setBool('notification_permission', notifGranted);
  }
}

/// Initialize all security features in parallel but with slight delay for UI rendering
Future<void> _initializeSecurityFeatures() async {
  try {
    // Short delay to ensure UI has started rendering first
    await Future.delayed(const Duration(milliseconds: 10));

    // Reset saved state before initializing Talsec (fresh scan)
    await resetThreatStatePrefs();
    
    // Run both initializations concurrently for better performance
    // Use compute isolate for CPU-intensive initialization when possible
    await Future.wait([
      _initializeTalsec(),
      _initializeSmsScanning(),
    ]);
    
    debugPrint('All security features initialized successfully');
  } catch (e) {
    debugPrint('Error initializing security features: $e');
  }
}

/// Initialize Talsec anti-tampering protection
/// Reset persistent threat/malware state before Talsec initializes
Future<void> resetThreatStatePrefs() async {
  await ThreatNotifier.clearStateInPrefs();
}

Future<void> _initializeTalsec() async {
  final config = TalsecConfig(
    androidConfig: AndroidConfig(
      packageName: 'com.zrelxr06.malwirus',
      signingCertHashes: ['M+yvYllZYSxNdDQzuEvU2ged+LKv8taNXrxXodel2NM='],
      supportedStores: [
        'com.android.vending',                     // Google Play Store
        'com.amazon.venezia',                      // Amazon Appstore
        'com.huawei.appmarket',                    // Huawei AppGallery
        'com.sec.android.app.samsungapps',         // Samsung Galaxy Store
        'com.xiaomi.mipicks',                      // Xiaomi GetApps
        'com.oppo.market',                         // OPPO App Market
        'com.vivo.appstore',                       // Vivo App Store
        'com.tencent.android.qqdownloader',        // Tencent MyApp
        'com.baidu.appsearch',                     // Baidu Mobile Assistant
        'com.qihoo.appstore',                      // 360 Mobile Assistant
        'com.lenovo.leos.appstore',                // Lenovo App Store
        'com.meizu.mstore',                        // Meizu App Store
        'com.smartisanos.appstore'                 // Smartisan App Store
      ],
      malwareConfig: MalwareConfig(
        blacklistedPackageNames: [''],
        suspiciousPermissions: [
          ['android.permission.READ_SMS', 'android.permission.READ_CONTACTS'], // Sensitive personal data
          ['android.permission.CAMERA'],                                       // Can be used for spying
          ['android.permission.RECORD_AUDIO'],                                 // Can be used for eavesdropping
          ['android.permission.SYSTEM_ALERT_WINDOW'],                          // Overlay attacks / phishing
        ],
      ),
    ),
    iosConfig: IOSConfig(
      bundleIds: ['com.zrelxr06.malwirus'],
      teamId: 'M8AK35...',
    ),
    watcherMail: 'rpangilinan22-0610@cca.edu.ph',
    isProd: true,
  );

  await Talsec.instance.start(config);
  debugPrint('Talsec initialization completed');
}

/// Initialize SMS security features
Future<void> _initializeSmsScanning() async {
  // Platform channel for native code communication
  const platform = MethodChannel('com.zrelxr06.malwirus/sms_security');
  
  try {
    // Check if SMS scanning is enabled in preferences
    final prefs = await SharedPreferences.getInstance();
    final isScanningEnabled = prefs.getBool('sms_scanning_enabled') ?? true;
    
    if (isScanningEnabled) {
      // Check SMS permission
      final hasPermission = await platform.invokeMethod<bool>('checkSmsPermission') ?? false;
      
      if (hasPermission) {
        // Start SMS scanning
        await platform.invokeMethod('startSmsScanning');
        debugPrint('SMS scanning started successfully');
      } else {
        // Permission will be requested when user opens SMS security screen
        debugPrint('SMS permission not granted yet');
      }
    } else {
      debugPrint('SMS scanning is disabled in preferences');
    }
  } catch (e) {
    debugPrint('Error initializing SMS scanning: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Rethink',
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          color: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontFamily: 'Rethink',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black, fontFamily: 'Rethink'),
          bodyMedium: TextStyle(color: Colors.black, fontFamily: 'Rethink'),
          bodySmall: TextStyle(color: Colors.black, fontFamily: 'Rethink'),
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'Rethink',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          color: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontFamily: 'Rethink',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Rethink'),
          bodyMedium: TextStyle(color: Colors.white, fontFamily: 'Rethink'),
          bodySmall: TextStyle(color: Colors.white, fontFamily: 'Rethink'),
        ),
      ),
      title: 'Malwirus',
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
