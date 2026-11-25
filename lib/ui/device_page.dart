import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tiltawort/tilt/calibrate.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/log_runner.dart';
import 'package:tiltawort/tilt/log_share.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/units.dart';
import 'package:tiltawort/ui/chamfer.dart';
import 'package:tiltawort/ui/series_plot.dart';
import 'package:tiltawort/ui/status_chip.dart';
import 'package:tiltawort/ui/theme.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({
    super.key,
    required this.scanner,
    required this.initial,
    required this.prefs,
    required this.history,
    required this.logs,
    this.runner,
    this.now,
  });

  final TiltScanner scanner;
  final TiltView initial;
  final PrefsStore prefs;
  final SessionHistory history;
  final CsvLogStore logs;
  final LogRunner? runner;
  final DateTime Function()? now;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  late TiltView _view;
  TiltPrefs _prefs = TiltPrefs.defaults;
  late final TextEditingController _name;
  late final TextEditingController _uncal;
  late final TextEditingController _actual;
  late final TextEditingController _comment;
  late final FocusNode _nameFocus;
  StreamSubscription<TiltAdvertisementEvent>? _ads;
  Timer? _tick;
  List<File> _files = [];
  String? _calError;
  Duration _chartPan = Duration.zero;
  late final LogRunner _runner;
  var _ownsRunner = false;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _view = widget.initial;
    _prefs = TiltPrefs(name: widget.initial.name);
    _name = TextEditingController(text: _prefs.name);
    _uncal = TextEditingController();
    _actual = TextEditingController();
    _comment = TextEditingController();
    _nameFocus = FocusNode();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) unawaited(_commitName());
    });
    if (widget.runner != null) {
      _runner = widget.runner!;
    } else {
      _runner = LogRunner(
        scanner: widget.scanner,
        logs: widget.logs,
        prefs: widget.prefs,
        history: widget.history,
      );
      _ownsRunner = true;
    }
    _runner.attach();
    _ads = widget.scanner.advertisements.listen(_onAd);
    widget.scanner.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    final loaded = await widget.prefs.load(_view.uuid);
    if (!mounted) return;
    var next = loaded;
    if (next.name.isEmpty && widget.initial.name.isNotEmpty) {
      next = next.copyWith(name: widget.initial.name);
    }
    final typed = _name.text.trim();
    final userEdited =
        typed.isNotEmpty && typed != widget.initial.name && typed != next.name;
    if (userEdited) {
      next = next.copyWith(name: typed);
      await widget.prefs.save(_view.uuid, next);
      _runner.updatePrefs(_view.uuid, next);
    }
    if (!mounted) return;
    setState(() {
      _prefs = next;
      if (!userEdited && !_nameFocus.hasFocus && _name.text != next.name) {
        _name.text = next.name;
      }
      _view = _view.copyWith(
        name: userEdited ? typed : next.name,
        calSg: applyCal(_view.rawSg, next.cal),
      );
    });
    await _refreshFiles();
    if (next.logging && !widget.logs.isOpenFor(_view.color)) {
      await widget.logs.resumeLatest(_view.color);
    }
    final active = widget.logs.activeFor(_view.color);
    if (active != null && await active.exists()) {
      widget.history.mergeAll(
        _view.uuid,
        samplesFromCsv(await active.readAsString()),
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshFiles() async {
    final files = await widget.logs.listForColor(_view.color);
    if (!mounted) return;
    setState(() => _files = files);
  }

  Future<void> _setPrefs(TiltPrefs next) async {
    setState(() {
      _prefs = next;
      _view = _view.copyWith(
        name: next.name,
        calSg: applyCal(_view.rawSg, next.cal),
      );
    });
    try {
      await widget.prefs.save(_view.uuid, next);
      _runner.updatePrefs(_view.uuid, next);
    } on FileSystemException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: ${e.message}')),
      );
    }
  }

  void _onAd(TiltAdvertisementEvent event) {
    if (event.advertisement.uuid != _view.uuid) return;
    final view = TiltView.fromEvent(
      event,
      name: _prefs.name,
      cal: _prefs.cal,
    );
    widget.history.add(
      view.uuid,
      SessionSample(at: view.lastPacket, sg: view.calSg, tempF: view.calTempF),
    );
    if (mounted) setState(() => _view = view);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ads?.cancel();
    _nameFocus.dispose();
    _name.dispose();
    _uncal.dispose();
    _actual.dispose();
    _comment.dispose();
    if (_ownsRunner) unawaited(_runner.detach());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = TiltPalette.of(context);
    final now = _now();
    final live = !_view.neverHeard && _view.isLiveAt(now);
    final beer = _prefs.name.trim().isEmpty ? 'Untitled' : _prefs.name.trim();
    final recording = recordingUi(
      prefsLogging: _prefs.logging,
      fileOpen: widget.logs.isOpenFor(_view.color),
    );
    final samples = widget.history.of(_view.uuid);
    final gUnit = _prefs.gravityUnit == 'P' ? '°P' : 'SG';
    final tUnit = _prefs.tempUnit == 'C' ? '°C' : '°F';
    final gNum = _view.neverHeard
        ? '—'
        : formatGravity(
            _view.calSg,
            isPro: _view.isPro,
            unit: _prefs.gravityUnit,
          );
    final tNum = _view.neverHeard
        ? '—'
        : (_prefs.tempUnit == 'C'
            ? (_view.isPro
                ? fToC(_view.calTempF).toStringAsFixed(1)
                : '${fToC(_view.calTempF).round()}')
            : (_view.isPro
                ? _view.calTempF.toStringAsFixed(1)
                : '${_view.calTempF.round()}'));
    final uncalCaption = _view.neverHeard
        ? '—'
        : 'Uncalibrated ${formatSg(_view.rawSg, isPro: _view.isPro)} · ${formatTempF(_view.rawTempF, isPro: _view.isPro)}';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FacetedMesh(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      BackChevron(onPressed: () => Navigator.of(context).pop()),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              beer,
                              style: soraTitle.copyWith(
                                color: p.primary,
                                fontSize: 22,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  _view.color,
                                  style: soraMuted.copyWith(color: p.muted),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _view.isPro ? 'Pro' : 'Tilt',
                                  style: soraLabel.copyWith(color: p.secondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusChip(live: live),
                          const SizedBox(height: 4),
                          Text(
                            lastHeardLabel(_view.lastPacket, now),
                            style: soraMuted.copyWith(color: p.muted, fontSize: 12),
                          ),
                          Text(
                            rssiLabel(_view.rssiDbm),
                            style: soraMuted.copyWith(color: p.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  ChamferPlate(
                    chamfer: 18,
                    bevel: 6,
                    fill: live ? p.livePlate : p.stalePlate,
                    edge: p.primary,
                    accentTl: p.primary,
                    accentTr: p.tertiary,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gNum,
                                    style: oxaniumHero.copyWith(color: p.primary),
                                  ),
                                  Text(
                                    gUnit,
                                    style: soraLabel.copyWith(color: p.primary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$tNum$tUnit',
                                  style: oxaniumReadout.copyWith(
                                    color: live ? p.tempOnLive : p.tempOnStale,
                                    fontSize: 36,
                                  ),
                                ),
                                Text(
                                  'Temp',
                                  style: soraLabel.copyWith(color: p.muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          uncalCaption,
                          style: soraMuted.copyWith(color: p.muted, fontSize: 12),
                        ),
                        if (!isNonsenseHeard(_view.lastPacket))
                          Text(
                            localStamp(_view.lastPacket),
                            style: soraMuted.copyWith(color: p.muted, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    p,
                    'Chart (this session)',
                    samples.isEmpty
                        ? ChamferPlate(
                            chamfer: 12,
                            bevel: 4,
                            inset: true,
                            shadow: false,
                            fill: Color.lerp(p.neutral, p.stalePlate, 0.4)!,
                            edge: p.secondary,
                            padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
                            child: Center(
                              child: Text(
                                'No samples yet',
                                style: soraMuted.copyWith(color: p.muted),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _legendDot(p.primary),
                                  const SizedBox(width: 6),
                                  Text('SG', style: soraLabel.copyWith(color: p.primary)),
                                  const SizedBox(width: 14),
                                  _legendDot(p.tertiary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Temp',
                                    style: soraLabel.copyWith(color: p.tertiary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ChamferPlate(
                                chamfer: 12,
                                bevel: 4,
                                inset: true,
                                shadow: false,
                                fill: Color.lerp(p.neutral, p.stalePlate, 0.4)!,
                                edge: p.secondary,
                                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                                child: Column(
                                  children: [
                                    SeriesPlot(
                                      samples: samples,
                                      line: p.primary,
                                      yOf: (s) => s.sg,
                                      now: now,
                                      yFormat: (y) => y.toStringAsFixed(_view.isPro ? 4 : 3),
                                      pan: _chartPan,
                                      onPan: _onChartPan,
                                    ),
                                    const SizedBox(height: 8),
                                    SeriesPlot(
                                      samples: samples,
                                      line: p.tertiary,
                                      yOf: (s) => s.tempF,
                                      now: now,
                                      yFormat: (y) => y.toStringAsFixed(_view.isPro ? 1 : 0),
                                      pan: _chartPan,
                                      onPan: _onChartPan,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                    inset: true,
                  ),
                  const SizedBox(height: 16),
                  _section(
                    p,
                    'Logging (ours)',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recordingStatusLine(
                            isOpen: recording,
                            fileName: widget.logs
                                .activeFor(_view.color)
                                ?.uri
                                .pathSegments
                                .last,
                            intervalSeconds: _prefs.logIntervalSeconds,
                          ),
                          style: soraBody.copyWith(color: p.ink),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final i in logIntervals) ...[
                              _choice(
                                p,
                                i.chip,
                                _prefs.logIntervalSeconds == i.seconds,
                                () {
                                  _setPrefs(
                                    _prefs.copyWith(logIntervalSeconds: i.seconds),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (recording)
                              _btn(p, 'Stop recording', _endLog, kind: MetalButtonKind.steel)
                            else
                              _btn(p, 'Start recording', _startLog, kind: MetalButtonKind.gold),
                            _btn(p, 'Snapshot', _logOnce, kind: MetalButtonKind.blue),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _field(p, _comment, 'Comment'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    p,
                    'Calibration (ours)',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_prefs.cal.isEmpty)
                          Text(
                            'No points. Live numbers equal uncal.',
                            style: soraMuted.copyWith(color: p.muted),
                          ),
                        for (var i = 0; i < _prefs.cal.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_prefs.cal[i].uncalSg.toStringAsFixed(4)} → ${_prefs.cal[i].actualSg.toStringAsFixed(4)}',
                                    style: soraBody.copyWith(color: p.ink),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final next = [..._prefs.cal]..removeAt(i);
                                    _setPrefs(_prefs.copyWith(cal: next));
                                  },
                                  child: Text('Delete', style: soraMuted.copyWith(color: p.muted)),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        _field(p, _uncal, 'Uncal SG'),
                        const SizedBox(height: 8),
                        _field(p, _actual, 'Actual SG'),
                        if (_calError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _calError!,
                            style: soraMuted.copyWith(color: p.primary),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _btn(p, 'Use live Tilt reading', _fillUncal, primary: false),
                            _btn(p, 'Add point', _addPoint, primary: false),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _btn(p, 'Tilt-a-Wort water cal → 1.000', _waterShortcut),
                        const SizedBox(height: 6),
                        Text(
                          'Stored on this device. Not written to the Tilt.',
                          style: soraMuted.copyWith(color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    p,
                    'Name & units (ours)',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                p,
                                _name,
                                'Beer name',
                                focusNode: _nameFocus,
                                onChanged: (v) {
                                  if (v.trim().isNotEmpty) {
                                    _setPrefs(_prefs.copyWith(name: v));
                                  }
                                },
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _name.clear();
                                _nameFocus.requestFocus();
                              },
                              child: Text('Clear', style: soraMuted.copyWith(color: p.muted)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Temperature scale', style: soraLabel.copyWith(color: p.secondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _choice(p, '°F', _prefs.tempUnit == 'F', () {
                              _setPrefs(_prefs.copyWith(tempUnit: 'F'));
                            }),
                            const SizedBox(width: 8),
                            _choice(p, '°C', _prefs.tempUnit == 'C', () {
                              _setPrefs(_prefs.copyWith(tempUnit: 'C'));
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Gravity Reading Type', style: soraLabel.copyWith(color: p.secondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _choice(p, 'SG', _prefs.gravityUnit == 'SG', () {
                              _setPrefs(_prefs.copyWith(gravityUnit: 'SG'));
                            }),
                            const SizedBox(width: 8),
                            _choice(p, '°P', _prefs.gravityUnit == 'P', () {
                              _setPrefs(_prefs.copyWith(gravityUnit: 'P'));
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    p,
                    'Logs',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_files.isEmpty)
                          Text(
                            'No logs for this color yet.',
                            style: soraMuted.copyWith(color: p.muted),
                          ),
                        for (final f in _files)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    f.uri.pathSegments.last,
                                    style: soraBody.copyWith(color: p.ink, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _onLogFileAction(f),
                                  child: Text(
                                    logFileActionLabel(defaultTargetPlatform),
                                    style: soraMuted.copyWith(color: p.primary),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await widget.logs.deleteFile(f);
                                    if (!widget.logs.isOpenFor(_view.color)) {
                                      await _setPrefs(_prefs.copyWith(logging: false));
                                    }
                                    await _refreshFiles();
                                  },
                                  child: Text('Delete', style: soraMuted.copyWith(color: p.muted)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _btn(p, 'Forget this Tilt', _forget, kind: MetalButtonKind.steel),
                ],
                ),
              ),
            ),
          ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(TiltPalette p, String title, Widget child, {bool inset = false}) {
    return ChamferPlate(
      chamfer: 14,
      bevel: 5,
      fill: p.stalePlate,
      edge: p.secondary,
      inset: inset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: soraLabel.copyWith(color: p.secondary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _choice(TiltPalette p, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ChamferPlate(
        chamfer: 8,
        bevel: 3,
        fill: selected ? p.primary : p.stalePlate,
        edge: selected ? p.primary : p.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shadow: false,
        child: Text(
          label,
          style: soraLabel.copyWith(color: selected ? p.onPrimary : p.ink),
        ),
      ),
    );
  }

  Widget _btn(
    TiltPalette p,
    String label,
    VoidCallback onTap, {
    MetalButtonKind kind = MetalButtonKind.gold,
    bool primary = true,
  }) {
    return MetalButton(
      label: label,
      onTap: onTap,
      kind: primary ? kind : MetalButtonKind.steel,
    );
  }

  Widget _field(
    TiltPalette p,
    TextEditingController c,
    String hint, {
    ValueChanged<String>? onChanged,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: c,
      focusNode: focusNode,
      onChanged: onChanged,
      style: soraBody.copyWith(color: p.ink),
      cursorColor: p.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: soraMuted.copyWith(color: p.muted),
        filled: true,
        fillColor: p.neutral,
        isDense: true,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: p.secondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: p.primary),
        ),
      ),
    );
  }

  void _fillUncal() {
    _uncal.text = formatSg(_view.rawSg, isPro: _view.isPro);
  }

  Future<void> _addPoint() async {
    final u = double.tryParse(_uncal.text.trim());
    final a = double.tryParse(_actual.text.trim());
    if (u == null || a == null) {
      setState(() => _calError = 'Need numbers in both Uncal SG and Actual SG.');
      return;
    }
    setState(() => _calError = null);
    await _setPrefs(_prefs.copyWith(cal: [..._prefs.cal, CalPoint(uncalSg: u, actualSg: a)]));
    _uncal.clear();
    _actual.clear();
  }

  Future<void> _waterShortcut() async {
    final p = TiltPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ChamferPlate(
            fill: p.surface,
            edge: p.primary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tilt-a-Wort water cal → 1.000', style: soraTitle.copyWith(color: p.primary)),
                const SizedBox(height: 8),
                Text('Does not tare the float.', style: soraBody.copyWith(color: p.ink)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel', style: soraBody.copyWith(color: p.muted)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Confirm', style: soraBody.copyWith(color: p.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    await _setPrefs(
      _prefs.copyWith(cal: upsertWaterCal(_prefs.cal, currentRaw: _view.rawSg)),
    );
  }

  void _onChartPan(Duration next) {
    final samples = widget.history.of(_view.uuid);
    var pan = next;
    if (pan.isNegative) pan = Duration.zero;
    if (samples.isNotEmpty) {
      final maxPan = _now().difference(samples.first.at);
      if (pan > maxPan) pan = maxPan;
    }
    setState(() => _chartPan = pan);
  }

  Future<void> _onLogFileAction(File file) async {
    final share = logFileActionIsShare(defaultTargetPlatform);
    if (!await file.exists()) {
      _logSnack(
        share
            ? 'Could not share: that log is gone.'
            : 'Could not reveal: that log is gone.',
      );
      await _refreshFiles();
      return;
    }
    if (share) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'text/csv')],
          ),
        );
      } catch (_) {
        _logSnack('Could not share: the system sheet did not open.');
        await _refreshFiles();
      }
      return;
    }
    try {
      await widget.logs.revealFile(file);
    } catch (_) {
      _logSnack('Could not reveal: the file manager did not open.');
      await _refreshFiles();
    }
  }

  void _logSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _commitName() async {
    final next = _name.text.trim().isEmpty ? 'Untitled' : _name.text.trim();
    if (_name.text != next) _name.text = next;
    if (_prefs.name != next) await _setPrefs(_prefs.copyWith(name: next));
  }

  Future<void> _startLog() async {
    await _commitName();
    if (_prefs.name.trim().isEmpty) {
      await _promptName();
      if (_prefs.name.trim().isEmpty) return;
    }
    try {
      await _runner.startRecording(
        uuid: _view.uuid,
        color: _view.color,
        beer: _prefs.name,
        at: _now(),
      );
      await _setPrefs(_prefs.copyWith(logging: true));
      await _refreshFiles();
    } on FileSystemException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: ${e.message}')),
      );
    }
  }

  Future<void> _endLog() async {
    await _runner.stopRecording(uuid: _view.uuid, color: _view.color);
    await _setPrefs(_prefs.copyWith(logging: false));
  }

  Future<void> _logOnce() async {
    final temp = _prefs.tempUnit == 'C' ? fToC(_view.calTempF) : _view.calTempF;
    await _runner.snapshot(
      uuid: _view.uuid,
      color: _view.color,
      beer: _prefs.name,
      sg: _view.calSg,
      tempF: temp,
      at: _now(),
      comment: _comment.text,
      tempUnit: _prefs.tempUnit,
    );
    _comment.clear();
    await _refreshFiles();
  }

  Future<void> _forget() async {
    if (widget.logs.isOpenFor(_view.color)) {
      await _runner.stopRecording(uuid: _view.uuid, color: _view.color);
    }
    await widget.prefs.remove(_view.uuid);
    _runner.forgetPrefs(_view.uuid);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop('forgotten');
    }
  }

  Future<void> _promptName() async {
    final p = TiltPalette.of(context);
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ChamferPlate(
            fill: p.surface,
            edge: p.primary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name this beer', style: soraTitle.copyWith(color: p.primary)),
                const SizedBox(height: 12),
                _field(p, c, 'Beer name'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, c.text),
                    child: Text('Save', style: soraBody.copyWith(color: p.primary)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    c.dispose();
    if (name == null || name.trim().isEmpty) return;
    _name.text = name.trim();
    await _setPrefs(_prefs.copyWith(name: name.trim()));
  }
}
