import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/create_scanner.dart';
import 'package:tiltawort/tilt/ffi_scanner.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/windows_scanner.dart';

const _ping = r'C:\Windows\System32\ping.exe';

void main() {
  test('missing library is RadioState.off, never invents ads', () async {
    final scanner = FfiBleScanner(
      libraryPath: r'C:\tiltawort-missing\tilt_listen.dll',
    );
    final radio = <RadioState>[];
    final ads = <TiltAdvertisementEvent>[];
    final radioSub = scanner.radio.listen(radio.add);
    final adSub = scanner.advertisements.listen(ads.add);
    await scanner.start();
    await Future<void>.delayed(Duration.zero);
    expect(radio, [RadioState.off]);
    expect(ads, isEmpty);
    await scanner.stop();
    await radioSub.cancel();
    await adSub.cancel();
  });

  test('start() kills leftover tilt_listen.exe even if the dll is missing', () async {
    final dir = await Directory.systemTemp.createTemp('tiltawort-orphan-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final dummy = File('${dir.path}${Platform.pathSeparator}tilt_listen.exe');
    await File(_ping).copy(dummy.path);
    final leftover = await Process.start(dummy.path, ['-t', '127.0.0.1']);
    addTearDown(() => forceKillPid(leftover.pid));
    expect(await pidIsRunning(leftover.pid), isTrue);

    final scanner = FfiBleScanner(
      libraryPath: r'C:\tiltawort-missing\tilt_listen.dll',
    );
    await scanner.start();
    addTearDown(() => scanner.stop());

    expect(await pidIsRunning(leftover.pid), isFalse);
  });

  test('createScanner() on Windows is FfiBleScanner, not a child process', () {
    if (!Platform.isWindows) return;
    final scanner = createScanner();
    expect(scanner, isA<FfiBleScanner>());
  });

  test('built tilt_listen.dll exports start and stop', () {
    if (!Platform.isWindows) return;
    final dll = locateTiltListenLibrary();
    if (dll == null) {
      markTestSkipped('tilt_listen.dll not built');
      return;
    }
    final lib = DynamicLibrary.open(dll.path);
    expect(lib.lookup('tilt_listen_start'), isNotNull);
    expect(lib.lookup('tilt_listen_stop'), isNotNull);
  });
}
