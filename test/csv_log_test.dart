import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/csv_log.dart';

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
    expect(CsvLogStore.header, 'Timestamp,Timepoint,SG,Temp,Color,Beer,Comment');
    expect(lines, hasLength(3));
    expect(lines[1], contains('Pink'));
    expect(lines[1], contains('House Pale'));
    expect(lines[2], contains('dry hop'));
    expect(lines[2], contains('1.0002'));
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
}
