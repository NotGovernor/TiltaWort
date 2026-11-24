import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/scanner.dart';

const kIosBeaconMethodChannel = 'tiltawort/ibeacon';
const kIosBeaconEventChannel = 'tiltawort/ibeacon/events';

typedef IosBeaconInvoke = Future<dynamic> Function(
  String method, [
  dynamic arguments,
]);

/// Native ranging map → same [decodeTiltBeacon] as 0x004C ads.
TiltAdvertisementEvent? eventFromIosBeacon(
  Map<Object?, Object?> map, {
  DateTime? now,
}) {
  if (map['type'] != 'beacon') return null;
  final uuid = map['uuid'];
  final major = map['major'];
  final minor = map['minor'];
  if (uuid is! String || major is! num || minor is! num) return null;
  final decoded = decodeTiltBeacon(
    uuid: uuid,
    major: major.toInt(),
    minor: minor.toInt(),
  );
  if (decoded == null) return null;
  final rssi = map['rssi'];
  return TiltAdvertisementEvent(
    advertisement: decoded,
    receivedAt: now ?? DateTime.now(),
    rssiDbm: rssi is num ? rssi.toInt() : null,
  );
}

/// Listen-only. Ranges eight Tilt UUIDs via Core Location iBeacon regions.
/// Native must not use Core Bluetooth connect / GATT.
class IosBeaconScanner implements TiltScanner {
  IosBeaconScanner({
    IosBeaconInvoke? invoke,
    Stream<dynamic>? events,
  })  : _invoke = invoke ?? _defaultInvoke,
        _events = events ?? _defaultEvents();

  static Future<dynamic> _defaultInvoke(String method, [dynamic arguments]) {
    return const MethodChannel(kIosBeaconMethodChannel)
        .invokeMethod<dynamic>(method, arguments);
  }

  static Stream<dynamic> _defaultEvents() =>
      const EventChannel(kIosBeaconEventChannel).receiveBroadcastStream();

  final IosBeaconInvoke _invoke;
  final Stream<dynamic> _events;

  final _radio = StreamController<RadioState>.broadcast();
  final _ads = StreamController<TiltAdvertisementEvent>.broadcast();
  StreamSubscription<dynamic>? _sub;

  /// The eight Tilt color UUIDs registered as iBeacon regions.
  List<String> get regionUuids => List<String>.unmodifiable(tiltColors.keys);

  @override
  Stream<RadioState> get radio => _radio.stream;

  @override
  Stream<TiltAdvertisementEvent> get advertisements => _ads.stream;

  @override
  Future<void> start() async {
    await stop();
    _sub = _events.listen(_onNative, onError: (_) {
      _radio.add(RadioState.off);
    });
    try {
      await _invoke('start', {'uuids': regionUuids});
    } catch (_) {
      _radio.add(RadioState.off);
    }
  }

  void _onNative(dynamic raw) {
    if (raw is! Map) return;
    final map = Map<Object?, Object?>.from(raw);
    if (map['type'] == 'radio') {
      _radio.add(map['on'] == true ? RadioState.on : RadioState.off);
      return;
    }
    final event = eventFromIosBeacon(map);
    if (event != null) _ads.add(event);
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _invoke('stop');
    } catch (_) {}
  }
}
