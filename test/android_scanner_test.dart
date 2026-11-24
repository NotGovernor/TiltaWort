import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/android_scanner.dart';
import 'package:tiltawort/tilt/create_scanner.dart';
import 'package:tiltawort/tilt/ffi_scanner.dart';
import 'package:tiltawort/tilt/scanner.dart';

/// kvurd Red standard Tilt iBeacon manufacturer payload (no 4C 00 prefix).
const redPayload = <int>[
  0x02, 0x15,
  0xA4, 0x95, 0xBB, 0x10, 0xC5, 0xB1, 0x4B, 0x44,
  0xB5, 0x12, 0x13, 0x70, 0xF0, 0x2D, 0x74, 0xDE,
  0x00, 0x44, // major 68
  0x03, 0xF8, // minor 1016
  0xC5,
];

/// Pink Pro: 72.0°F / SG 1.0000 (minor > 5000).
const pinkProPayload = <int>[
  0x02, 0x15,
  0xA4, 0x95, 0xBB, 0x80, 0xC5, 0xB1, 0x4B, 0x44,
  0xB5, 0x12, 0x13, 0x70, 0xF0, 0x2D, 0x74, 0xDE,
  0x02, 0xD0, // 720
  0x27, 0x10, // 10000
  0xC5,
];

class FakeAndroidListenClient implements AndroidListenClient {
  FakeAndroidListenClient({this.startRadio = RadioState.on});

  RadioState startRadio;

  final _radio = StreamController<RadioState>.broadcast();
  final _ads = StreamController<AndroidMfgAd>.broadcast();

  @override
  Stream<RadioState> get radio => _radio.stream;

  @override
  Stream<AndroidMfgAd> get manufacturerAds => _ads.stream;

  @override
  Future<void> start() async {
    _radio.add(startRadio);
  }

  @override
  Future<void> stop() async {}

  void emitAd({
    required int companyId,
    required List<int> payload,
    int? rssi,
  }) {
    _ads.add(
      AndroidMfgAd(companyId: companyId, payload: payload, rssi: rssi),
    );
  }
}

