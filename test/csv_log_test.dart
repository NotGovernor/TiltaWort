import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/units.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tiltawort-csv-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('write two rows, read back header + values', () async {
    final store = CsvLogStore(dir);
    final start = DateTime.utc(2026, 10, 24, 21, 0);
    final file = await store.startLog(
      color: 'Pink',
      beer: 'House Pale',
      at: start,
    );
    await store.append(
      timestamp: start,
      sg: 1.0000,
      temp: 72.0,
      color: 'Pink',
      beer: 'House Pale',
      comment: '',
    );
    await store.append(
      timestamp: start.add(const Duration(seconds: 5)),
      sg: 1.0002,
      temp: 72.4,
      color: 'Pink',
      beer: 'House Pale',
      comment: 'dry hop',
    );

    final text = await file.readAsString();
    final lines = text.trim().split(RegExp(r'\r?\n'));
    expect(lines.first, CsvLogStore.header);
    expect(CsvLogStore.header, 'Timestamp,Timepoint,SG,Plato,Temp,TempUnit,Color,Beer,Comment');
    expect(lines, hasLength(3));
    expect(lines[1], contains('Pink'));
    expect(lines[1], contains('House Pale'));
    expect(lines[2], contains('dry hop'));
    expect(lines[2], contains('1.0002'));
  });

  test('two colors can record at once', () async {
    final store = CsvLogStore(dir);
    final t0 = DateTime.utc(2026, 10, 25, 17, 0);
    final pink = await store.startLog(color: 'Pink', beer: 'Pale', at: t0);
    final black = await store.startLog(color: 'Black', beer: 'Stout', at: t0);
    expect(store.isOpenFor('Pink'), isTrue);
    expect(store.isOpenFor('Black'), isTrue);
    expect(pink.path, isNot(black.path));
    await store.append(
      timestamp: t0,
      sg: 1.010,
      temp: 68,
      color: 'Pink',
      beer: 'Pale',
    );
    await store.append(
      timestamp: t0,
      sg: 1.080,
      temp: 64,
      color: 'Black',
      beer: 'Stout',
    );
    expect(await pink.readAsString(), contains('1.01'));
    expect(await pink.readAsString(), isNot(contains('1.08')));
    expect(await black.readAsString(), contains('1.08'));
    await store.endLog('Pink');
    expect(store.isOpenFor('Pink'), isFalse);
    expect(store.isOpenFor('Black'), isTrue);
  });

  test('listForColor only returns that color', () async {
    final store = CsvLogStore(dir);
    await store.startLog(color: 'Pink', beer: 'Pale', at: DateTime.utc(2026, 10, 24));
    await store.endLog();
    await store.startLog(color: 'Black', beer: 'Stout', at: DateTime.utc(2026, 10, 24));
    await store.endLog();
    final pink = await store.listForColor('Pink');
    expect(pink, hasLength(1));
    expect(pink.first.path, contains('Pink'));
  });

  test('deleteFile of active log ends recording', () async {
    final store = CsvLogStore(dir);
    final f = await store.startLog(color: 'Pink', beer: 'Pale');
    expect(store.isOpen, isTrue);
    await store.deleteFile(f);
    expect(store.isOpen, isFalse);
  });

  test('recordingUi is fileOpen only', () {
    expect(recordingUi(prefsLogging: true, fileOpen: false), isFalse);
    expect(recordingUi(prefsLogging: false, fileOpen: true), isTrue);
    expect(recordingUi(prefsLogging: true, fileOpen: true), isTrue);
  });

  test('interval 900s skips a second append 1s later unless force', () async {
    final store = CsvLogStore(dir);
    final start = DateTime.utc(2026, 10, 25, 13, 0);
    final file = await store.startLog(color: 'Pink', beer: 'Pale', at: start);
    await store.append(
      timestamp: start,
      sg: 1.010,
      temp: 68,
      color: 'Pink',
      beer: 'Pale',
      intervalSeconds: 900,
    );
    await store.append(
      timestamp: start.add(const Duration(seconds: 1)),
      sg: 1.011,
      temp: 68,
      color: 'Pink',
      beer: 'Pale',
      intervalSeconds: 900,
    );
    var lines = (await file.readAsString()).trim().split(RegExp(r'\r?\n'));
    expect(lines, hasLength(2));
    await store.append(
      timestamp: start.add(const Duration(seconds: 2)),
      sg: 1.012,
      temp: 68,
      color: 'Pink',
      beer: 'Pale',
      intervalSeconds: 900,
      force: true,
    );
    lines = (await file.readAsString()).trim().split(RegExp(r'\r?\n'));
    expect(lines, hasLength(3));
    expect(lines[2], contains('1.012'));
  });

  test('shouldWrite is true when closed is false, interval 0 always, first write, then elapsed', () async {
    final store = CsvLogStore(dir);
    final t0 = DateTime.utc(2026, 10, 25, 13, 0);
    expect(store.shouldWrite('Pink', t0, 900), isFalse);
    await store.startLog(color: 'Pink', beer: 'Pale', at: t0);
    expect(store.shouldWrite('Pink', t0, 0), isTrue);
    expect(store.shouldWrite('Pink', t0, 900), isTrue);
    await store.append(
      timestamp: t0,
      sg: 1.000,
      temp: 70,
      color: 'Pink',
      beer: 'Pale',
      intervalSeconds: 900,
    );
    expect(store.shouldWrite('Pink', t0.add(const Duration(seconds: 1)), 900), isFalse);
    expect(store.shouldWrite('Pink', t0.add(const Duration(seconds: 900)), 900), isTrue);
    await store.endLog('Pink');
    expect(store.lastWriteFor('Pink'), isNull);
    expect(store.shouldWrite('Pink', t0.add(const Duration(hours: 1)), 900), isFalse);
  });

  test('row writes Plato from SG and TempUnit', () async {
    final store = CsvLogStore(dir);
    final start = DateTime.utc(2026, 10, 25, 13, 0);
    final file = await store.startLog(color: 'Pink', beer: 'Pale', at: start);
    await store.append(
      timestamp: start,
      sg: 1.040,
      temp: 68.0,
      color: 'Pink',
      beer: 'Pale',
      tempUnit: 'F',
    );
    final lines = (await file.readAsString()).trim().split(RegExp(r'\r?\n'));
    expect(lines.first, 'Timestamp,Timepoint,SG,Plato,Temp,TempUnit,Color,Beer,Comment');
    expect(lines[1], contains('1.04'));
    expect(lines[1], contains(sgToPlato(1.040).toStringAsFixed(2)));
    expect(lines[1], contains(',F,'));
  });

  test('resumeLatest reopens the latest CSV and appends without rewriting the header', () async {
    final store = CsvLogStore(dir);
    final t0 = DateTime.utc(2026, 10, 25, 12);
    final file = await store.startLog(color: 'Pink', beer: 'Pale', at: t0);
    await store.append(
      timestamp: t0,
      sg: 1.040,
      temp: 68,
      color: 'Pink',
      beer: 'Pale',
    );
    await store.endLog('Pink');
    expect(store.isOpenFor('Pink'), isFalse);

    final resumed = await store.resumeLatest('Pink');
    expect(resumed!.path, file.path);
    expect(store.isOpenFor('Pink'), isTrue);
    await store.append(
      timestamp: t0.add(const Duration(minutes: 5)),
      sg: 1.038,
      temp: 67,
      color: 'Pink',
      beer: 'Pale',
    );
    final lines = (await file.readAsString()).trim().split(RegExp(r'\r?\n'));
    expect(lines.first, CsvLogStore.header);
    expect(lines.where((l) => l == CsvLogStore.header), hasLength(1));
    expect(lines, hasLength(3));
    expect(lines.last, contains('1.038'));
  });

  test('samplesFromCsv loads SG temp and skips header', () {
    const text = 'Timestamp,Timepoint,SG,Plato,Temp,TempUnit,Color,Beer,Comment\n'
        '2026-10-25T12:00:00.000Z,0.000000,1.04,10.00,68.0,F,Pink,Pale,\n'
        '2026-10-25T12:05:00.000Z,0.003472,1.038,9.52,67.0,F,Pink,Pale,\n';
    final samples = samplesFromCsv(text);
    expect(samples, hasLength(2));
    expect(samples.first.sg, closeTo(1.04, 1e-9));
    expect(samples.first.tempF, closeTo(68, 1e-9));
    expect(samples.last.sg, closeTo(1.038, 1e-9));
  });
}
