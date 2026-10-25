import 'dart:async';

import 'package:tiltawort/tilt/scanner.dart';

/// Other OS: radio assumed on, no advertisements. No BLE calls.
class StubScanner implements TiltScanner {
  final _radio = StreamController<RadioState>.broadcast();
  final _ads = StreamController<TiltAdvertisementEvent>.broadcast();

  @override
  Stream<RadioState> get radio => _radio.stream;

  @override
  Stream<TiltAdvertisementEvent> get advertisements => _ads.stream;

  @override
  Future<void> start() async {
    _radio.add(RadioState.on);
  }

  @override
  Future<void> stop() async {}
}
