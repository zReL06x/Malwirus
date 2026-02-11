import 'package:flutter/material.dart';
import 'dart:async';
import 'strings.dart';

/// Helper class for calculating security points, status, and recommendations for SaaS dashboard
class SecurityStatusHelper {
  static const int maxPoints = 100;
  static const int threatDeduction = 5;
  static const int disabledFeatureDeduction = 10;

  // Observable streams for UI updates
  static final StreamController<SecurityStatus> _statusController = 
      StreamController<SecurityStatus>.broadcast();
  
  static Stream<SecurityStatus> get statusStream => _statusController.stream;
  
  // Current security status cache
  static SecurityStatus? _currentStatus;
  
  /// Dispose method to clean up resources
  static void dispose() {
    _statusController.close();
  }

  /// Updates the security status and notifies observers
  static void updateSecurityStatus({
    required int deviceThreats,
    required int smsThreats,
    required int webThreats,
    required bool hasMaliciousApps,
    required bool smsEnabled,
    required bool webEnabled,
    bool deviceEnabled = true,
    List<String>? deviceThreatDetails,
    List<String>? smsThreatDetails,
    List<String>? webThreatDetails,
  }) {
    // Count malicious apps as single issue regardless of number of apps
    int totalThreats = deviceThreats + smsThreats + webThreats;
    if (hasMaliciousApps) {
      totalThreats += 1; // Count as single threat regardless of app count
    }
    // Also count disabled protections as issues
    if (!smsEnabled) totalThreats += 1;
    if (!webEnabled) totalThreats += 1;

    final int score = calculateSecurityPoints(
      detectedThreats: totalThreats,
      smsEnabled: smsEnabled,
      webEnabled: webEnabled,
      deviceEnabled: deviceEnabled,
    );

    final String statusLabel = getSecurityStatusLabel(score);
    
    final List<String> recommendations = generateRecommendations(
      detectedThreats: totalThreats,
      smsEnabled: smsEnabled,
      webEnabled: webEnabled,
      deviceThreats: deviceThreatDetails,
      smsThreats: smsThreatDetails,
      hasMaliciousApps: hasMaliciousApps,
    );

    _currentStatus = SecurityStatus(
      score: score,
      statusLabel: statusLabel,
      totalThreats: totalThreats,
      deviceThreats: deviceThreats,
      smsThreats: smsThreats,
      webThreats: webThreats,
      hasMaliciousApps: hasMaliciousApps,
      smsEnabled: smsEnabled,
      webEnabled: webEnabled,
      deviceEnabled: deviceEnabled,
      recommendations: recommendations,
    );

    _statusController.add(_currentStatus!);
  }

  /// Gets the current security status without triggering updates
  static SecurityStatus? getCurrentStatus() => _currentStatus;

  /// Calculates the security points based on threats and enabled features.
  ///
  /// [detectedThreats]: Total number of detected threats (device + SMS).
  /// [smsEnabled]: Whether SMS Security is enabled.
  /// [webEnabled]: Whether Web Security is enabled (default: false).
  /// [deviceEnabled]: Whether Device Security is enabled (usually always true, but allow for future use).
  static int calculateSecurityPoints({
    required int detectedThreats,
    required bool smsEnabled,
    required bool webEnabled,
    bool deviceEnabled = true,
  }) {
    int score = maxPoints;
    score -= detectedThreats * threatDeduction;
    if (!smsEnabled) score -= disabledFeatureDeduction;
    if (!webEnabled) score -= disabledFeatureDeduction;
    if (!deviceEnabled) score -= disabledFeatureDeduction;
    if (score < 0) score = 0;
    if (score > maxPoints) score = maxPoints;
    return score;
  }

  /// Returns the security status label based on the score.
  static String getSecurityStatusLabel(int score) {
    if (score >= 80) return 'Safe';
    if (score >= 50) return 'Warning';
    return 'Critical';
  }

