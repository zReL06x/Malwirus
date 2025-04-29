import 'package:freerasp/freerasp.dart';

class ThreatState {
  factory ThreatState.initial() =>
      ThreatState.internal(detectedThreats: {}, detectedMalware: []);

  const ThreatState.internal({
    required this.detectedThreats,
    required this.detectedMalware,
  });

  final Set<Threat> detectedThreats;
  final List<SuspiciousAppInfo> detectedMalware;

  ThreatState copyWith({
    Set<Threat>? detectedThreats,
    List<SuspiciousAppInfo>? detectedMalware,
  }) {
    return ThreatState.internal(
      detectedThreats: detectedThreats ?? this.detectedThreats,
      detectedMalware:
      detectedMalware?.nonNulls.toList() ?? this.detectedMalware,
    );
  }
}