import 'dart:io';

import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/stub_scanner.dart';
import 'package:tiltawort/tilt/windows_scanner.dart';

/// Roller calls this. Default fake so UI ships without the radio.
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
