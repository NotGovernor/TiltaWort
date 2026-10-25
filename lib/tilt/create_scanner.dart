import 'dart:io';

import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/stub_scanner.dart';
import 'package:tiltawort/tilt/windows_scanner.dart';

/// Live Windows → [WindowsBleScanner]. Tests inject [FakeTiltScanner].
TiltScanner createScanner() {
  if (kUseFakeScanner) {
    return FakeTiltScanner(
      script: FakeTiltScanner.pinkProDemo(),
      repeat: true,
    );
  }
  if (Platform.isWindows) return WindowsBleScanner();
  return StubScanner();
}
