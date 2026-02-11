---
trigger: always_on
---

lib
├── channel
│ └── platform_channel.dart // Dart side of Platform Channel (communicates with Kotlin)
├── device_security
│ ├── bottomsheet
│ │ ├── maliciousApps_bottomsheet.dart // Displays detected malicious apps
│ │ └── recommendation_bottomsheet.dart // Shows security recommendations using
DraggableScrollableSheet
│ ├── TalsecApplication
│ │ └── threat_notifier.dart // Monitors and notifies device security threats via Talsec
│ └── device_securityScreen.dart // Main UI for device security overview
├── history
│ └── history_screen.dart // Main UI for displaying SMS and web history
├── settings
│ ├── permissions
│ │ └── permissionHandler.dart // Handles permission checks and requests
│ └── settings_screen.dart // Settings main layout and logic
├── sms_security
│ ├── bottomsheet
│ │ └── whitelist_bottomsheet.dart // UI for managing SMS whitelist (add/delete entries)
│ └── sms_securityScreen.dart // Main screen for SMS analysis and results
├── style
│ ├── icons.dart // Defines reusable icon widgets
│ └── theme.dart // Centralized theming and app styling
├── web_security
│ └── web_screen.dart // Main screen for web threat monitoring and display
├── home_screen.dart // Landing screen (main navigation entry)
├── main.dart // App entry point; initializes core services
├── splash_screen.dart // Splash screen shown during app startup
└── strings.dart // Strings that will be used on this entire project.

