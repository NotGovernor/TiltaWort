import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/ui/device_page.dart';
import 'package:tiltawort/ui/home_page.dart';
import 'package:tiltawort/ui/theme.dart';

const _outDir = r'M:\AIHome\Foundry Team\jobs\t_35e41075';

const _pink = TiltAdvertisement(
  color: 'Pink',
  uuid: FakeTiltScanner.pinkUuid,
  tempF: 72.0,
  sg: 1.0000,
  isPro: true,
);

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
}

Future<void> _fonts() async {
  Future<void> load(String family, String asset) async {
    final data = await rootBundle.load(asset);
    await (FontLoader(family)..addFont(Future.value(data))).load();
  }

  await load('Sora', 'fonts/Sora-VariableFont_wght.ttf');
  await load('Oxanium', 'fonts/Oxanium-VariableFont_wght.ttf');
}

Future<void> _shot(GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.25);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  Directory(_outDir).createSync(recursive: true);
  File('$_outDir${Platform.pathSeparator}$name')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_fonts);

  final t0 = DateTime.utc(2026, 10, 25, 12, 0, 0);
  final seed = [
    TiltView.fromEvent(
      TiltAdvertisementEvent(
        advertisement: _pink,
        receivedAt: t0.subtract(const Duration(seconds: 4)),
        rssiDbm: -96,
      ),
      name: 'House Pale',
    ),
    TiltView(
      uuid: 'A495BB30-C5B1-4B44-B512-1370F02D74DE',
      color: 'Black',
      name: 'Dry Stout',
      rawSg: 1.021,
      rawTempF: 64,
      calSg: 1.021,
      calTempF: 64,
      isPro: false,
      lastPacket: t0.subtract(const Duration(minutes: 12)),
    ),
  ];

  Future<void> home(WidgetTester tester, ThemeMode mode, String file) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tiltLightTheme(),
          darkTheme: tiltDarkTheme(),
          themeMode: mode,
          home: HomePage(
            scanner: FakeTiltScanner(script: const []),
            seed: seed,
            now: () => t0,
            names: const {FakeTiltScanner.pinkUuid: 'House Pale'},
            prefs: _MemoryPrefs(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      for (final el in find.byType(Image).evaluate()) {
        final img = el.widget as Image;
        await precacheImage(img.image, el);
      }
    });
    await tester.pump();
    await tester.runAsync(() => _shot(key, file));
  }

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tilt-shot-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> device(WidgetTester tester, ThemeMode mode, String file) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final history = SessionHistory()
      ..add(
        FakeTiltScanner.pinkUuid,
        SessionSample(at: t0.subtract(const Duration(minutes: 20)), sg: 1.014, tempF: 68),
      )
      ..add(
        FakeTiltScanner.pinkUuid,
        SessionSample(at: t0.subtract(const Duration(minutes: 5)), sg: 1.012, tempF: 67.8),
      );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tiltLightTheme(),
          darkTheme: tiltDarkTheme(),
          themeMode: mode,
          home: DevicePage(
            scanner: FakeTiltScanner(script: const []),
            initial: seed.first,
            prefs: PrefsStore(File('${tmp.path}/prefs.json')),
            history: history,
            logs: CsvLogStore(Directory('${tmp.path}/logs')),
            now: () => t0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() => _shot(key, file));
  }

  testWidgets('capture home dark', (tester) async {
    await home(tester, ThemeMode.dark, 'home-dark.png');
    expect(find.text('Tilt-a-Wort'), findsNothing);
    expect(
      find.image(const AssetImage('assets/brand/wordmark-dark.png')),
      findsNothing,
    );
    expect(find.text('House Pale'), findsOneWidget);
  });

  testWidgets('capture home light', (tester) async {
    await home(tester, ThemeMode.light, 'home-light.png');
    expect(find.text('Tilt-a-Wort'), findsNothing);
    expect(
      find.image(const AssetImage('assets/brand/wordmark-light.png')),
      findsNothing,
    );
  });

  testWidgets('capture device dark', (tester) async {
    await device(tester, ThemeMode.dark, 'device-dark.png');
    expect(find.text('House Pale'), findsWidgets);
    expect(find.text('No samples yet'), findsNothing);
  });

  testWidgets('capture device light', (tester) async {
    await device(tester, ThemeMode.light, 'device-light.png');
    expect(find.text('House Pale'), findsWidgets);
  });
}
