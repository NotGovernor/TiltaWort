import 'package:flutter/material.dart';
import 'package:tiltawort/ui/theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    final p = TiltPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: live ? p.primary : p.secondary,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        live ? 'Live' : 'Stale',
        style: soraLabel.copyWith(
          color: live ? p.onPrimary : p.neutral,
          fontSize: 11,
        ),
      ),
    );
  }
}
