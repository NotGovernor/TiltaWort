import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/app.dart';
import 'package:tiltawort/tilt/calibrate.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/ui/chamfer.dart';
import 'package:tiltawort/ui/home_page.dart';
import 'package:tiltawort/ui/theme.dart';

const _pink = TiltAdvertisement(
  color: 'Pink',
  uuid: FakeTiltScanner.pinkUuid,
  tempF: 72.0,
  sg: 1.0000,
  isPro: true,
);

const _black = TiltAdvertisement(
  color: 'Black',
  uuid: 'A495BB30-C5B1-4B44-B512-1370F02D74DE',
  tempF: 64.0,
  sg: 1.021,
  isPro: false,
);

/// In-memory store so widget tests do not wait on dart:io inside fake async.
class _MemoryPrefs extends PrefsStore {
  _MemoryPrefs() : super(File('memory-prefs.json'));

  final _data = <String, TiltPrefs>{};

  @override
  Future<TiltPrefs> load(String uuid) async =>
      _data[uuid] ?? TiltPrefs.defaults;

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

class _MemoryLogs extends CsvLogStore {
  _MemoryLogs() : super(Directory('memory-logs'));

  DateTime heard = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<DateTime> lastHeardForColor(String color) async => heard;

  @override
  Future<List<File>> listForColor(String color) async => const [];

