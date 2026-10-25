import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/ui/home_page.dart';
import 'package:tiltawort/ui/theme.dart';

class TiltawortApp extends StatefulWidget {
  const TiltawortApp({
    super.key,
    required this.scanner,
    this.seed,
    this.names = const {},
    this.prefs,
    this.history,
    this.logs,
    this.initialTheme = ThemeMode.dark,
    this.version = '1.0.0',
  });

  final TiltScanner scanner;
  final List<TiltView>? seed;
  final Map<String, String> names;
  final PrefsStore? prefs;
  final SessionHistory? history;
  final CsvLogStore? logs;
  final ThemeMode initialTheme;
  final String version;

  @override
  State<TiltawortApp> createState() => _TiltawortAppState();
}

class _TiltawortAppState extends State<TiltawortApp> {
  late ThemeMode _mode;
  late final SessionHistory _history;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialTheme;
    _history = widget.history ?? SessionHistory();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tilt-a-Wort',
      debugShowCheckedModeBanner: false,
      theme: tiltLightTheme(),
      darkTheme: tiltDarkTheme(),
      themeMode: _mode,
      home: HomePage(
        scanner: widget.scanner,
        seed: widget.seed ?? fakeDemoSeed(),
        names: widget.names,
        prefs: widget.prefs,
        history: _history,
        logs: widget.logs,
        themeMode: _mode,
        onThemeMode: (m) => setState(() => _mode = m),
        version: widget.version,
      ),
    );
  }
}

/// Extra Stale tile so fake Home shows Live and Stale together.
List<TiltView> fakeDemoSeed() {
  if (!kUseFakeScanner) return const [];
  final now = DateTime.now();
  return [
    TiltView(
      uuid: 'A495BB30-C5B1-4B44-B512-1370F02D74DE',
      color: 'Black',
      name: 'Dry Stout',
      rawSg: 1.021,
      rawTempF: 64,
      calSg: 1.021,
      calTempF: 64,
      isPro: false,
      lastPacket: now.subtract(const Duration(minutes: 12)),
    ),
  ];
}
