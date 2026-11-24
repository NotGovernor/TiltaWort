import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/sidecar_protocol.dart';
import 'package:tiltawort/tilt/windows_scanner.dart';

typedef TiltListenCbNative = Void Function(
  Pointer<Char> line,
  Pointer<Void> user,
);
typedef TiltListenStartNative = Int32 Function(
  Pointer<NativeFunction<TiltListenCbNative>> cb,
  Pointer<Void> user,
);
typedef TiltListenStart = int Function(
  Pointer<NativeFunction<TiltListenCbNative>> cb,
  Pointer<Void> user,
);
typedef TiltListenStopNative = Void Function();
typedef TiltListenStop = void Function();

/// In-process listen-only scanner. Loads `tilt_listen` cdylib (btleplug 0.13.5).
/// Empty ScanFilter, manufacturer 0x004C only. Never connects, never GATT.
class FfiBleScanner implements TiltScanner {
  FfiBleScanner({this.libraryPath});

  /// Absolute path to the cdylib. Null → next-to-exe / repo release dir.
  final String? libraryPath;

  final _radio = StreamController<RadioState>.broadcast();
  final _ads = StreamController<TiltAdvertisementEvent>.broadcast();

  TiltListenStart? _startFn;
  TiltListenStop? _stopFn;
  NativeCallable<TiltListenCbNative>? _cb;
  bool _running = false;

  @override
  Stream<RadioState> get radio => _radio.stream;

  @override
  Stream<TiltAdvertisementEvent> get advertisements => _ads.stream;

  @override
  Future<void> start() async {
    await stop();
    await killLeftoverTiltListenExe();
    final path = libraryPath ?? locateTiltListenLibrary()?.path;
    if (path == null || !File(path).existsSync()) {
      _radio.add(RadioState.off);
      return;
    }
    try {
      final lib = DynamicLibrary.open(path);
      _startFn = lib.lookupFunction<TiltListenStartNative, TiltListenStart>(
        'tilt_listen_start',
      );
      _stopFn = lib.lookupFunction<TiltListenStopNative, TiltListenStop>(
        'tilt_listen_stop',
      );
    } catch (e) {
      stderr.writeln('tilt_listen load failed: $e');
      _radio.add(RadioState.off);
      return;
    }
    final callable = NativeCallable<TiltListenCbNative>.listener(_onNativeLine);
    _cb = callable;
    final rc = _startFn!(callable.nativeFunction, nullptr);
    if (rc != 0) {
      stderr.writeln('tilt_listen_start failed: $rc');
      callable.close();
      _cb = null;
      _radio.add(RadioState.off);
      return;
    }
    _running = true;
  }

  void _onNativeLine(Pointer<Char> line, Pointer<Void> user) {
    if (line == nullptr) return;
    try {
      final parsed = parseSidecarLine(_readCString(line));
      if (parsed is SidecarAdapterLine) {
        _radio.add(parsed.isOn ? RadioState.on : RadioState.off);
        return;
      }
      if (parsed is SidecarAdLine) {
        final event = eventFromSidecarAd(parsed);
        if (event == null) return;
        _ads.add(event);
      }
    } catch (e) {
      stderr.writeln('tilt_listen cb: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (_running) {
      try {
        _stopFn?.call();
      } catch (_) {}
      _running = false;
    }
    _cb?.close();
    _cb = null;
  }
}

String _readCString(Pointer<Char> ptr) {
  final units = <int>[];
  for (var i = 0; ; i++) {
    final b = ptr[i];
    if (b == 0) break;
    units.add(b & 0xff);
  }
  return utf8.decode(units);
}

File? locateTiltListenLibrary() {
  final env = Platform.environment['TILTAWORT_LISTEN'];
  if (env != null && env.isNotEmpty) {
    final f = File(env);
    if (f.existsSync()) return f;
  }
  final names = <String>[
    if (Platform.isWindows) 'tilt_listen.dll',
    if (Platform.isMacOS) ...['libtilt_listen.dylib', 'tilt_listen.dylib'],
    if (Platform.isLinux) ...['libtilt_listen.so', 'tilt_listen.so'],
  ];
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
