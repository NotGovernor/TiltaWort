import 'dart:async';

import 'package:tiltawort/tilt/decode.dart';

/// Default true so Roller can ship UI without the radio.
/// Live Windows listen: `--dart-define=USE_FAKE_SCANNER=false`.
const kUseFakeScanner = bool.fromEnvironment(
  'USE_FAKE_SCANNER',
  defaultValue: true,
);

enum RadioState { off, on }

enum AppScanStatus { radioOff, scanning, heard, empty }

class TiltAdvertisementEvent {
  const TiltAdvertisementEvent({
    required this.advertisement,
    required this.receivedAt,
    this.rssiDbm,
  });

  final TiltAdvertisement advertisement;
  final DateTime receivedAt;
  final int? rssiDbm;
}

/// Listen-only. Implementations must not call BLE connect or GATT.
abstract class TiltScanner {
  Stream<RadioState> get radio;
  Stream<TiltAdvertisementEvent> get advertisements;
  Future<void> start();
  Future<void> stop();
}
