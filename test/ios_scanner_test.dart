import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/create_scanner.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/ffi_scanner.dart';
import 'package:tiltawort/tilt/ios_scanner.dart';
import 'package:tiltawort/tilt/scanner.dart';

void main() {
  const pinkUuid = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';
  const redUuid = 'A495BB10-C5B1-4B44-B512-1370F02D74DE';

  test('eventFromIosBeacon Pink Pro matches decodeTiltBeacon', () {
    final event = eventFromIosBeacon(
      {
        'type': 'beacon',
        'uuid': pinkUuid.toLowerCase(),
        'major': 720,
        'minor': 10000,
        'rssi': -97,
      },
      now: DateTime.utc(2026, 10, 25),
    )!;
    expect(event.advertisement.color, 'Pink');
    expect(event.advertisement.isPro, isTrue);
    expect(event.advertisement.tempF, closeTo(72.0, 1e-9));
    expect(event.advertisement.sg, closeTo(1.0000, 1e-9));
    expect(event.rssiDbm, -97);
  });

  test('eventFromIosBeacon Red standard Tilt', () {
    final event = eventFromIosBeacon({
      'type': 'beacon',
      'uuid': redUuid,
      'major': 68,
      'minor': 1016,
      'rssi': -80,
    })!;
    expect(event.advertisement.color, 'Red');
    expect(event.advertisement.isPro, isFalse);
    expect(event.advertisement.tempF, 68.0);
    expect(event.advertisement.sg, closeTo(1.016, 1e-9));
  });

  test('unknown UUID and non-beacon maps are dropped', () {
    expect(
      eventFromIosBeacon({
        'type': 'beacon',
        'uuid': '00000000-0000-0000-0000-000000000000',
        'major': 1,
        'minor': 1,
      }),
      isNull,
    );
    expect(eventFromIosBeacon({'type': 'radio', 'on': true}), isNull);
  });

  test('start ranges the eight Tilt UUIDs and never connect', () async {
    final log = <String>[];
    Object? startArgs;
    final native = StreamController<dynamic>.broadcast();
    addTearDown(native.close);
    final scanner = IosBeaconScanner(
      invoke: (method, [arguments]) async {
        log.add(method);
        if (method == 'start') startArgs = arguments;
        return null;
      },
      events: native.stream,
    );
    final radio = <RadioState>[];
    final ads = <TiltAdvertisementEvent>[];
    final radioSub = scanner.radio.listen(radio.add);
    final adSub = scanner.advertisements.listen(ads.add);
    addTearDown(() async {
      await radioSub.cancel();
      await adSub.cancel();
      await scanner.stop();
    });

    await scanner.start();
    expect(log, isNot(contains('connect')));
    expect(log, isNot(contains('gatt')));
    expect(log.contains('start'), isTrue);
    expect(scanner.regionUuids, hasLength(8));
    expect(scanner.regionUuids, tiltColors.keys);
    final uuids = (startArgs as Map)['uuids'] as List;
    expect(uuids, scanner.regionUuids);

    native.add({'type': 'radio', 'on': true});
    native.add({
      'type': 'beacon',
      'uuid': pinkUuid,
      'major': 790,
      'minor': 10003,
      'rssi': -99,
    });
    native.add({
      'type': 'beacon',
      'uuid': 'not-a-tilt',
      'major': 1,
      'minor': 1,
    });
    await Future<void>.delayed(Duration.zero);
    expect(radio, [RadioState.on]);
    expect(ads, hasLength(1));
    expect(ads.first.advertisement.color, 'Pink');
    expect(ads.first.advertisement.tempF, closeTo(79.0, 1e-9));
    expect(ads.first.advertisement.sg, closeTo(1.0003, 1e-9));
  });

  test('start() invoke failure is RadioState.off, no invented ads', () async {
    final scanner = IosBeaconScanner(
      invoke: (method, [arguments]) async {
        if (method == 'start') throw Exception('no plugin');
      },
      events: const Stream.empty(),
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

  test('createScanner() on iOS is IosBeaconScanner', () {
    if (!Platform.isIOS) return;
    expect(createScanner(), isA<IosBeaconScanner>());
  });

  test('create_scanner.dart routes Platform.isIOS to IosBeaconScanner', () {
    final src = File('lib/tilt/create_scanner.dart').readAsStringSync();
    expect(src.contains('Platform.isIOS'), isTrue);
    expect(src.contains('IosBeaconScanner()'), isTrue);
  });

  test('createScanner() on Windows is still FfiBleScanner', () {
    if (!Platform.isWindows) return;
    expect(createScanner(), isA<FfiBleScanner>());
  });

  test('iOS sources have no CoreBluetooth connect/GATT', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('startRangingBeacons'));
    expect(swift, contains('CLBeaconIdentityConstraint'));
    expect(swift, isNot(contains('import CoreBluetooth')));
    expect(swift, isNot(contains('CBCentralManager')));
    expect(swift, isNot(contains('connectPeripheral')));
    expect(swift, isNot(contains('writeValue')));
    final dart = File('lib/tilt/ios_scanner.dart').readAsStringSync();
    expect(dart, contains("invoke('start'"));
    expect(dart, isNot(contains('connectPeripheral')));
    expect(dart, isNot(contains('writeCharacteristic')));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSLocationWhenInUseUsageDescription'));
    expect(plist, contains('NSBluetoothAlwaysUsageDescription'));
  });
}
