import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/ui/chamfer.dart';
import 'package:tiltawort/ui/theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeMode,
    required this.version,
    required this.radio,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  final String version;
  final RadioState radio;

  @override
  Widget build(BuildContext context) {
    final p = TiltPalette.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FacetedMesh(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BackChevron(onPressed: () => Navigator.of(context).pop()),
            ),
            const SizedBox(height: 8),
            Text('App Settings', style: soraTitle.copyWith(color: p.primary)),
            const SizedBox(height: 20),
            if (radio == RadioState.off) ...[
              ChamferPlate(
                fill: p.tertiary,
                edge: p.tertiary,
                child: Text(
                  'Bluetooth is off. This app only listens.',
                  style: soraBody.copyWith(color: p.onTertiary),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text('Appearance', style: soraLabel.copyWith(color: p.secondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _modePlate(
                    context,
                    p,
                    label: 'Dark',
                    selected: themeMode != ThemeMode.light,
                    onTap: () => onThemeMode(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modePlate(
                    context,
                    p,
                    label: 'Light',
                    selected: themeMode == ThemeMode.light,
                    onTap: () => onThemeMode(ThemeMode.light),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('About', style: soraLabel.copyWith(color: p.secondary)),
            const SizedBox(height: 8),
            Text(
              'Tilt-a-Wort $version',
              style: soraBody.copyWith(color: p.ink),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modePlate(
    BuildContext context,
    TiltPalette p, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ChamferPlate(
        fill: selected ? p.primary : p.stalePlate,
        edge: selected ? p.primary : p.secondary,
        child: Text(
          label,
          style: soraTitle.copyWith(
            color: selected ? p.onPrimary : p.ink,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
