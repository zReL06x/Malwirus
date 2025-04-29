import 'package:flutter/material.dart';
import 'package:freerasp/freerasp.dart';
import 'widgets.dart';
import 'package:malwirus/theme/app_colors.dart';
import 'threat_state.dart';

/// ListView displaying all detected threats
class ThreatListView extends StatelessWidget {
  /// Represents a list of detected threats
  const ThreatListView({
    required this.threats,
    super.key,
  });

  /// Set of detected threats
  final Set<Threat> threats;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: Threat.values.length,
      itemBuilder: (context, index) {
        final currentThreat = Threat.values[index];
        final isDetected = threats.contains(currentThreat);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(currentThreat.name.capitalize()),
            subtitle: Text(isDetected ? 'Danger' : 'Safe'),
            trailing: SafetyIcon(isDetected: isDetected),
            tileColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
    );
  }
}