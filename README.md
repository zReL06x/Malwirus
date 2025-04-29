# Malwirus

A modern Android device security app built with Flutter and Kotlin, featuring advanced device and SMS security, real-time threat detection, and a polished day/night UI.

---

## Overview
Malwirus is a security-focused Android app designed to help users monitor and protect their devices from malware, tampering, and suspicious SMS activity. The app leverages native security checks, the [freerasp](https://pub.dev/packages/freerasp) package, and a custom Flutter UI that adapts to day/night themes.

## Features
- **Device Security:**
  - Real-time threat detection (root, emulator, tampering, malware, etc.)
  - Security scan dashboard with threat summaries
  - Detailed threat and malware info with recommendations
- **SMS Security:**
  - Scans SMS for suspicious links and malware patterns
  - Whitelist management for trusted senders
  - Native integration for SMS permission and scanning
- **Modern UI:**
  - Lottie animation and a 2x2 grid of security options
  - Transparent, centered AppBar (no elevation, borders, or shadows)
  - Responsive layouts and adaptive theming (day/night)
  - All UI colors and styles managed via `styles.xml` and `app_colors.dart`
- **User Experience:**
  - Onboarding splash screen
  - Automatic permission handling
  - Persistent settings and scan history

## Screenshots
<!-- Add screenshots here if available -->

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio or compatible IDE
- Android device or emulator (SMS features require device)

### Installation
```sh
git clone https://github.com/yourusername/malwirus.git
cd malwirus
flutter pub get
flutter run
```

### Project Structure
- `lib/`
  - `main.dart` — App entry point and initialization
  - `home_screen.dart` — Main dashboard with security grid and animation
  - `device_security_screen.dart` — Device threat detection and reporting
  - `sms_security_screen.dart` — SMS scanning and whitelist management
  - `theme/`, `widget/`, `device_security/`, `sms_security/` — UI components and logic
- `android/` — Native Kotlin code, permissions, and integration
- `assets/` — Lottie animations, images, etc.

## Theming & UI Guidelines
- Transparent AppBar, no elevation or borders
- Day mode: white background, black icons/text
- Night mode: black background, white icons/text
- Topbar text centered; all styles managed for consistency
- Strings and styles managed in `strings.xml` and `styles.xml`

## Security
- Uses [freerasp](https://pub.dev/packages/freerasp) for anti-tampering, root, emulator, and malware detection
- Handles permissions and sensitive data securely
- Native integration for SMS scanning

## Contributing
Pull requests are welcome! Please follow these guidelines:
- Write reusable, maintainable code
- Follow existing UI and theming conventions
- Store all strings in `strings.xml` and styles in `styles.xml`
- Optimize for performance and stability
- Update this README with any major changes

## License
[MIT](LICENSE)

---

For questions or feedback, open an issue or contact the maintainer.
