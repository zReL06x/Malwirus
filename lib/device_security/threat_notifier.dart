import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freerasp/freerasp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'threat_state.dart';

/// Class responsible for setting up listeners to detected threats
import 'dart:convert';

class ThreatNotifier extends AutoDisposeNotifier<ThreatState> {
  @override
  ThreatState build() {
    _init();
    // Load saved state asynchronously and update if any data is found
    ThreatNotifier.loadStateFromPrefs().then((savedState) {
      if (savedState.detectedThreats.isNotEmpty || savedState.detectedMalware.isNotEmpty) {
        updateState(savedState);
      }
    });
    return ThreatState.initial();
  }
  
  /// Updates the entire state with a new state
  void updateState(ThreatState newState) {
    state = newState;
  }

  void _init() {
    final threatCallback = ThreatCallback(
      onMalware: _updateMalware,
      onHooks: () => _updateThreat(Threat.hooks),
      onDebug: () => _updateThreat(Threat.debug),
      onPasscode: () => _updateThreat(Threat.passcode),
      onDeviceID: () => _updateThreat(Threat.deviceId),
      onSimulator: () => _updateThreat(Threat.simulator),
      onAppIntegrity: () => _updateThreat(Threat.appIntegrity),
      onObfuscationIssues: () => _updateThreat(Threat.obfuscationIssues),
      onDeviceBinding: () => _updateThreat(Threat.deviceBinding),
      onUnofficialStore: () => _updateThreat(Threat.unofficialStore),
      onPrivilegedAccess: () => _updateThreat(Threat.privilegedAccess),
      onSecureHardwareNotAvailable: () =>
          _updateThreat(Threat.secureHardwareNotAvailable),
      onSystemVPN: () => _updateThreat(Threat.systemVPN),
      onDevMode: () => _updateThreat(Threat.devMode),
      onADBEnabled: () => _updateThreat(Threat.adbEnabled),
      onScreenshot: () => _updateThreat(Threat.screenshot),
      onScreenRecording: () => _updateThreat(Threat.screenRecording),
    );

    Talsec.instance.attachListener(threatCallback);
  }

  void _updateThreat(Threat threat) {
    final updatedThreats = {...state.detectedThreats, threat};
    state = state.copyWith(detectedThreats: updatedThreats);
    saveStateToPrefs(state);
  }

  void _updateMalware(List<SuspiciousAppInfo?> malware) {
    final updatedMalware = malware.nonNulls.toList();
    state = state.copyWith(detectedMalware: updatedMalware);
    saveStateToPrefs(state);
  }

  /// Reconcile the current scan with saved data, removing threats/malware that are no longer present
  void reconcileAndUpdate(Set<Threat> scannedThreats, List<SuspiciousAppInfo> scannedMalware) {
    final newState = ThreatState.internal(
      detectedThreats: scannedThreats,
      detectedMalware: scannedMalware,
    );
    state = newState;
    saveStateToPrefs(state);
  }

  /// Save the current state to shared_preferences
  static Future<void> saveStateToPrefs(ThreatState state) async {
    final prefs = await SharedPreferences.getInstance();
    // Save threats as list of string names
    final threatList = state.detectedThreats.map((t) => t.name).toList();
    await prefs.setStringList('detectedThreats', threatList);
    // Save malware as JSON
    final malwareList = state.detectedMalware.map((m) => _malwareToJson(m)).toList();
    await prefs.setString('detectedMalware', jsonEncode(malwareList));
  }

  /// Load the state from shared_preferences
  static Future<ThreatState> loadStateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final threatNames = prefs.getStringList('detectedThreats') ?? [];
    final Set<Threat> threats = threatNames.map((name) => Threat.values.firstWhereOrNull((t) => t.name == name)).whereType<Threat>().toSet();
    final malwareJson = prefs.getString('detectedMalware');
    List<SuspiciousAppInfo> malware = [];
    if (malwareJson != null) {
      try {
        final decoded = jsonDecode(malwareJson) as List;
        malware = decoded.map((m) => _malwareFromJson(m)).whereType<SuspiciousAppInfo>().toList();
      } catch (_) {}
    }
    return ThreatState.internal(detectedThreats: threats, detectedMalware: malware);
  }

  /// Clear the saved state in shared_preferences
  static Future<void> clearStateInPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('detectedThreats');
    await prefs.remove('detectedMalware');
  }

  // Helper to serialize SuspiciousAppInfo (customize as needed)
  static Map<String, dynamic> _malwareToJson(SuspiciousAppInfo m) {
    return {
      'packageName': m.packageInfo.packageName,
      'reason': m.reason,
    };
  }

  // Helper to deserialize SuspiciousAppInfo (customize as needed)
  static SuspiciousAppInfo? _malwareFromJson(dynamic json) {
    if (json is Map<String, dynamic> && json['packageName'] is String && json['reason'] is String) {
      // SuspiciousAppInfo constructor may need adjustment if it has more fields
      try {
        return SuspiciousAppInfo(
          packageInfo: PackageInfo(packageName: json['packageName']),
          reason: json['reason'],
        );
      } catch (_) {}
    }
    return null;
  }

}