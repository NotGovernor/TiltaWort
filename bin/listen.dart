import 'dart:async';
import 'dart:io';

import 'package:tiltawort/tilt/windows_scanner.dart';

/// Live Windows listen. Prints each decoded Tilt ad as it arrives.
///   flutter pub get
///   dart run bin/listen.dart
Future<void> main(List<String> args) async {
  var seconds = 35;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--seconds' && i + 1 < args.length) {
      seconds = int.parse(args[i + 1]);
    }
  }
  final exe = locateTiltListen();
  if (exe == null) {
    stderr.writeln('tilt_listen.exe not found. Build native/tilt_listen (--release).');
    exitCode = 2;
    return;
  }
  stdout.writeln('sidecar: ${exe.path}');
  stdout.writeln('listening ${seconds}s (empty filter, 0x004C only, no GATT)');
  final scanner = WindowsBleScanner(sidecarPath: exe.path, seconds: seconds);
  var n = 0;
  final sub = scanner.advertisements.listen((e) {
    n++;
    final a = e.advertisement;
    stdout.writeln(
      'decoded: ${a.color} ${a.isPro ? 'Pro' : 'Tilt'} '
      'SG=${a.sg.toStringAsFixed(4)} ${a.tempF.toStringAsFixed(1)}°F '
      'rssi=${e.rssiDbm ?? '?'}',
    );
  });
  final radioSub = scanner.radio.listen((s) => stdout.writeln('radio: $s'));
  await scanner.start();
  await Future<void>.delayed(Duration(seconds: seconds + 2));
  await scanner.stop();
  await sub.cancel();
  await radioSub.cancel();
  if (n == 0) {
    stdout.writeln('none in range after ${seconds}s (honest empty; RSSI −94..−103 is still in-room)');
  } else {
    stdout.writeln('heard $n decoded advertisement(s)');
  }
}
