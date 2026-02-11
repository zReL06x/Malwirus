---
trigger: always_on
---

com.zrelxr06.malwirus
├── data
│   ├── history
│   │   ├── sms_security
│   │   │   └── SmsHistoryEntry               // Represents SMS security history entries
│   │   ├── web_security
│   │   │   └── WebHistoryEntry               // Represents web security history entries
│   │   └── HistoryHandler                    // Handles saving and deleting history records
│   ├── notification
│   │   ├── action
│   │   │   └── NotificationActionHandler     // Handles user actions triggered from notifications
│   │   └── NotificationHandler               // Manages system and custom notifications
│   ├── preference
│   │   └── PreferenceHandler                 // Manages app preferences and persistent settings
│   ├── sms_security
│   │   ├── google.safebrowsing
│   │   │   ├── SafeBrowsingClient.kt        // Handles interaction with Google Safe Browsing API
│   │   │   └── SafeBrowsingService          // Provides Safe Browsing scanning services
│   │   ├── receiver
│   │   │   └── smsReceiver                   // Triggered when an SMS is received
│   │   ├── url
│   │   │   ├── SuspiciousUrlPatterns        // Stores patterns used to detect malicious URLs
│   │   │   └── UrlScanner                   // Extracts and scans URLs in SMS messages
│   │   ├── SmsProcessor.kt                  // Main processor for analyzing incoming SMS content
│   │   └── SmsModel                         // Loads ONNX model for spam/malware detection
│   └── utility
│       └── NetworkUtils                     // Utility to check internet connectivity
└── MainActivity                              // Kotlin entry point; communicates with Flutter via Platform Channel