void main() {
  test('createScanner() on Android is AndroidBleScanner', () {
    if (!Platform.isAndroid) {
      markTestSkipped('not Android (this PC is ${Platform.operatingSystem})');
      return;
    }
    expect(createScanner(), isA<AndroidBleScanner>());
  });

  test('createScanner() on Windows stays FFI, not Android', () {
    if (!Platform.isWindows) return;
    expect(createScanner(), isA<FfiBleScanner>());
    expect(createScanner(), isNot(isA<AndroidBleScanner>()));
  });

  test('create_scanner.dart routes Platform.isAndroid to AndroidBleScanner', () {
    final src = File('lib/tilt/create_scanner.dart').readAsStringSync();
    expect(src.contains('Platform.isAndroid'), isTrue);
    expect(src.contains('AndroidBleScanner()'), isTrue);
  });

  test('AndroidBleScanner start with no ads invents none', () async {
    final client = FakeAndroidListenClient();
    final scanner = AndroidBleScanner(client: client);
    final radio = <RadioState>[];
    final ads = <TiltAdvertisementEvent>[];
    final radioSub = scanner.radio.listen(radio.add);
    final adSub = scanner.advertisements.listen(ads.add);
    addTearDown(() async {
      await scanner.stop();
      await radioSub.cancel();
      await adSub.cancel();
    });

    await scanner.start();
    await Future<void>.delayed(Duration.zero);
    expect(radio, [RadioState.on]);
    expect(ads, isEmpty);
  });

  test('AndroidBleScanner radio off emits no ads', () async {
    final client = FakeAndroidListenClient(startRadio: RadioState.off);
    final scanner = AndroidBleScanner(client: client);
    final radio = <RadioState>[];
    final ads = <TiltAdvertisementEvent>[];
    final radioSub = scanner.radio.listen(radio.add);
    final adSub = scanner.advertisements.listen(ads.add);
    addTearDown(() async {
      await scanner.stop();
      await radioSub.cancel();
      await adSub.cancel();
    });

    await scanner.start();
    await Future<void>.delayed(Duration.zero);
    expect(radio, [RadioState.off]);
    expect(ads, isEmpty);
  });

  test('0x004C Red vector decodes; wrong company and junk dropped', () async {
    final client = FakeAndroidListenClient();
    final scanner = AndroidBleScanner(client: client);
    final ads = <TiltAdvertisementEvent>[];
    final sub = scanner.advertisements.listen(ads.add);
    addTearDown(() async {
      await scanner.stop();
      await sub.cancel();
    });
    await scanner.start();

    client.emitAd(companyId: 0x004C, payload: redPayload, rssi: -81);
    await Future<void>.delayed(Duration.zero);
    expect(ads, hasLength(1));
    expect(ads.single.advertisement.color, 'Red');
    expect(ads.single.advertisement.isPro, isFalse);
    expect(ads.single.advertisement.tempF, 68.0);
    expect(ads.single.advertisement.sg, closeTo(1.016, 1e-9));
    expect(ads.single.rssiDbm, -81);

    client.emitAd(companyId: 0x0075, payload: redPayload, rssi: -40);
    client.emitAd(
      companyId: 0x004C,
      payload: [0x02, 0x15, ...List.filled(21, 0)],
      rssi: -40,
    );
    await Future<void>.delayed(Duration.zero);
    expect(ads, hasLength(1));
  });

  test('0x004C Pink Pro vector', () async {
    final client = FakeAndroidListenClient();
    final scanner = AndroidBleScanner(client: client);
    final ads = <TiltAdvertisementEvent>[];
    final sub = scanner.advertisements.listen(ads.add);
    addTearDown(() async {
      await scanner.stop();
      await sub.cancel();
    });
    await scanner.start();

    client.emitAd(companyId: 0x004C, payload: pinkProPayload, rssi: -97);
    await Future<void>.delayed(Duration.zero);
    expect(ads, hasLength(1));
    expect(ads.single.advertisement.color, 'Pink');
    expect(ads.single.advertisement.isPro, isTrue);
    expect(ads.single.advertisement.tempF, closeTo(72.0, 1e-9));
    expect(ads.single.advertisement.sg, closeTo(1.0000, 1e-9));
    expect(ads.single.rssiDbm, -97);
  });

  test('android dart+kotlin sources never connect or GATT', () {
    const dartPath = 'lib/tilt/android_scanner.dart';
    const kotlinPath =
        'android/app/src/main/kotlin/com/notgovernor/tiltawort/TiltListenPlugin.kt';
    final dart = File(dartPath).readAsStringSync();
    final kotlin = File(kotlinPath).readAsStringSync();
    expect(RegExp(r'\.connect\s*\(').hasMatch(dart), isFalse);
    expect(RegExp(r'\.connect\s*\(').hasMatch(kotlin), isFalse);
    expect(dart.contains('BluetoothGatt'), isFalse);
    expect(kotlin.contains('BluetoothGatt'), isFalse);
    expect(dart.contains('discoverServices'), isFalse);
    expect(kotlin.contains('discoverServices'), isFalse);
    expect(kotlin.contains('startScan'), isTrue);
    expect(kotlin.contains('0x004C'), isTrue);
  });

  test('manifest: SCAN without neverForLocation; FINE_LOCATION not capped at 30', () {
    final xml =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(xml.contains('android.permission.BLUETOOTH_SCAN'), isTrue);
    expect(xml.contains('usesPermissionFlags="neverForLocation"'), isFalse);
    expect(xml.contains('android.permission.BLUETOOTH_CONNECT'), isTrue);
    expect(xml.contains('ACCESS_FINE_LOCATION'), isTrue);
    final loc = xml.indexOf('android.permission.ACCESS_FINE_LOCATION');
    expect(loc, isNonNegative);
    final locTag = xml.substring(loc, xml.indexOf('/>', loc));
    expect(locTag.contains('maxSdkVersion'), isFalse);
    expect(xml.contains('ACCESS_BACKGROUND_LOCATION'), isFalse);
  });

  test('kotlin requests FINE_LOCATION on API 31+ with SCAN/CONNECT', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/notgovernor/tiltawort/TiltListenPlugin.kt',
    ).readAsStringSync();
    final start = kotlin.indexOf('private fun neededPermissions()');
    final end = kotlin.indexOf('private fun hasPermissions()');
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final fn = kotlin.substring(start, end);
    final sStart = fn.indexOf('VERSION_CODES.S');
    final sEnd = fn.indexOf('} else {');
    expect(sStart, isNonNegative);
    expect(sEnd, greaterThan(sStart));
    final sBranch = fn.substring(sStart, sEnd);
    expect(sBranch.contains('BLUETOOTH_SCAN'), isTrue);
    expect(sBranch.contains('BLUETOOTH_CONNECT'), isTrue);
    expect(sBranch.contains('ACCESS_FINE_LOCATION'), isTrue);
    expect(kotlin.contains('ACCESS_BACKGROUND_LOCATION'), isFalse);
  });
}
