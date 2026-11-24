import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/windows_scanner.dart';

const _ping = r'C:\Windows\System32\ping.exe';

void main() {
  test('forceKillPid reaps a live process (Process.kill is not enough)', () async {
    final proc = await Process.start(_ping, ['-t', '127.0.0.1']);
    addTearDown(() => forceKillPid(proc.pid));
    expect(await pidIsRunning(proc.pid), isTrue);
    await forceKillPid(proc.pid);
    expect(await pidIsRunning(proc.pid), isFalse);
  });

  test('killLeftoverTiltListenExe reaps a dummy named tilt_listen.exe', () async {
    final dir = await Directory.systemTemp.createTemp('tiltawort-orphan-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final dummy = File('${dir.path}${Platform.pathSeparator}tilt_listen.exe');
    await File(_ping).copy(dummy.path);
    final leftover = await Process.start(dummy.path, ['-t', '127.0.0.1']);
    addTearDown(() => forceKillPid(leftover.pid));
    expect(await pidIsRunning(leftover.pid), isTrue);

    await killLeftoverTiltListenExe();
    expect(await pidIsRunning(leftover.pid), isFalse);
  });
}
