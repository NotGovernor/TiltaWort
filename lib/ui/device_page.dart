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
    this.now,
  });

  final TiltScanner scanner;
  final TiltView initial;
  final PrefsStore prefs;
  final SessionHistory history;
  final CsvLogStore logs;
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
  StreamSubscription<TiltAdvertisementEvent>? _ads;
  Timer? _tick;
  List<File> _files = [];

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
    setState(() {
      _prefs = next;
      if (_name.text != next.name) _name.text = next.name;
      _view = _view.copyWith(
        name: next.name,
        calSg: applyCal(_view.rawSg, next.cal),
      );
    });
    await _refreshFiles();
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
    await widget.prefs.save(_view.uuid, next);
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
    if (_prefs.logging && widget.logs.isOpen) {
      final temp = _prefs.tempUnit == 'C' ? fToC(view.calTempF) : view.calTempF;
      widget.logs.append(
        timestamp: view.lastPacket,
        sg: view.calSg,
        temp: temp,
        color: view.color,
        beer: _prefs.name,
        comment: '',
      );
    }
    if (mounted) setState(() => _view = view);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ads?.cancel();
    _name.dispose();
    _uncal.dispose();
    _actual.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = TiltPalette.of(context);
    final now = _now();
    final live = _view.isLiveAt(now);
    final beer = _prefs.name.trim().isEmpty ? 'Untitled' : _prefs.name.trim();
    final samples = widget.history.of(_view.uuid);
    final gUnit = _prefs.gravityUnit == 'P' ? '°P' : 'SG';
    final tUnit = _prefs.tempUnit == 'C' ? '°C' : '°F';
    final gNum = formatGravity(
      _view.calSg,
      isPro: _view.isPro,
      unit: _prefs.gravityUnit,
    );
    final tNum = _prefs.tempUnit == 'C'
        ? (_view.isPro
            ? fToC(_view.calTempF).toStringAsFixed(1)
            : '${fToC(_view.calTempF).round()}')
        : (_view.isPro
            ? _view.calTempF.toStringAsFixed(1)
            : '${_view.calTempF.round()}');
    final uncalCaption =
        'Uncalibrated ${formatSg(_view.rawSg, isPro: _view.isPro)} · ${formatTempF(_view.rawTempF, isPro: _view.isPro)}';

    return Scaffold(
      backgroundColor: p.neutral,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Back', style: soraBody.copyWith(color: p.ink)),
                  ),
                  _facet(_view.color),
                  const SizedBox(width: 8),
                  Text(_view.color, style: soraLabel.copyWith(color: p.secondary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      beer,
                      style: soraTitle.copyWith(color: p.primary, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusChip(live: live),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    gNum,
                    style: oxaniumReadout.copyWith(fontSize: 56, color: p.ink),
                  ),
                  Text(gUnit, style: soraLabel.copyWith(color: p.muted)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tNum,
                        style: oxaniumReadout.copyWith(fontSize: 36, color: p.ink),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text(tUnit, style: soraLabel.copyWith(color: p.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(uncalCaption, style: soraMuted.copyWith(color: p.muted)),
                  Text(
                    _view.isPro ? 'Pro' : 'Tilt',
                    style: soraLabel.copyWith(color: p.secondary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${relativeAgo(_view.lastPacket, now)} · ${localStamp(_view.lastPacket)} · ${rssiLabel(_view.rssiDbm)}',
                    style: soraMuted.copyWith(color: p.muted),
                  ),
                  const SizedBox(height: 20),
                  _section(
                    p,
                    'Chart (this session)',
                    samples.isEmpty
                        ? Text('No samples yet', style: soraMuted.copyWith(color: p.muted))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SG', style: soraLabel.copyWith(color: p.primary)),
                              SeriesPlot(
                                samples: samples,
                                line: p.primary,
                                yOf: (s) => s.sg,
                              ),
                              const SizedBox(height: 8),
                              Text('Temp', style: soraLabel.copyWith(color: p.tertiary)),
                              SeriesPlot(
                                samples: samples,
                                line: p.tertiary,
                                yOf: (s) => s.tempF,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    p,
                    'Logging (ours)',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _choice(p, 'Off', !_prefs.logging, () {
                              _setPrefs(_prefs.copyWith(logging: false));
                            }),
                            const SizedBox(width: 8),
                            _choice(p, 'On', _prefs.logging, () {
                              _setPrefs(_prefs.copyWith(logging: true));
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _btn(p, 'Start log', _startLog),
                            _btn(p, 'End log', _endLog, primary: false),
                            _btn(p, 'Log once', _logOnce, primary: false),
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
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _btn(p, 'Fill uncal', _fillUncal, primary: false),
                            _btn(p, 'Add point', _addPoint, primary: false),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _btn(p, 'Tilt-a-Wort cal → 1.000', _waterShortcut),
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
                        _field(p, _name, 'Beer name', onChanged: (v) {
                          _setPrefs(_prefs.copyWith(name: v));
                        }),
                        const SizedBox(height: 12),
                        Text('Temp', style: soraLabel.copyWith(color: p.secondary)),
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
                        Text('Gravity', style: soraLabel.copyWith(color: p.secondary)),
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
                                  onPressed: () => widget.logs.revealFile(f),
                                  child: Text('Reveal', style: soraMuted.copyWith(color: p.primary)),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await widget.logs.deleteFile(f);
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
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(TiltPalette p, String title, Widget child) {
    return ChamferPlate(
      fill: p.surface,
      edge: p.secondary.withValues(alpha: 0.45),
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

  Widget _choice(TiltPalette p, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.surface,
          border: Border.all(color: selected ? p.primary : p.secondary),
        ),
        child: Text(
          label,
          style: soraLabel.copyWith(color: selected ? p.onPrimary : p.ink),
        ),
      ),
    );
  }

  Widget _btn(TiltPalette p, String label, VoidCallback onTap, {bool primary = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? p.primary : p.surface,
          border: Border.all(color: p.primary),
        ),
        child: Text(
          label,
          style: soraLabel.copyWith(color: primary ? p.onPrimary : p.primary),
        ),
      ),
    );
  }

  Widget _field(
    TiltPalette p,
    TextEditingController c,
    String hint, {
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: c,
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

  Widget _facet(String color) {
    return CustomPaint(
      painter: ChamferEdgePainter(chamfer: 3, edge: TiltColors.secondary),
      child: ClipPath(
        clipper: const ChamferClipper(chamfer: 3),
        child: ColoredBox(
          color: factorySwatch(color),
          child: const SizedBox(width: 14, height: 14),
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
    if (u == null || a == null) return;
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
                Text('Tilt-a-Wort cal → 1.000', style: soraTitle.copyWith(color: p.primary)),
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
      _prefs.copyWith(cal: [..._prefs.cal, waterCal(currentRaw: _view.rawSg)]),
    );
  }

  Future<void> _startLog() async {
    if (_prefs.name.trim().isEmpty) {
      await _promptName();
      if (_prefs.name.trim().isEmpty) return;
    }
    await widget.logs.startLog(color: _view.color, beer: _prefs.name, at: _now());
    await _setPrefs(_prefs.copyWith(logging: true));
    await _refreshFiles();
  }

  Future<void> _endLog() async {
    await widget.logs.endLog();
    await _setPrefs(_prefs.copyWith(logging: false));
  }

  Future<void> _logOnce() async {
    if (!widget.logs.isOpen) {
      await _startLog();
      if (!widget.logs.isOpen) return;
    }
    final temp = _prefs.tempUnit == 'C' ? fToC(_view.calTempF) : _view.calTempF;
    await widget.logs.append(
      timestamp: _now(),
      sg: _view.calSg,
      temp: temp,
      color: _view.color,
      beer: _prefs.name,
      comment: _comment.text,
    );
    _comment.clear();
    await _refreshFiles();
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
