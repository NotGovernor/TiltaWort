import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/scanner.dart';

/// One manufacturer-data advertisement from the Android scan callback.
class AndroidMfgAd {
  const AndroidMfgAd({
    required this.companyId,
    required this.payload,
    this.rssi,
  });

  final int companyId;
  final List<int> payload;
  final int? rssi;
}

/// Listen-only Android BLE. Implementations must not connect or use GATT.
abstract class AndroidListenClient {
  Stream<RadioState> get radio;
  Stream<AndroidMfgAd> get manufacturerAds;
  Future<void> start();
  Future<void> stop();
}

/// In-process Android scan. Empty filter, manufacturer 0x004C → [decodeTilt].
/// Never connects, never GATT.
class AndroidBleScanner implements TiltScanner {
  AndroidBleScanner({AndroidListenClient? client})
      : _client = client ?? MethodChannelAndroidListenClient();

  final AndroidListenClient _client;
  final _radio = StreamController<RadioState>.broadcast();
  final _ads = StreamController<TiltAdvertisementEvent>.broadcast();
  StreamSubscription<RadioState>? _radioSub;
  StreamSubscription<AndroidMfgAd>? _adSub;

  @override
  Stream<RadioState> get radio => _radio.stream;

  @override
  Stream<TiltAdvertisementEvent> get advertisements => _ads.stream;

  @override
  Future<void> start() async {
    await stop();
    _radioSub = _client.radio.listen(_radio.add);
    _adSub = _client.manufacturerAds.listen(_onAd);
    await _client.start();
  }

  void _onAd(AndroidMfgAd ad) {
    final decoded = decodeTilt(companyId: ad.companyId, payload: ad.payload);
    if (decoded == null) return;
    _ads.add(
      TiltAdvertisementEvent(
        advertisement: decoded,
        receivedAt: DateTime.now(),
        rssiDbm: ad.rssi,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _radioSub?.cancel();
    await _adSub?.cancel();
    _radioSub = null;
    _adSub = null;
    await _client.stop();
  }
}

/// Platform channel to [TiltListenPlugin] (scan only).
class MethodChannelAndroidListenClient implements AndroidListenClient {
  MethodChannelAndroidListenClient({
    MethodChannel? methods,
    EventChannel? events,
  })  : _methods = methods ??
            const MethodChannel('com.notgovernor.tiltawort/listen'),
        _events = events ??
            const EventChannel('com.notgovernor.tiltawort/listen/events');

  final MethodChannel _methods;
  final EventChannel _events;
  final _radio = StreamController<RadioState>.broadcast();
  final _ads = StreamController<AndroidMfgAd>.broadcast();
  StreamSubscription<dynamic>? _sub;

  @override
  Stream<RadioState> get radio => _radio.stream;

  @override
  Stream<AndroidMfgAd> get manufacturerAds => _ads.stream;

  @override
  Future<void> start() async {
    await stop();
    _sub = _events.receiveBroadcastStream().listen(_onEvent);
    try {
      await _methods.invokeMethod<bool>('start');
    } on PlatformException catch (e) {
      stderr.writeln('android listen start failed: $e');
      _radio.add(RadioState.off);
    }
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final map = Map<Object?, Object?>.from(event);
    final type = map['type'] as String?;
    if (type == 'adapter') {
      _radio.add(map['on'] == true ? RadioState.on : RadioState.off);
      return;
    }
    if (type != 'ad') return;
    final company = map['companyId'];
    final raw = map['payload'];
    if (company is! num || raw is! List) return;
    final payload = <int>[];
    for (final b in raw) {
      if (b is num) payload.add(b.toInt());
    }
    final rssi = map['rssi'];
    _ads.add(
      AndroidMfgAd(
        companyId: company.toInt(),
        payload: payload,
        rssi: rssi is num ? rssi.toInt() : null,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _methods.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Host OS / tests without the Android plugin.
    } on PlatformException {
      // Native already stopped.
    }
  }
}
