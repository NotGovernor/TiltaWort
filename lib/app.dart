import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/ui/home_page.dart';
import 'package:tiltawort/ui/theme.dart';

class TiltawortApp extends StatelessWidget {
  const TiltawortApp({
    super.key,
    required this.scanner,
    this.seed,
    this.names = const {},
  });

  final TiltScanner scanner;
  final List<TiltView>? seed;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tilt-a-Wort',
      debugShowCheckedModeBanner: false,
      theme: tiltDarkTheme(),
      home: HomePage(
        scanner: scanner,
        seed: seed ?? fakeDemoSeed(),
        names: names,
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
