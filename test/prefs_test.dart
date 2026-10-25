import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/calibrate.dart';
import 'package:tiltawort/tilt/prefs.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tiltawort-prefs-');
    file = File('${dir.path}/prefs.json');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('round-trip keyed by color UUID', () async {
    const uuid = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';
    final store = PrefsStore(file);
    await store.save(
      uuid,
      TiltPrefs(
        name: 'House Pale',
        tempUnit: 'F',
        gravityUnit: 'SG',
        cal: const [CalPoint(uncalSg: 1.000, actualSg: 1.000)],
        logging: false,
      ),
    );
    final loaded = await PrefsStore(file).load(uuid);
    expect(loaded.name, 'House Pale');
    expect(loaded.tempUnit, 'F');
    expect(loaded.gravityUnit, 'SG');
    expect(loaded.logging, isFalse);
    expect(loaded.cal, hasLength(1));
    expect(loaded.cal.first.uncalSg, closeTo(1.000, 1e-9));
    expect(loaded.cal.first.actualSg, closeTo(1.000, 1e-9));
  });

  test('unknown uuid returns defaults', () async {
    final loaded = await PrefsStore(file).load('A495BB10-C5B1-4B44-B512-1370F02D74DE');
    expect(loaded.name, '');
    expect(loaded.tempUnit, 'F');
    expect(loaded.gravityUnit, 'SG');
    expect(loaded.cal, isEmpty);
    expect(loaded.logging, isFalse);
    expect(loaded.logIntervalSeconds, 0);
  });

  test('logIntervalSeconds round-trips and defaults to 0', () async {
    const uuid = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';
    final store = PrefsStore(file);
    await store.save(uuid, const TiltPrefs(logIntervalSeconds: 900));
    final loaded = await PrefsStore(file).load(uuid);
    expect(loaded.logIntervalSeconds, 900);
  });
}
