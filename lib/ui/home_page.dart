import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/ui/chamfer.dart';
import 'package:tiltawort/ui/home_status.dart';
import 'package:tiltawort/ui/settings_stub.dart';
import 'package:tiltawort/ui/theme.dart';

String formatSg(double sg, {required bool isPro}) =>
    sg.toStringAsFixed(isPro ? 4 : 3);

String formatTempF(double tempF, {required bool isPro}) {
  if (isPro) return '${tempF.toStringAsFixed(1)} °F';
  return '${tempF.round()} °F';
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.scanner,
    this.seed = const [],
    this.now,
    this.names = const {},
  });

  final TiltScanner scanner;
  final List<TiltView> seed;
  final DateTime Function()? now;
  final Map<String, String> names;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _tiles = <String, TiltView>{};
  RadioState _radio = RadioState.on;
  StreamSubscription<TiltAdvertisementEvent>? _ads;
  StreamSubscription<RadioState>? _radioSub;
  Timer? _tick;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    for (final tile in widget.seed) {
      _tiles[tile.uuid] = tile;
    }
    _ads = widget.scanner.advertisements.listen(_onAd);
    _radioSub = widget.scanner.radio.listen((state) {
      if (mounted) setState(() => _radio = state);
    });
    widget.scanner.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onAd(TiltAdvertisementEvent event) {
    final uuid = event.advertisement.uuid;
    final name = widget.names[uuid] ?? _tiles[uuid]?.name ?? '';
    final view = TiltView.fromEvent(event, name: name);
    if (!mounted) return;
    setState(() => _tiles[uuid] = view);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ads?.cancel();
    _radioSub?.cancel();
    widget.scanner.stop();
    super.dispose();
  }

  List<TiltView> _sorted() {
    final now = _now();
    final list = _tiles.values.toList();
    list.sort((a, b) {
      final aLive = a.isLiveAt(now);
      final bLive = b.isLiveAt(now);
      if (aLive != bLive) return aLive ? -1 : 1;
      return b.lastPacket.compareTo(a.lastPacket);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final tiles = _sorted();
    final liveCount = tiles.where((t) => t.isLiveAt(now)).length;
    final status = HomeStatus.of(
      radio: _radio,
      liveCount: liveCount,
      tileCount: tiles.length,
    );

    return Scaffold(
      backgroundColor: TiltColors.neutral,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                onGear: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsStubPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (status.kind == HomeStatusKind.radioOff)
                _RadioOffBanner(copy: status.line)
              else if (status.kind == HomeStatusKind.empty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(status.line, style: soraBody),
                )
              else
                Text(status.line, style: soraMuted),
              if (tiles.isNotEmpty) ...[
                const SizedBox(height: 24),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final two = constraints.maxWidth >= 720;
                      final gap = 24.0;
                      final tileWidth = two
                          ? (constraints.maxWidth - gap) / 2
                          : constraints.maxWidth;
                      return ListView(
                        children: [
                          Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final tile in tiles)
                                SizedBox(
                                  width: tileWidth,
                                  child: TiltTile(view: tile, now: now),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onGear});

  final VoidCallback onGear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('Tilt-a-Wort', style: soraTitle)),
        IconButton(
          tooltip: 'App settings',
          onPressed: onGear,
          icon: const Icon(Icons.settings, color: TiltColors.secondary),
        ),
      ],
    );
  }
}

class _RadioOffBanner extends StatelessWidget {
  const _RadioOffBanner({required this.copy});

  final String copy;

  @override
  Widget build(BuildContext context) {
    return ChamferPlate(
      chamfer: 8,
      fill: TiltColors.tertiary,
      edge: TiltColors.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy,
            style: soraBody.copyWith(color: TiltColors.onTertiary),
          ),
          const SizedBox(height: 12),
          ChamferPlate(
            chamfer: 8,
            fill: TiltColors.primary,
            edge: TiltColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: const Text(
              'Open Bluetooth settings',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: TiltColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TiltTile extends StatelessWidget {
  const TiltTile({super.key, required this.view, required this.now});

  final TiltView view;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final live = view.isLiveAt(now);
    final ink = live ? TiltColors.ink : TiltColors.secondary;
    final readout = live ? TiltColors.primary : TiltColors.secondary;
    final name = view.name.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 88),
      child: ChamferPlate(
        chamfer: 12,
        fill: TiltColors.surface,
        edge: live ? TiltColors.primary : TiltColors.secondary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: ChamferPlate(
                    chamfer: 4,
                    fill: factorySwatch(view.color),
                    edge: TiltColors.secondary,
                    padding: EdgeInsets.zero,
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  view.color,
                  style: soraBody.copyWith(color: ink, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(name, style: soraBody.copyWith(color: ink)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatSg(view.calSg, isPro: view.isPro),
                    style: oxaniumReadout.copyWith(color: readout),
                  ),
                ),
                Text(
                  formatTempF(view.calTempF, isPro: view.isPro),
                  style: oxaniumReadout.copyWith(
                    color: readout,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatusChip(live: live),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return ChamferPlate(
      chamfer: 8,
      fill: live ? TiltColors.primary : TiltColors.surface,
      edge: live ? TiltColors.primary : TiltColors.secondary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        live ? 'Live' : 'Stale',
        style: TextStyle(
          fontFamily: 'Sora',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: live ? TiltColors.onPrimary : TiltColors.secondary,
        ),
      ),
    );
  }
}
