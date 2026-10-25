import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/sidecar_protocol.dart';

/// Windows listen-only scanner. Spawns the btleplug sidecar (empty ScanFilter,
/// manufacturer 0x004C only). Never connects, never GATT.
class WindowsBleScanner implements TiltScanner {
  WindowsBleScanner({this.sidecarPath, this.seconds});

  /// Absolute path to `tilt_listen.exe`. Null → search env / next-to-exe / repo.
  final String? sidecarPath;

  /// If set, sidecar exits after this many seconds (live proof). Null → until stop().
  final int? seconds;

  final _radio = StreamController<RadioState>.broadcast();
  final _ads = StreamController<TiltAdvertisementEvent>.broadcast();
  Process? _proc;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  @override
  Stream<RadioState> get radio => _radio.stream;

  @override
  Stream<TiltAdvertisementEvent> get advertisements => _ads.stream;

  @override
  Future<void> start() async {
    if (_proc != null) return;
    final exe = sidecarPath ?? locateTiltListen()?.path;
    if (exe == null) {
      stderr.writeln('tilt_listen.exe not found (set TILTAWORT_LISTEN)');
      _radio.add(RadioState.off);
      return;
    }
    final args = <String>[];
    if (seconds != null) args.addAll(['--seconds', '$seconds']);
    _proc = await Process.start(exe, args, runInShell: false);
    _stdoutSub = _proc!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onStdout);
    _stderrSub = _proc!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => stderr.writeln(line));
  }

  void _onStdout(String line) {
    final parsed = parseSidecarLine(line);
    if (parsed is SidecarAdapterLine) {
      _radio.add(parsed.isOn ? RadioState.on : RadioState.off);
      return;
    }
    if (parsed is SidecarAdLine) {
      final event = eventFromSidecarAd(parsed);
      if (event == null) return;
      final a = event.advertisement;
      stdout.writeln(
        '${a.color} ${a.isPro ? 'Pro' : 'Tilt'} '
        'SG=${a.sg.toStringAsFixed(4)} ${a.tempF.toStringAsFixed(1)}°F '
        'rssi=${event.rssiDbm ?? '?'} dBm',
      );
      _ads.add(event);
    }
  }

  @override
  Future<void> stop() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _proc?.kill();
    try {
      await _proc?.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {}
    _proc = null;
  }
}

File? locateTiltListen() {
  final env = Platform.environment['TILTAWORT_LISTEN'];
  if (env != null && env.isNotEmpty) {
    final f = File(env);
    if (f.existsSync()) return f;
  }
  final names = ['tilt_listen.exe', 'tilt_listen'];
  final dirs = <String>[
    File(Platform.resolvedExecutable).parent.path,
    Directory.current.path,
    '${Directory.current.path}${Platform.pathSeparator}native${Platform.pathSeparator}tilt_listen${Platform.pathSeparator}target${Platform.pathSeparator}release',
  ];
  for (final dir in dirs) {
    for (final name in names) {
      final f = File('$dir${Platform.pathSeparator}$name');
      if (f.existsSync()) return f;
    }
  }
  return null;
}

/// Opens Windows Bluetooth settings. Does not toggle radio itself.
Future<void> openBluetoothSettings() async {
  if (!Platform.isWindows) return;
  await Process.start('explorer.exe', ['ms-settings:bluetooth'], runInShell: false);
}
