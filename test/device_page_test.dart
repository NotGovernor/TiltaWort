import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/history.dart';
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
  _MemoryPrefs() : super(File('memory-device-prefs.json'));

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

Future<void> _pumpDevice(
  WidgetTester tester, {
  required TiltScanner scanner,
  required TiltView view,
  required PrefsStore prefs,
  required SessionHistory history,
  required CsvLogStore logs,
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: tiltDarkTheme(),
      home: DevicePage(
        scanner: scanner,
        initial: view,
        prefs: prefs,
        history: history,
        logs: logs,
        now: now,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _allText(WidgetTester tester) {
  final bits = <String>[];
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    if (w.data != null) {
      bits.add(w.data!);
    } else if (w.textSpan != null) {
      bits.add(w.textSpan!.toPlainText());
    }
  }
  return bits.join(' | ');
}

void main() {
  late Directory dir;
  late PrefsStore prefs;
  late CsvLogStore logs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tiltawort-device-');
    prefs = PrefsStore(File('${dir.path}/prefs.json'));
    logs = CsvLogStore(Directory('${dir.path}/logs'));
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  TiltView pinkView(DateTime t0) => TiltView.fromEvent(
        TiltAdvertisementEvent(
          advertisement: _pink,
          receivedAt: t0,
          rssiDbm: -97,
        ),
        name: 'House Pale',
      );

  testWidgets('header, hero, freshness, empty chart; never Connected',
      (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    final scanner = FakeTiltScanner(script: const []);
    await _pumpDevice(
      tester,
      scanner: scanner,
      view: pinkView(t0),
      prefs: prefs,
      history: SessionHistory(),
      logs: logs,
      now: () => t0,
    );

    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Pink'), findsOneWidget);
    expect(find.text('House Pale'), findsWidgets);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('1.0000'), findsWidgets);
    expect(find.textContaining('Uncalibrated'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.textContaining('ago'), findsOneWidget);
    expect(find.textContaining('-97 dBm'), findsOneWidget);
    expect(find.text('No samples yet'), findsOneWidget);
    expect(_allText(tester).toLowerCase().contains('connected'), isFalse);
  });

  testWidgets('samples hide empty copy and do not invent a flat 1.000',
      (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    final history = SessionHistory()
      ..add(
        FakeTiltScanner.pinkUuid,
        SessionSample(at: t0, sg: 1.012, tempF: 68),
      )
      ..add(
        FakeTiltScanner.pinkUuid,
        SessionSample(at: t0.add(const Duration(seconds: 5)), sg: 1.011, tempF: 68.2),
      );
    final scanner = FakeTiltScanner(script: const []);
    await _pumpDevice(
      tester,
      scanner: scanner,
      view: pinkView(t0),
      prefs: prefs,
      history: history,
      logs: logs,
      now: () => t0,
    );
    expect(find.text('No samples yet'), findsNothing);
  });

  testWidgets('cal shortcut copy and confirm', (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    final scanner = FakeTiltScanner(script: const []);
    await _pumpDevice(
      tester,
      scanner: scanner,
      view: pinkView(t0),
      prefs: prefs,
      history: SessionHistory(),
      logs: logs,
      now: () => t0,
    );
    expect(find.text('Tilt-a-Wort water cal → 1.000'), findsOneWidget);
    await tester.ensureVisible(find.text('Tilt-a-Wort water cal → 1.000'));
    await tester.tap(find.text('Tilt-a-Wort water cal → 1.000'));
    await tester.pumpAndSettle();
    expect(find.text('Does not tare the float.'), findsOneWidget);
  });

  testWidgets('units are F/C and SG/P only', (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    final scanner = FakeTiltScanner(script: const []);
    await _pumpDevice(
      tester,
      scanner: scanner,
      view: pinkView(t0),
      prefs: prefs,
      history: SessionHistory(),
      logs: logs,
      now: () => t0,
    );
    expect(find.text('°F'), findsWidgets);
    expect(find.text('°C'), findsOneWidget);
    expect(find.text('SG'), findsWidgets);
    expect(find.text('°P'), findsOneWidget);
    expect(find.text('ABV'), findsNothing);
    expect(find.text('Brix'), findsNothing);
    expect(find.text('proof'), findsNothing);
  });

  testWidgets('logging controls present', (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    final scanner = FakeTiltScanner(script: const []);
    await _pumpDevice(
      tester,
      scanner: scanner,
      view: pinkView(t0),
      prefs: prefs,
      history: SessionHistory(),
      logs: logs,
      now: () => t0,
    );
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('Stop recording'), findsOneWidget);
    expect(find.text('Snapshot'), findsOneWidget);
    expect(find.text('Forget this Tilt'), findsOneWidget);
    expect(find.text('Not recording'), findsOneWidget);
    expect(find.text('Off'), findsNothing);
    expect(find.text('On'), findsNothing);
    expect(find.text('Start log'), findsNothing);
  });

  testWidgets('start recording then delete file shows Not recording',
      (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    await tester.runAsync(() async {
      await logs.startLog(color: 'Pink', beer: 'House Pale', at: t0);
    });
    expect(logs.isOpen, isTrue);

    final scanner = FakeTiltScanner(script: const []);
    await _pumpDevice(
      tester,
      scanner: scanner,
      view: pinkView(t0),
      prefs: prefs,
      history: SessionHistory(),
      logs: logs,
      now: () => t0,
    );

    expect(find.textContaining('Recording ·'), findsOneWidget);
    expect(find.text('Not recording'), findsNothing);

    await tester.runAsync(() async {
      await logs.deleteFile(logs.active!);
    });
    await tester.pump(const Duration(seconds: 1));

    expect(logs.isOpen, isFalse);
    expect(find.text('Not recording'), findsOneWidget);
    expect(find.textContaining('Recording ·'), findsNothing);
  });

  testWidgets('gravity help shows Plato formula', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    await _pumpDevice(
      tester,
      scanner: FakeTiltScanner(script: const []),
      view: pinkView(t0),
      prefs: prefs,
      history: SessionHistory(),
      logs: logs,
      now: () => t0,
    );
    await tester.tap(find.text('?'));
    await tester.pump();
    expect(find.textContaining('259 − (259 / SG)'), findsOneWidget);
  });

  testWidgets('empty name unfocus becomes Untitled', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    await _pumpDevice(
      tester,
      scanner: FakeTiltScanner(script: const []),
      view: pinkView(t0),
      prefs: prefs,
      history: SessionHistory(),
      logs: logs,
      now: () => t0,
    );
    await tester.tap(find.text('Clear'));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Untitled'), findsOneWidget);
  });

  testWidgets('bad cal point shows an error', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    await _pumpDevice(
      tester,
      scanner: FakeTiltScanner(script: const []),
      view: pinkView(t0),
      prefs: prefs,
      history: SessionHistory(),
      logs: logs,
      now: () => t0,
    );
    await tester.tap(find.text('Add point'));
    await tester.pump();
    expect(
      find.text('Need numbers in both Uncal SG and Actual SG.'),
      findsOneWidget,
    );
  });

  testWidgets('Forget this Tilt removes prefs', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    const uuid = FakeTiltScanner.pinkUuid;
    final mem = _MemoryPrefs();
    await mem.save(uuid, const TiltPrefs(name: 'House Pale', logging: true));
    await _pumpDevice(
      tester,
      scanner: FakeTiltScanner(script: const []),
      view: pinkView(t0),
      prefs: mem,
      history: SessionHistory(),
      logs: logs,
      now: () => t0,
    );
    await tester.tap(find.text('Forget this Tilt'));
    await tester.pump();
    final loaded = await mem.load(uuid);
    expect(loaded.name, '');
    expect(loaded.logging, isFalse);
  });
}
