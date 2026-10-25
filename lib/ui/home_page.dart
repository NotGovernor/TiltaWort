import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/calibrate.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/units.dart';
import 'package:tiltawort/ui/chamfer.dart';
import 'package:tiltawort/ui/device_page.dart';
import 'package:tiltawort/ui/home_status.dart';
import 'package:tiltawort/ui/settings_page.dart';
import 'package:tiltawort/ui/theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.scanner,
    this.seed = const [],
    this.now,
    this.names = const {},
    this.prefs,
    this.history,
    this.logs,
    this.themeMode = ThemeMode.dark,
    this.onThemeMode,
    this.version = '1.0.0',
  });

  final TiltScanner scanner;
  final List<TiltView> seed;
  final DateTime Function()? now;
  final Map<String, String> names;
  final PrefsStore? prefs;
  final SessionHistory? history;
  final CsvLogStore? logs;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeMode;
  final String version;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _tiles = <String, TiltView>{};
  final _prefsCache = <String, TiltPrefs>{};
  RadioState _radio = RadioState.on;
  StreamSubscription<TiltAdvertisementEvent>? _ads;
  StreamSubscription<RadioState>? _radioSub;
  Timer? _tick;
  late final SessionHistory _history;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  String _nameFor(String uuid, TiltPrefs? prefs, String fallback) {
    final injected = widget.names[uuid];
    if (injected != null && injected.isNotEmpty) return injected;
    if (prefs != null && prefs.name.isNotEmpty) return prefs.name;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _history = widget.history ?? SessionHistory();
    for (final tile in widget.seed) {
      _tiles[tile.uuid] = tile;
      unawaited(_hydrateUuid(tile.uuid));
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
    unawaited(_onAdAsync(event));
  }

  Future<void> _onAdAsync(TiltAdvertisementEvent event) async {
    final uuid = event.advertisement.uuid;
    var prefs = _prefsCache[uuid];
    if (prefs == null && widget.prefs != null) {
      prefs = await widget.prefs!.load(uuid);
      if (!mounted) return;
      _prefsCache[uuid] = prefs;
    }
    final name = _nameFor(uuid, prefs, _tiles[uuid]?.name ?? '');
    final view = TiltView.fromEvent(
      event,
      name: name,
      cal: prefs?.cal ?? const [],
    );
    _history.add(
      uuid,
      SessionSample(at: view.lastPacket, sg: view.calSg, tempF: view.calTempF),
    );
    if (!mounted) return;
    setState(() => _tiles[uuid] = view);
  }

  Future<void> _hydrateUuid(String uuid) async {
    if (widget.prefs == null) return;
    final loaded = await widget.prefs!.load(uuid);
    if (!mounted) return;
    _prefsCache[uuid] = loaded;
    final tile = _tiles[uuid];
    if (tile == null) return;
    final name = _nameFor(uuid, loaded, tile.name);
    final calSg = applyCal(tile.rawSg, loaded.cal);
    if (tile.name == name && tile.calSg == calSg) return;
    setState(() {
      _tiles[uuid] = tile.copyWith(name: name, calSg: calSg);
    });
  }

  Future<void> _openDevice(TiltView tile) async {
    final prefs = widget.prefs ??
        PrefsStore(File('${Directory.systemTemp.path}/tiltawort-prefs.json'));
    final logs = widget.logs ??
        CsvLogStore(Directory('${Directory.systemTemp.path}/tiltawort-logs'));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DevicePage(
          scanner: widget.scanner,
          initial: _tiles[tile.uuid] ?? tile,
          prefs: prefs,
          history: _history,
          logs: logs,
          now: widget.now,
        ),
      ),
    );
    _prefsCache.remove(tile.uuid);
    await _hydrateUuid(tile.uuid);
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

    final palette = TiltPalette.of(context);
    return Scaffold(
      backgroundColor: palette.neutral,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FacetedMesh(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              _Header(
                onGear: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsPage(
                        themeMode: widget.themeMode,
                        onThemeMode: widget.onThemeMode ?? (_) {},
                        version: widget.version,
                        radio: _radio,
                      ),
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
                                  child: TiltTile(
                                    view: tile,
                                    now: now,
                                    onTap: () => _openDevice(tile),
                                  ),
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
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onGear});

  final VoidCallback onGear;

  @override
  Widget build(BuildContext context) {
    final palette = TiltPalette.of(context);
    return Row(
      children: [
        const Expanded(child: Text('Tilt-a-Wort', style: soraTitle)),
        IconButton(
          tooltip: 'App settings',
          onPressed: onGear,
          icon: Icon(Icons.settings, color: palette.secondary),
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
    final palette = TiltPalette.of(context);
    return ChamferPlate(
      chamfer: 8,
      fill: palette.tertiary,
      edge: palette.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy,
            style: soraBody.copyWith(color: palette.onTertiary),
          ),
          const SizedBox(height: 12),
          ChamferPlate(
            chamfer: 8,
            fill: palette.primary,
            edge: palette.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text(
              'Open Bluetooth settings',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TiltTile extends StatelessWidget {
  const TiltTile({
    super.key,
    required this.view,
    required this.now,
    this.onTap,
  });

  final TiltView view;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = TiltPalette.of(context);
    final live = view.isLiveAt(now);
    final ink = live ? palette.ink : palette.secondary;
    final readout = live ? palette.primary : palette.secondary;
    final name = view.name.trim();

    return Semantics(
      button: true,
      label: name.isEmpty ? view.color : '${view.color} $name',
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 88),
      child: ChamferPlate(
        chamfer: 12,
        fill: palette.surface,
        edge: live ? palette.primary : palette.secondary,
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
                    edge: palette.secondary,
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
    final palette = TiltPalette.of(context);
    return ChamferPlate(
      chamfer: 8,
      fill: live ? palette.primary : palette.surface,
      edge: live ? palette.primary : palette.secondary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        live ? 'Live' : 'Stale',
        style: TextStyle(
          fontFamily: 'Sora',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: live ? palette.onPrimary : palette.secondary,
        ),
      ),
    );
  }
}
