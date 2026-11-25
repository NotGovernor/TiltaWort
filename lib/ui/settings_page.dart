import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/update_apply.dart';
import 'package:tiltawort/tilt/updates.dart';
import 'package:tiltawort/ui/chamfer.dart';
import 'package:tiltawort/ui/theme.dart';
import 'package:tiltawort/ui/update_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeMode,
    required this.version,
    required this.radio,
    this.os,
    this.fetch,
    this.onApply,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  final String version;
  final RadioState radio;
  final UpdateOs? os;
  final ReleaseFetch? fetch;
  final Future<void> Function(UpdateOffer)? onApply;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _status;
  var _busy = false;

  UpdateOs get _os => widget.os ?? updateOsFrom();

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Checking\u2026';
    });
    try {
      final offer = await checkForUpdate(
        currentVersion: widget.version,
        os: _os,
        releaseBuild: true,
        fromLaunch: false,
        fetch: widget.fetch ?? githubFetch,
      );
      if (!mounted) return;
      if (offer == null) {
        setState(() => _status = "You're on ${widget.version}");
        return;
      }
      setState(() => _status = null);
      final go = await showUpdateDialog(context, offer: offer, os: _os);
      if (go && mounted) {
        await (widget.onApply ?? applyUpdate)(offer);
      }
    } on UpdateException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not check for updates');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
            if (widget.radio == RadioState.off) ...[
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
                    selected: widget.themeMode != ThemeMode.light,
                    onTap: () => widget.onThemeMode(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modePlate(
                    context,
                    p,
                    label: 'Light',
                    selected: widget.themeMode == ThemeMode.light,
                    onTap: () => widget.onThemeMode(ThemeMode.light),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('About', style: soraLabel.copyWith(color: p.secondary)),
            const SizedBox(height: 8),
            Text(
              'Tilt-a-Wort ${widget.version}',
              style: soraBody.copyWith(color: p.ink),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : _check,
                child: Text(
                  'Check for updates',
                  style: soraBody.copyWith(color: p.primary),
                ),
              ),
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _status!,
                  style: soraMuted.copyWith(color: p.muted),
                ),
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
