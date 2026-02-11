<p align="center">
  <img src="assets/logo/logo_dark.png" alt="Malwirus Logo" width="120"/>
</p>

<h1 align="center">Malwirus</h1>

<p align="center">
  <strong>Your Android Security Companion</strong><br/>
  Real-time device protection, SMS threat detection, and web security — all on-device.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Android"/>
  <img src="https://img.shields.io/badge/Flutter-3.7+-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Kotlin-1.9+-7F52FF?logo=kotlin&logoColor=white" alt="Kotlin"/>
  <img src="https://img.shields.io/badge/Min%20SDK-23-orange" alt="Min SDK 23"/>
  <img src="https://img.shields.io/badge/License-Proprietary-red" alt="License"/>
</p>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
  - [Device Security](#-device-security)
  - [SMS Security](#-sms-security)
  - [Web Security](#-web-security)
  - [Security History](#-security-history)
  - [Home Dashboard](#-home-dashboard)
  - [Settings](#-settings)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Permissions](#permissions)
- [Privacy](#privacy)
- [Contributing](#contributing)

---

## Overview

**Malwirus** is a privacy-first Android security application built with **Flutter** (Dart) for the UI and **Kotlin** for native platform services. It provides three pillars of protection:

1. **Device Security** — Integrity monitoring via Talsec, sideloaded app detection, and actionable recommendations.
2. **SMS Security** — On-device ML-powered spam/phishing detection with Google Safe Browsing link verification.
3. **Web Security** — Local VPN-based DNS filtering with per-app rules, custom blocklists, and a pre-listed Bloom filter containing ~300,000+ known malicious domains.

All scanning and filtering happens **on your device**. No personal data, message content, or browsing history is uploaded to external servers.

---

## Features

### 🛡 Device Security

- **Talsec Integration** — Monitors device integrity in real-time: root/jailbreak detection, emulator detection, debugger attachment, ADB status, developer mode, app integrity, device binding, secure hardware, and screen capture/recording.
- **Sideloaded App Detection** — Identifies apps not installed from Google Play Store, flags untrusted installers, and lets you manage trusted installer sources.
- **App Whitelisting** — Exclude trusted apps from detection to reduce false positives.
- **Security Recommendations** — Context-aware suggestions with quick-action buttons that link directly to relevant Android settings.
- **Re-scan Options** — Background re-scan or full app restart for deep integrity refresh.

### 📱 SMS Security

- **On-Device ML Classification** — Uses an ONNX Runtime model (`malwirus_model.onnx`) to classify incoming SMS messages as spam or legitimate with confidence scores.
- **Auto Link Scan** — Automatically extracts URLs from messages and checks them against:
  - Built-in suspicious URL pattern matching (`SuspiciousUrlPatterns`)
  - Google Safe Browsing API v4 for cloud-assisted verification
- **Whitelist Management** — Exclude trusted sender numbers from scanning.
- **Blocklist Management** — Flag numbers and receive alerts on incoming calls from blocklisted senders.
- **Auto-Block Spam** — Automatically adds suspicious 11-digit senders to the blocklist.
- **Real-Time SMS Receiver** — Background `BroadcastReceiver` processes incoming messages even when the app is closed.
- **Notification Alerts** — Instant notifications for detected threats with quick actions (whitelist, ignore).

### 🌐 Web Security

- **Local VPN DNS Filtering** — Private, on-device VPN intercepts DNS lookups and blocks unsafe domains by responding with NXDOMAIN before the connection starts.
- **Universal DNS Filtering** — Protect all apps on the device with a single toggle.
- **Per-App DNS Filtering** — Choose which specific apps are filtered while exempting others.
- **Custom Domain Blocklist** — Add/remove domains to block manually.
- **Pre-listed Domains (Bloom Filter)** — A compact Bloom filter with ~300,000+ known malicious/phishing/tracker domains for instant local lookups.
- **Live Statistics** — Real-time counters for bytes in/out, DNS queries, and DNS blocks.
- **Live Rule Updates** — Apply blocklist and per-app filter changes to the running VPN without restarting.

### 📜 Security History

- **SMS Scan History** — View detailed logs of scanned messages with sender, timestamp, spam classification, confidence, URL scan results, and threat info.
- **Quick Actions** — Copy number/link, add/remove from whitelist or blocklist, delete individual entries.
- **Export** — Share history as a file for external review.
- **Auto-Cleanup** — Configurable retention period (3, 7, or 30 days) for automatic history deletion.
- **Clear History** — One-tap option to wipe all history data.

### 🏠 Home Dashboard

- **Threat Overview** — Aggregated security score (0–100) with status labels (Safe, Warning, Critical).
- **Real-Time Status** — Live indicators for SMS Security, Web Security, and Device Security states.
- **Detected Issues Counter** — Total threat count across all modules.
- **Recommendations Panel** — Actionable security recommendations based on current protection state.
- **Quick Navigation** — Feature grid for instant access to Device Security, SMS Security, Web Security, and History.

### ⚙ Settings

- **Permissions Management** — Centralized view and control of Notification, SMS, and Phone/Call permissions.
- **Persistent Monitoring Notification** — Foreground service showing live SMS and VPN status in the notification shade.
- **Auto-Block Spam Senders** — Toggle automatic blocklist additions.
- **Whitelisted Apps Management** — Review and remove apps excluded from device security scans.
- **Web Stats & DNS Reset** — View and reset web protection counters.
- **History Deletion Period** — Configure automatic cleanup (3/7/30 days).
- **Help Center** — Searchable FAQs, feature guides, and contact support (email-based).
- **Data Privacy** — Transparency about on-device processing with no data retrieval.
- **Debug Mode** — Session-scoped developer tools (SMS simulation, logcat viewer).
- **Day/Night Mode** — Follows system theme automatically with full light and dark theme support.
- **Onboarding** — Re-viewable introduction screens explaining each feature.

---

## Architecture

Malwirus follows a **hybrid architecture** combining Flutter for the UI layer and Kotlin for performance-critical native services:

```
┌─────────────────────────────────────────────────┐
│                  Flutter (Dart)                  │
│  ┌───────────┐ ┌──────────┐ ┌────────────────┐  │
│  │    UI      │ │  State   │ │  Platform      │  │
│  │  Screens   │ │  Mgmt    │ │  Channel       │  │
│  │  & Widgets │ │ Riverpod │ │  (Bridge)      │  │
│  └───────────┘ └──────────┘ └───────┬────────┘  │
│                                     │            │
├─────────────────────────────────────┼────────────┤
│              MethodChannel          │            │
├─────────────────────────────────────┼────────────┤
│                  Kotlin (Native)    │            │
│  ┌──────────┐ ┌──────────┐ ┌───────▼────────┐   │
│  │ Talsec   │ │   SMS    │ │  VPN Service   │   │
│  │ Security │ │ Processor│ │  DNS Filter    │   │
│  │ Manager  │ │ + ONNX   │ │  Bloom Filter  │   │
│  └──────────┘ └──────────┘ └────────────────┘   │
│  ┌──────────┐ ┌──────────┐ ┌────────────────┐   │
│  │Notifica- │ │Preference│ │   History      │   │
│  │tion Mgr  │ │ Handler  │ │   Handler      │   │
│  └──────────┘ └──────────┘ └────────────────┘   │
└─────────────────────────────────────────────────┘
```

**Key patterns:**
- **Platform Channels** — All Flutter ↔ Kotlin communication goes through a single `MethodChannel` (`malwirus/platform`).
- **Feature-Based Organization** — Code is grouped by feature (device_security, sms_security, web_security), not by file type.
- **On-Device Processing** — ML inference (ONNX), DNS filtering, and URL scanning all run locally.
- **SharedPreferences** — Used for lightweight persistent state (toggles, lists, counters).
- **Foreground Services** — VPN service and monitoring notification run as Android foreground services for reliability.

---

## Project Structure

### Flutter (Dart) — `lib/`

```
lib/
├── channel/
│   └── platform_channel.dart        # MethodChannel bridge to Kotlin
├── device_security/
│   ├── bottomsheet/
│   │   ├── maliciousApps_bottomsheet.dart
│   │   └── recommendation_bottomsheet.dart
│   └── device_securityScreen.dart   # Device integrity & app detection UI
├── history/
│   └── history_screen.dart          # SMS scan history viewer
├── settings/
│   ├── permissions/
│   │   └── permissionHandler.dart   # Permission checks & requests
│   ├── help_center/                 # FAQs and support
│   ├── whitelisted/                 # Whitelisted apps management
│   └── settings_screen.dart         # Settings main layout
├── sms_security/
│   ├── bottomsheet/
│   │   ├── whitelist_bottomsheet.dart
│   │   └── blocklist_bottomsheet.dart
│   └── sms_securityScreen.dart      # SMS scanning controls & stats
├── style/
│   ├── icons.dart                   # Centralized icon definitions
│   ├── theme.dart                   # App-wide theming (light/dark)
│   └── ui/                          # Shared UI components
├── web_security/
│   ├── bottomsheet/
│   │   ├── manage_app_bottomsheet.dart
│   │   └── manage_dns_bottomsheet.dart
│   └── web_screen.dart              # VPN controls & DNS filtering UI
├── home_screen.dart                 # Main dashboard
├── home_screenBottomsheet.dart      # Home screen bottom sheets
├── introduction_screen.dart         # Onboarding flow
├── main.dart                        # App entry point
├── security_status_helper.dart      # Global security score calculations
├── splash_screen.dart               # Splash screen
└── strings.dart                     # All UI strings (centralized)
```

### Kotlin (Native) — `android/.../com/zrelxr06/malwirus/`

```
com.zrelxr06.malwirus/
├── device_security/
│   ├── InstallSourceInspector.kt    # Detects app install sources
│   ├── TalsecApplication.kt        # Talsec SDK initialization
│   ├── TalsecManager.kt            # Threat state management
│   └── TalsecNotifier.kt           # Threat change notifications
├── history/
│   ├── HistoryHandler.kt           # Save/delete history records
│   ├── HistoryManager.kt           # History data access
│   └── SmsHistoryEntry.kt          # History data model
├── notification/
│   ├── action/
│   │   └── NotificationActionHandler.kt  # Notification button actions
│   ├── MonitoringService.kt        # Persistent monitoring foreground service
│   └── NotificationHandler.kt      # Notification creation & management
├── preference/
│   └── PreferenceHandler.kt        # SharedPreferences wrapper
├── sms_security/
│   ├── google/safebrowsing/
│   │   ├── SafeBrowsingClient.kt   # Google Safe Browsing API client
│   │   └── SafeBrowsingService.kt  # Safe Browsing scan service
│   ├── receiver/
│   │   ├── SmsReceiver.kt          # BroadcastReceiver for incoming SMS
│   │   └── CallReceiver.kt         # BroadcastReceiver for incoming calls
│   ├── url/
│   │   ├── SuspiciousUrlPatterns.kt # Centralized URL pattern matching
│   │   └── UrlScanner.kt           # URL extraction & scanning
│   ├── SmsProcessor.kt             # Core SMS analysis pipeline
│   └── SmsModel.kt                 # ONNX Runtime model inference
├── utility/
│   └── NetworkUtils.kt             # Internet connectivity checks
├── web_security/
│   ├── controller/                  # VPN lifecycle control
│   ├── dns/
│   │   └── DnsFilter.kt            # DNS blocklist + Bloom filter
│   ├── model/
│   │   └── Counters.kt             # Traffic/DNS counter model
│   ├── receiver/
│   │   └── RulesUpdateReceiver.kt  # Live rule change handler
│   ├── repository/
│   │   └── RuleRepository.kt       # Persistent rule storage
│   └── service/
│       └── WebSecurityVpnService.kt # VPN foreground service
└── MainActivity.kt                  # Platform channel handler
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **UI Framework** | Flutter 3.7+ / Dart |
| **Native Platform** | Kotlin (Android) |
| **State Management** | Riverpod |
| **ML Inference** | ONNX Runtime Android 1.15.1 |
| **Device Security** | Talsec Security Community 16.0.1 |
| **Link Verification** | Google Safe Browsing API v4 |
| **DNS Filtering** | Custom VPN Service with Bloom filter |
| **Persistence** | SharedPreferences |
| **JSON Parsing** | Gson 2.10.1 |
| **Animations** | Lottie / DotLottie |
| **Onboarding** | introduction_screen |
| **Sharing** | share_plus / path_provider |
| **Notifications** | Android NotificationManager + Foreground Services |

---

## Prerequisites

- **Flutter SDK** 3.7.2 or higher
- **Dart SDK** 3.7.2 or higher
- **Android Studio** with Kotlin support
- **Android SDK** — Min SDK 23 (Android 6.0), Target SDK as per Flutter defaults
- **NDK** 27.0.12077973
- **Java 11** (for Kotlin compilation)
- **Google Safe Browsing API Key** (for cloud-assisted link scanning — see [Setup](#getting-started))

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/your-username/Malwirus.git
cd Malwirus
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Configure API Keys

Create or update the Google Safe Browsing API key in the appropriate configuration file. The key is used by `SafeBrowsingClient.kt` for URL verification.

> **Note:** The app functions without the API key — local pattern matching still works. The API key enables cloud-assisted link verification as an additional layer.

### 4. Configure Signing (Release builds)

Create a `key.properties` file in the `android/` directory:

```properties
storeFile=path/to/your/keystore.jks
storePassword=your_store_password
keyAlias=your_key_alias
keyPassword=your_key_password
```

### 5. Run the app

```bash
flutter run
```

### 6. Build Release APK

```bash
flutter build apk --release
```

---

## Permissions

Malwirus requests the following permissions, each clearly explained to the user during onboarding:

| Permission | Purpose |
|-----------|---------|
| `INTERNET` | Google Safe Browsing API lookups and DNS resolution |
| `READ_SMS` / `RECEIVE_SMS` | Scan incoming SMS messages for threats |
| `POST_NOTIFICATIONS` | Alert users about detected threats and monitoring status |
| `FOREGROUND_SERVICE` | Keep VPN and monitoring services running reliably |
| `READ_PHONE_STATE` / `READ_CALL_LOG` | Detect incoming calls from blocklisted numbers |
| `ACCESS_NETWORK_STATE` | Check internet connectivity before network requests |
| `BIND_VPN_SERVICE` | Local DNS filtering via Android VPN API |

All permissions are requested gracefully with clear explanations. The app functions with reduced capabilities if some permissions are denied.

---

## Privacy

Malwirus is built with a **privacy-first** approach:

- **On-device ML inference** — SMS classification runs entirely on your phone using ONNX Runtime. No message content is uploaded.
- **Local DNS filtering** — The VPN processes DNS lookups on-device. Browsing content is never stored or transmitted.
- **Minimal cloud usage** — Only URLs flagged locally are optionally verified via Google Safe Browsing API v4 (only the URL is sent, nothing else).
- **No telemetry** — The app does not collect analytics, usage data, or personal information.
- **User-controlled history** — All scan history is stored locally and can be cleared or auto-deleted at any time.
- **Transparent data handling** — A Data Privacy section in Settings explains exactly what data is and isn't processed.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add your feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

Please follow the existing code conventions:
- Group code by feature, not by file type
- Use centralized theme and icons from `lib/style/`
- Store all UI strings in `lib/strings.dart`
- Use `SharedPreferences` for simple persistent data
- Separate logic from UI — use handlers/services for background work
- Support both light and dark themes

---

<p align="center">
  <strong>Malwirus</strong> — Android Security, On Your Terms.
</p>
