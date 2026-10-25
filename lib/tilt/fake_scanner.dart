import 'dart:async';

import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/scanner.dart';

class FakeTiltScanner implements TiltScanner {
  FakeTiltScanner({
    List<TiltAdvertisementEvent>? script,
    this.repeat = false,
    this.interval = const Duration(seconds: 5),
    this.initialRadio = RadioState.on,
  }) : script = script ?? pinkProDemo();

  final List<TiltAdvertisementEvent> script;
  final bool repeat;
  final Duration interval;
  final RadioState initialRadio;

  final _radio = StreamController<RadioState>.broadcast();
  final _ads = StreamController<TiltAdvertisementEvent>.broadcast();
  Timer? _timer;
  var _i = 0;
  var _started = false;

  static const pinkUuid = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';

  static List<TiltAdvertisementEvent> pinkProDemo({DateTime? at, int rssi = -97}) {
    return [
      TiltAdvertisementEvent(
        advertisement: const TiltAdvertisement(
          color: 'Pink',
          uuid: pinkUuid,
          tempF: 72.0,
          sg: 1.0000,
          isPro: true,
        ),
        receivedAt: at ?? DateTime.now(),
        rssiDbm: rssi,
      ),
    ];
  }

  @override
  Stream<RadioState> get radio => _radio.stream;

  @override
  Stream<TiltAdvertisementEvent> get advertisements => _ads.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _radio.add(initialRadio);
    if (initialRadio == RadioState.off) return;
    _emitNext();
    if (repeat && script.isNotEmpty) {
      _timer = Timer.periodic(interval, (_) => _emitNext());
    }
  }

  void _emitNext() {
    if (script.isEmpty) return;
    final event = script[_i % script.length];
    _i++;
    _ads.add(
      repeat
          ? TiltAdvertisementEvent(
              advertisement: event.advertisement,
              receivedAt: DateTime.now(),
              rssiDbm: event.rssiDbm,
            )
          : event,
    );
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
