import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/calibrate.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/log_runner.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/units.dart';
import 'package:tiltawort/tilt/updates.dart';
import 'package:tiltawort/ui/chamfer.dart';
import 'package:tiltawort/ui/device_page.dart';
import 'package:tiltawort/ui/home_status.dart';
import 'package:tiltawort/ui/settings_page.dart';
import 'package:tiltawort/ui/status_chip.dart';
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
    this.updateOs,
    this.updateFetch,
    this.onApplyUpdate,
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
  final UpdateOs? updateOs;
  final ReleaseFetch? updateFetch;
  final Future<void> Function(UpdateOffer)? onApplyUpdate;

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
  late final PrefsStore _prefsStore;
  late final CsvLogStore _logs;
  late final LogRunner _runner;

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
    _prefsStore = widget.prefs ??
        PrefsStore(File('${Directory.systemTemp.path}/tiltawort-prefs.json'));
    _logs = widget.logs ??
        CsvLogStore(Directory('${Directory.systemTemp.path}/tiltawort-logs'));
    _runner = LogRunner(
      scanner: widget.scanner,
      logs: _logs,
      prefs: _prefsStore,
      history: _history,
    );
    _runner.attach();
    for (final tile in widget.seed) {
      _tiles[tile.uuid] = tile;
      unawaited(_hydrateUuid(tile.uuid));
    }
    unawaited(_restoreLogging());
    _ads = widget.scanner.advertisements.listen(_onAd);
    _radioSub = widget.scanner.radio.listen((state) {
      if (mounted) setState(() => _radio = state);
    });
    widget.scanner.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _restoreLogging() async {
    if (widget.prefs == null) return;
    final uuids = await _prefsStore.loggingUuids();
    if (!mounted) return;
    var added = false;
    for (final uuid in uuids) {
      if (_tiles.containsKey(uuid)) continue;
      final color = tiltColors[uuid];
      if (color == null) continue;
      final loaded = await _prefsStore.load(uuid);
      _prefsCache[uuid] = loaded;
      final last = widget.logs == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : await _logs.lastHeardForColor(color);
      _tiles[uuid] = TiltView.remembered(
        uuid: uuid,
        color: color,
        name: _nameFor(uuid, loaded, ''),
        lastPacket: last,
      );
      added = true;
    }
    if (added && mounted) setState(() {});
    if (widget.logs != null) {
      await _runner.resumeFromPrefs();
    }
  }

  void _onAd(TiltAdvertisementEvent event) {
    final uuid = event.advertisement.uuid;
    final prefs = _prefsCache[uuid];
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
    if (prefs == null && widget.prefs != null) {
      unawaited(_hydrateUuid(uuid));
    }
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
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DevicePage(
          scanner: widget.scanner,
          initial: _tiles[tile.uuid] ?? tile,
          prefs: _prefsStore,
          history: _history,
          logs: _logs,
          runner: _runner,
          now: widget.now,
        ),
      ),
    );
    if (result == 'forgotten') {
      _prefsCache.remove(tile.uuid);
      if (mounted) setState(() => _tiles.remove(tile.uuid));
      return;
    }
    _prefsCache.remove(tile.uuid);
    await _hydrateUuid(tile.uuid);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ads?.cancel();
    _radioSub?.cancel();
    unawaited(_runner.detach());
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FacetedMesh(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                            os: widget.updateOs,
                            fetch: widget.updateFetch,
                            onApply: widget.onApplyUpdate,
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
                      child: Text(
                        status.line,
                        style: soraBody.copyWith(color: palette.ink),
                      ),
                    )
                  else
                    Text(
                      status.line,
                      style: soraMuted.copyWith(color: palette.muted),
                    ),
                  if (tiles.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: ListView.separated(
                            itemCount: tiles.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 2),
                            itemBuilder: (context, i) {
                              return TiltTile(
                                view: tiles[i],
                                now: now,
                                onTap: () => _openDevice(tiles[i]),
                              );
                            },
                          ),
                        ),
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
        const Spacer(),
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
    final live = !view.neverHeard && view.isLiveAt(now);
    final name = view.name.trim();
    final plate = live ? palette.livePlate : palette.stalePlate;
    final ink = live ? palette.liveInk : palette.staleInk;
    final muted = live
        ? Color.lerp(ink, palette.muted, 0.45)!
        : palette.muted;
    final sgColor = live ? palette.liveGold : Color.lerp(palette.primary, ink, 0.2)!;
    final tempColor = live ? palette.tempOnLive : palette.tempOnStale;
    final colorWord = view.color;
    final sg = view.neverHeard ? '—' : formatSg(view.calSg, isPro: view.isPro);
    final temp = view.neverHeard ? '—' : formatTempF(view.calTempF, isPro: view.isPro);

    return Semantics(
      button: true,
      label: name.isEmpty ? view.color : '${view.color} $name',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 148),
          child: ChamferPlate(
            chamfer: 20,
            bevel: 6,
            fill: plate,
            edge: live ? palette.primary : palette.secondary,
            strip: factorySwatch(view.color),
            stripFactor: 0.15,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? view.color : name,
                            style: soraBody.copyWith(
                              color: live ? palette.liveGold : ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          if (name.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              colorWord,
                              style: soraMuted.copyWith(color: muted, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    StatusChip(live: live),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(sg, style: oxaniumReadout.copyWith(color: sgColor)),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SG',
                                    style: soraLabel.copyWith(
                                      color: muted,
                                      fontSize: 10,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  Text(
                                    'Temp.',
                                    style: soraLabel.copyWith(
                                      color: muted,
                                      fontSize: 10,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          temp,
                          style: oxaniumReadout.copyWith(
                            color: tempColor,
                            fontSize: 36,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    lastHeardLabel(view.lastPacket, now),
                    style: soraMuted.copyWith(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