  /// Generates overall recommendations based on security state.
  ///
  /// [detectedThreats]: Total number of detected threats (device + SMS).
  /// [smsEnabled]: Whether SMS Security is enabled.
  /// [webEnabled]: Whether Web Security is enabled (default: false).
  /// [deviceThreats]: List of device threats (strings or enums).
  /// [smsThreats]: List of SMS threats (strings or enums).
  /// [hasMaliciousApps]: Whether malicious apps are detected (counted as single threat).
  static List<String> generateRecommendations({
    required int detectedThreats,
    required bool smsEnabled,
    required bool webEnabled,
    List<String>? deviceThreats,
    List<String>? smsThreats,
    bool hasMaliciousApps = false,
  }) {
    final List<String> recs = [];
    // If there are any threats overall, surface a general device warning
    if (detectedThreats > 0) {
      recs.add(AppStrings.recDeviceThreatsDetected);
    }
    if (!smsEnabled) {
      recs.add(AppStrings.recEnableSms);
    } else if ((smsThreats?.isNotEmpty ?? false)) {
      recs.add(AppStrings.recSmsSuspiciousDetected);
    }
    if (!webEnabled) {
      recs.add(AppStrings.recEnableWeb);
    }
    if ((deviceThreats?.isNotEmpty ?? false)) {
      recs.add(AppStrings.recCheckDeviceThreats);
    }
    if (hasMaliciousApps) {
      recs.add(AppStrings.recCheckMaliciousApps);
    }
    if (recs.isEmpty && detectedThreats == 0 && smsEnabled && webEnabled) {
      recs.add(AppStrings.recAllGood);
    }
    return recs;
  }
}

/// Data class representing the current security status
class SecurityStatus {
  final int score;
  final String statusLabel;
  final int totalThreats;
  final int deviceThreats;
  final int smsThreats;
  final int webThreats;
  final bool hasMaliciousApps;
  final bool smsEnabled;
  final bool webEnabled;
  final bool deviceEnabled;
  final List<String> recommendations;

  const SecurityStatus({
    required this.score,
    required this.statusLabel,
    required this.totalThreats,
    required this.deviceThreats,
    required this.smsThreats,
    required this.webThreats,
    required this.hasMaliciousApps,
    required this.smsEnabled,
    required this.webEnabled,
    required this.deviceEnabled,
    required this.recommendations,
  });

  /// Creates a copy of this SecurityStatus with updated values
  SecurityStatus copyWith({
    int? score,
    String? statusLabel,
    int? totalThreats,
    int? deviceThreats,
    int? smsThreats,
    int? webThreats,
    bool? hasMaliciousApps,
    bool? smsEnabled,
    bool? webEnabled,
    bool? deviceEnabled,
    List<String>? recommendations,
  }) {
    return SecurityStatus(
      score: score ?? this.score,
      statusLabel: statusLabel ?? this.statusLabel,
      totalThreats: totalThreats ?? this.totalThreats,
      deviceThreats: deviceThreats ?? this.deviceThreats,
      smsThreats: smsThreats ?? this.smsThreats,
      webThreats: webThreats ?? this.webThreats,
      hasMaliciousApps: hasMaliciousApps ?? this.hasMaliciousApps,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      webEnabled: webEnabled ?? this.webEnabled,
      deviceEnabled: deviceEnabled ?? this.deviceEnabled,
      recommendations: recommendations ?? this.recommendations,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecurityStatus &&
        other.score == score &&
        other.statusLabel == statusLabel &&
        other.totalThreats == totalThreats &&
        other.deviceThreats == deviceThreats &&
        other.smsThreats == smsThreats &&
        other.webThreats == webThreats &&
        other.hasMaliciousApps == hasMaliciousApps &&
        other.smsEnabled == smsEnabled &&
        other.webEnabled == webEnabled &&
        other.deviceEnabled == deviceEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      score,
      statusLabel,
      totalThreats,
      deviceThreats,
      smsThreats,
      webThreats,
      hasMaliciousApps,
      smsEnabled,
      webEnabled,
      deviceEnabled,
    );
  }

  @override
  String toString() {
    return 'SecurityStatus(score: $score, statusLabel: $statusLabel, '
        'totalThreats: $totalThreats, hasMaliciousApps: $hasMaliciousApps)';
  }
}