  @override
  Future<File?> resumeLatest(String color) async => null;
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required TiltScanner scanner,
  List<TiltView> seed = const [],
  DateTime Function()? now,
  Map<String, String> names = const {},
  PrefsStore? prefs,
  CsvLogStore? logs,
  ThemeData? theme,
  ThemeMode themeMode = ThemeMode.dark,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? tiltDarkTheme(),
      darkTheme: tiltDarkTheme(),
      themeMode: themeMode,
      home: HomePage(
        scanner: scanner,
        seed: seed,
        now: now,
        names: names,
        prefs: prefs,
        logs: logs,
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
  testWidgets('Pink live tile: color, cal SG, temp, Live; no Connected/RSSI/Pro/time',
      (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    final scanner = FakeTiltScanner(
      script: [
        TiltAdvertisementEvent(advertisement: _pink, receivedAt: t0, rssiDbm: -97),
      ],
    );
    await _pumpHome(tester, scanner: scanner, now: () => t0);

    expect(find.text('Tilt-a-Wort'), findsNothing);
    expect(find.image(const AssetImage('assets/brand/wordmark-dark.png')), findsNothing);
    expect(find.image(const AssetImage('assets/brand/wordmark-light.png')), findsNothing);
    expect(find.byTooltip('App settings'), findsOneWidget);
    expect(find.text('Pink'), findsOneWidget);
    expect(find.text('1.0000'), findsOneWidget);
    expect(find.text('72.0 °F'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Scanning · heard 1'), findsOneWidget);

    final text = _allText(tester);
    expect(text.toLowerCase().contains('connected'), isFalse);
    expect(text.contains('RSSI'), isFalse);
    expect(text.contains('-97'), isFalse);
    expect(text.contains('Pro'), isFalse);
    expect(text.contains('Untitled'), isFalse);
  });

  testWidgets('beer name only if set', (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    final scanner = FakeTiltScanner(
      script: [
        TiltAdvertisementEvent(advertisement: _pink, receivedAt: t0),
      ],
    );
    await _pumpHome(
      tester,
      scanner: scanner,
      now: () => t0,
      names: {FakeTiltScanner.pinkUuid: 'House Pale'},
    );
    expect(find.text('House Pale'), findsOneWidget);
  });

  testWidgets('stale remembered tile keeps last SG and says Stale', (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    final staleAt = t0.subtract(const Duration(seconds: 31));
    final scanner = FakeTiltScanner(script: const []);
    await _pumpHome(
      tester,
      scanner: scanner,
      now: () => t0,
      seed: [
        TiltView.fromEvent(
          TiltAdvertisementEvent(advertisement: _black, receivedAt: staleAt),
          name: 'Dry Stout',
        ),
      ],
    );
    expect(find.text('Black'), findsOneWidget);
    expect(find.text('Dry Stout'), findsOneWidget);
    expect(find.text('1.021'), findsOneWidget);
    expect(find.text('64 °F'), findsOneWidget);
    expect(find.text('Stale'), findsOneWidget);
    expect(find.text('Live'), findsNothing);
    expect(find.text('Scanning · none live'), findsOneWidget);
  });

  testWidgets('dark Home paints FacetedMesh', (tester) async {
    final scanner = FakeTiltScanner(script: const []);
    await _pumpHome(tester, scanner: scanner);
    expect(find.byType(FacetedMesh), findsOneWidget);
    expect(find.textContaining('Connected'), findsNothing);
  });

  testWidgets('empty home copy when radio on and nothing heard', (tester) async {
    final scanner = FakeTiltScanner(script: const []);
    await _pumpHome(tester, scanner: scanner);
    expect(
      find.text(
        'No Tilts heard. They broadcast about every 5 seconds. This app only listens.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Connected'), findsNothing);
  });

  testWidgets('radio off banner', (tester) async {
    final scanner = FakeTiltScanner(
      script: const [],
      initialRadio: RadioState.off,
    );
    await _pumpHome(tester, scanner: scanner);
    expect(find.text('Bluetooth is off. This app only listens.'), findsOneWidget);
    expect(find.text('Open Bluetooth settings'), findsOneWidget);
    expect(find.textContaining('Connected'), findsNothing);
  });

  testWidgets('gear opens settings', (tester) async {
    final scanner = FakeTiltScanner(script: const []);
    await tester.pumpWidget(TiltawortApp(scanner: scanner, seed: const []));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byTooltip('App settings'));
    await tester.pumpAndSettle();
    expect(find.text('App Settings'), findsOneWidget);
  });

  testWidgets('tap tile opens device', (tester) async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 30);
    final scanner = FakeTiltScanner(
      script: [
        TiltAdvertisementEvent(advertisement: _pink, receivedAt: t0, rssiDbm: -97),
      ],
    );
    await _pumpHome(
      tester,
      scanner: scanner,
      now: () => t0,
      names: {FakeTiltScanner.pinkUuid: 'House Pale'},
    );
    await tester.tap(find.text('Pink'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Back'), findsOneWidget);
    expect(find.textContaining('Connected'), findsNothing);
  });

  test('kUseFakeScanner defaults false', () {
    expect(kUseFakeScanner, isFalse);
  });

  testWidgets('prefs cal point changes Home SG; remembered name survives rescan',
      (tester) async {
    final t0 = DateTime.utc(2026, 10, 25, 0, 50);
    final prefs = _MemoryPrefs();
    await prefs.save(
      FakeTiltScanner.pinkUuid,
      const TiltPrefs(
        name: 'House Pale',
        cal: [CalPoint(uncalSg: 1.000, actualSg: 1.004)],
      ),
    );
    final scanner = FakeTiltScanner(
      script: [
        TiltAdvertisementEvent(advertisement: _pink, receivedAt: t0),
      ],
    );
    await _pumpHome(
      tester,
      scanner: scanner,
      now: () => t0,
      prefs: prefs,
    );

    expect(find.text('House Pale'), findsOneWidget);
    expect(find.text('1.0040'), findsOneWidget);
    expect(find.text('1.0000'), findsNothing);
    expect(find.text('72.0 °F'), findsOneWidget);
    expect(find.textContaining('Connected'), findsNothing);
  });

  testWidgets('Light uses light surface on a tile', (tester) async {
    final t0 = DateTime.utc(2026, 10, 25, 0, 50);
    final scanner = FakeTiltScanner(
      script: [
        TiltAdvertisementEvent(advertisement: _pink, receivedAt: t0),
      ],
    );
    await _pumpHome(
      tester,
      scanner: scanner,
      now: () => t0,
      theme: tiltLightTheme(),
      themeMode: ThemeMode.light,
    );

    expect(find.byType(TiltTile), findsOneWidget);
    final plates = tester
        .widgetList<ChamferPlate>(
          find.descendant(
            of: find.byType(TiltTile),
            matching: find.byType(ChamferPlate),
          ),
        )
        .toList();
    expect(plates, isNotEmpty);
    expect(plates.first.fill, TiltPalette.light.livePlate);
    expect(plates.first.fill, isNot(TiltColors.surface));
    expect(find.textContaining('Connected'), findsNothing);
  });

  testWidgets('startup logging uuid is Stale with em dash until heard', (tester) async {
    final prefs = _MemoryPrefs();
    await prefs.save(
      FakeTiltScanner.pinkUuid,
      const TiltPrefs(logging: true, name: 'House Pale'),
    );
    await _pumpHome(
      tester,
      scanner: FakeTiltScanner(script: const []),
      prefs: prefs,
      seed: const [],
    );
    await tester.pump();
    expect(find.text('House Pale'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(find.text('Stale'), findsOneWidget);
    expect(find.text('1.0000'), findsNothing);
    final text = _allText(tester);
    expect(text.contains('d ago'), isFalse);
    expect(text.contains('1969'), isFalse);
    expect(text.contains('1970'), isFalse);
  });

  testWidgets('remembered tile uses last CSV time, not 20000 d; SG stays dash',
      (tester) async {
    final now = DateTime.utc(2026, 10, 25, 19);
    final heard = now.subtract(const Duration(hours: 3));
    final prefs = _MemoryPrefs();
    await prefs.save(
      FakeTiltScanner.pinkUuid,
      const TiltPrefs(logging: true, name: 'House Pale'),
    );
    final logs = _MemoryLogs()..heard = heard;
    await _pumpHome(
      tester,
      scanner: FakeTiltScanner(script: const []),
      prefs: prefs,
      logs: logs,
      now: () => now,
    );
    await tester.pump();

    expect(find.text('3 h ago'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(find.text('Stale'), findsOneWidget);
    expect(find.text('1.040'), findsNothing);
    expect(find.text('0.0000'), findsNothing);
    expect(find.text('1.0000'), findsNothing);
    final text = _allText(tester);
    expect(text.contains('20000'), isFalse);
    expect(text.contains('1969'), isFalse);
    expect(text.contains('1970'), isFalse);
  });
}
