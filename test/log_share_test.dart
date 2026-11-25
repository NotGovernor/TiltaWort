import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/log_share.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/ui/device_page.dart';
import 'package:tiltawort/ui/theme.dart';

const _pink = TiltAdvertisement(
  color: 'Pink',
  uuid: FakeTiltScanner.pinkUuid,
  tempF: 72.0,
  sg: 1.0000,
  isPro: true,
);

class _MemoryPrefs extends PrefsStore {
  _MemoryPrefs() : super(File('memory-share-prefs.json'));
  final _data = <String, TiltPrefs>{};

  @override
  Future<TiltPrefs> load(String uuid) async => _data[uuid] ?? TiltPrefs.defaults;

  @override
  Future<void> save(String uuid, TiltPrefs prefs) async {
    _data[uuid] = prefs;
  }

  @override
  Future<List<String>> loggingUuids() async =>
      [for (final e in _data.entries) if (e.value.logging) e.key];

  @override
  Future<void> remove(String uuid) async {
    _data.remove(uuid);
  }
}

class _FixedLogs extends CsvLogStore {
  _FixedLogs(super.directory, this.files);
  final List<File> files;
  var deleted = 0;

  @override
  Future<List<File>> listForColor(String color) async => files;

  @override
  Future<void> deleteFile(File file) async {
    deleted++;
    files.remove(file);
  }
}

Future<void> _pumpWithLog(
  WidgetTester tester, {
  required CsvLogStore logs,
  required TargetPlatform platform,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final t0 = DateTime.utc(2026, 10, 24, 21, 30);
  await tester.pumpWidget(
    MaterialApp(
      theme: tiltDarkTheme(),
      home: DevicePage(
        scanner: FakeTiltScanner(script: const []),
        initial: TiltView.fromEvent(
          TiltAdvertisementEvent(
            advertisement: _pink,
            receivedAt: t0,
          ),
          name: 'House Pale',
        ),
        prefs: _MemoryPrefs(),
        history: SessionHistory(),
        logs: logs,
        now: () => t0,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  test('Windows / Linux / Mac label is Reveal', () {
    expect(logFileActionLabel(TargetPlatform.windows), 'Reveal');
    expect(logFileActionLabel(TargetPlatform.linux), 'Reveal');
    expect(logFileActionLabel(TargetPlatform.macOS), 'Reveal');
  });

  test('Android / iOS label is Share', () {
    expect(logFileActionLabel(TargetPlatform.android), 'Share');
    expect(logFileActionLabel(TargetPlatform.iOS), 'Share');
  });

  late Directory dir;
  late CsvLogStore logs;
  late File logFile;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tiltawort-share-');
    logFile = File('${dir.path}/House Pale (Pink TILT) 2026-10-24 2130.csv');
    logs = _FixedLogs(Directory('${dir.path}/logs'), [logFile]);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  testWidgets('Android log row says Share, not Reveal', (tester) async {
    await _pumpWithLog(tester, logs: logs, platform: TargetPlatform.android);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Reveal'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('No logs for this color yet.'), findsNothing);
  });

  testWidgets('iOS log row says Share, not Reveal', (tester) async {
    await _pumpWithLog(tester, logs: logs, platform: TargetPlatform.iOS);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Reveal'), findsNothing);
  });

  testWidgets('Windows log row says Reveal, not Share', (tester) async {
    await _pumpWithLog(tester, logs: logs, platform: TargetPlatform.windows);
    expect(find.text('Reveal'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('Delete confirm Cancel leaves the file', (tester) async {
    await _pumpWithLog(tester, logs: logs, platform: TargetPlatform.windows);
    final name = 'House Pale (Pink TILT) 2026-10-24 2130.csv';
    expect(find.text(name), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.text('Delete this log?'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    expect(find.text(name), findsWidgets);
    expect((logs as _FixedLogs).deleted, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Delete this log?'), findsNothing);
    expect(find.text(name), findsOneWidget);
    expect((logs as _FixedLogs).deleted, 0);
  });
}
