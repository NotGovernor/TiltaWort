import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/ui/settings_page.dart';
import 'package:tiltawort/ui/theme.dart';

void main() {
  testWidgets('dark default, light option, version, never Connected',
      (tester) async {
    var mode = ThemeMode.dark;
    await tester.pumpWidget(
      MaterialApp(
        theme: tiltDarkTheme(),
        home: SettingsPage(
          themeMode: mode,
          onThemeMode: (m) => mode = m,
          version: '1.0.0',
          radio: RadioState.on,
        ),
      ),
    );
    expect(find.text('App Settings'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.textContaining('1.0.0'), findsOneWidget);
    expect(find.textContaining('Connected'), findsNothing);
    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(mode, ThemeMode.light);
  });

  testWidgets('radio off pointer uses Home copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: tiltDarkTheme(),
        home: SettingsPage(
          themeMode: ThemeMode.dark,
          onThemeMode: (_) {},
          version: '1.0.0',
          radio: RadioState.off,
        ),
      ),
    );
    expect(find.text('Bluetooth is off. This app only listens.'), findsOneWidget);
  });
}
