import 'dart:io';

import 'package:tiltawort/tilt/android_scanner.dart';
import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/ffi_scanner.dart';
import 'package:tiltawort/tilt/ios_scanner.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/stub_scanner.dart';

/// Live Windows → [FfiBleScanner] (in-process cdylib).
/// Android → [AndroidBleScanner] (in-process scan, no GATT).
/// iOS → [IosBeaconScanner] (Core Location iBeacon regions, no connect).
/// Tests inject [FakeTiltScanner].
TiltScanner createScanner() {
  if (kUseFakeScanner) {
    return FakeTiltScanner(
      script: FakeTiltScanner.pinkProDemo(),
      repeat: true,
    );
  }
  if (Platform.isWindows) return FfiBleScanner();
  if (Platform.isAndroid) return AndroidBleScanner();
  if (Platform.isIOS) return IosBeaconScanner();
  if ((Platform.isLinux || Platform.isMacOS) &&
      locateTiltListenLibrary() != null) {
    return FfiBleScanner();
  }
  return StubScanner();
}
