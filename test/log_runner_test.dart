import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/log_runner.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';

class _PushScanner implements TiltScanner {
  final _ads = StreamController<TiltAdvertisementEvent>.broadcast();
  final _radio = StreamController<RadioState>.broadcast();

  @override
  Stream<RadioState> get radio => _radio.stream;

  @override
  Stream<TiltAdvertisementEvent> get advertisements => _ads.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  void emit(TiltAdvertisementEvent event) => _ads.add(event);
}

TiltAdvertisementEvent _ad({
  required String color,
  required String uuid,
  required DateTime at,
  double sg = 1.040,
  double tempF = 68,
}) {
  return TiltAdvertisementEvent(
    advertisement: TiltAdvertisement(
      color: color,
      uuid: uuid,
      tempF: tempF,
      sg: sg,
      isPro: true,
    ),
    receivedAt: at,
  );
}

void main() {
  late Directory dir;
  late PrefsStore prefs;
  late CsvLogStore logs;
  late _PushScanner scanner;
  late LogRunner runner;

  const pink = 'A495BB80-C5B1-4B44-B512-1370F02D74DE';
  const black = 'A495BB30-C5B1-4B44-B512-1370F02D74DE';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tiltawort-runner-');
    prefs = PrefsStore(File('${dir.path}/prefs.json'));
    logs = CsvLogStore(Directory('${dir.path}/logs'));
    scanner = _PushScanner();
    runner = LogRunner(scanner: scanner, logs: logs, prefs: prefs);
    runner.attach();
  });

  tearDown(() async {
    await runner.detach();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('closed color is ignored', () async {
    final t0 = DateTime.utc(2026, 10, 25, 17);
    await runner.ingest(_ad(color: 'Pink', uuid: pink, at: t0));
    expect(logs.isOpenFor('Pink'), isFalse);
    expect(await logs.listForColor('Pink'), isEmpty);
  });

  test('startRecording opens that color and sets prefs.logging', () async {
    final t0 = DateTime.utc(2026, 10, 25, 17);
    await runner.startRecording(
      uuid: pink,
      color: 'Pink',
      beer: 'Pale',
      at: t0,
    );
    expect(logs.isOpenFor('Pink'), isTrue);
    expect((await prefs.load(pink)).logging, isTrue);
  });

  test('open color gets a row from an ad', () async {
    final t0 = DateTime.utc(2026, 10, 25, 17);
    await runner.startRecording(
      uuid: pink,
      color: 'Pink',
      beer: 'Pale',
      at: t0,
    );
    await runner.ingest(_ad(color: 'Pink', uuid: pink, at: t0, sg: 1.042));
    final text = await logs.activeFor('Pink')!.readAsString();
    expect(text, contains('1.042'));
    expect(text, contains('Pink'));
  });

  test('two open colors both get rows from ads', () async {
    final t0 = DateTime.utc(2026, 10, 25, 17);
    await runner.startRecording(uuid: pink, color: 'Pink', beer: 'Pale', at: t0);
    await runner.startRecording(uuid: black, color: 'Black', beer: 'Stout', at: t0);
    await runner.ingest(_ad(color: 'Pink', uuid: pink, at: t0, sg: 1.01));
    await runner.ingest(_ad(color: 'Black', uuid: black, at: t0, sg: 1.08));
    expect(await logs.activeFor('Pink')!.readAsString(), contains('1.01'));
    expect(await logs.activeFor('Black')!.readAsString(), contains('1.08'));
    expect(await logs.activeFor('Pink')!.readAsString(), isNot(contains('1.08')));
  });

  test('stopRecording closes the file and clears prefs.logging', () async {
    final t0 = DateTime.utc(2026, 10, 25, 17);
    await runner.startRecording(uuid: pink, color: 'Pink', beer: 'Pale', at: t0);
    await runner.stopRecording(uuid: pink, color: 'Pink');
    expect(logs.isOpenFor('Pink'), isFalse);
    expect((await prefs.load(pink)).logging, isFalse);
  });

  test('snapshot force-writes even inside the interval', () async {
    final t0 = DateTime.utc(2026, 10, 25, 17);
    await prefs.save(pink, const TiltPrefs(logging: false, logIntervalSeconds: 900));
    await runner.startRecording(uuid: pink, color: 'Pink', beer: 'Pale', at: t0);
    await runner.ingest(_ad(color: 'Pink', uuid: pink, at: t0, sg: 1.01));
    await runner.snapshot(
      uuid: pink,
      color: 'Pink',
      beer: 'Pale',
      sg: 1.02,
      tempF: 70,
      at: t0.add(const Duration(seconds: 1)),
      comment: 'check',
    );
    final lines = (await logs.activeFor('Pink')!.readAsString())
        .trim()
        .split(RegExp(r'\r?\n'));
    expect(lines, hasLength(3));
    expect(lines.last, contains('1.02'));
    expect(lines.last, contains('check'));
  });
}
