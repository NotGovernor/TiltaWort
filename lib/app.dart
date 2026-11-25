import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/update_apply.dart';
import 'package:tiltawort/tilt/updates.dart';
import 'package:tiltawort/ui/home_page.dart';
import 'package:tiltawort/ui/theme.dart';
import 'package:tiltawort/ui/update_dialog.dart';

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
    this.updateOs,
    this.updateFetch,
    this.onApplyUpdate,
  });

  final TiltScanner scanner;
  final List<TiltView>? seed;
  final Map<String, String> names;
  final PrefsStore? prefs;
  final SessionHistory? history;
  final CsvLogStore? logs;
  final ThemeMode initialTheme;
  final String version;
  final UpdateOs? updateOs;
  final ReleaseFetch? updateFetch;
  final Future<void> Function(UpdateOffer)? onApplyUpdate;

  @override
  State<TiltawortApp> createState() => _TiltawortAppState();
}

class _TiltawortAppState extends State<TiltawortApp> {
  late ThemeMode _mode;
  late final SessionHistory _history;
  final _nav = GlobalKey<NavigatorState>();
  var _dismissedUpdate = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialTheme;
    _history = widget.history ?? SessionHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_launchCheck());
    });
  }

  Future<void> _launchCheck() async {
    if (_dismissedUpdate) return;
    final offer = await checkForUpdate(
      currentVersion: widget.version,
      os: widget.updateOs ?? updateOsFrom(),
      releaseBuild: kReleaseMode,
      fromLaunch: true,
      fetch: widget.updateFetch ?? githubFetch,
    );
    if (offer == null || !mounted) return;
    final ctx = _nav.currentContext;
    if (ctx == null) return;
    final go = await showUpdateDialog(
      ctx,
      offer: offer,
      os: widget.updateOs ?? updateOsFrom(),
    );
    if (!go) {
      _dismissedUpdate = true;
      return;
    }
    await (widget.onApplyUpdate ?? applyUpdate)(offer);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _nav,
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
        updateOs: widget.updateOs,
        updateFetch: widget.updateFetch,
        onApplyUpdate: widget.onApplyUpdate,
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
