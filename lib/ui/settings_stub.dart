import 'package:flutter/material.dart';
import 'package:tiltawort/ui/theme.dart';

/// Gear target for Task 5. Full settings is the next Roller card.
class SettingsStubPage extends StatelessWidget {
  const SettingsStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TiltColors.neutral,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back', style: soraBody),
              ),
              const SizedBox(height: 16),
              const Text('App Settings', style: soraTitle),
              const SizedBox(height: 8),
              const Text(
                'Appearance and about come next.',
                style: soraMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
