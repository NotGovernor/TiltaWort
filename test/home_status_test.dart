import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/ui/home_status.dart';

void main() {
  test('radio off is the listen-only banner, never Connected', () {
    final s = HomeStatus.of(
      radio: RadioState.off,
      liveCount: 2,
      tileCount: 2,
    );
    expect(s.kind, HomeStatusKind.radioOff);
    expect(s.line, 'Bluetooth is off. This app only listens.');
    expect(s.line.toLowerCase().contains('connected'), isFalse);
  });

  test('radio on, nothing remembered, nothing heard is empty copy', () {
    final s = HomeStatus.of(
      radio: RadioState.on,
      liveCount: 0,
      tileCount: 0,
    );
    expect(s.kind, HomeStatusKind.empty);
    expect(
      s.line,
      'No Tilts heard. They broadcast about every 5 seconds. This app only listens.',
    );
  });

  test('radio on, remembered but none live', () {
    final s = HomeStatus.of(
      radio: RadioState.on,
      liveCount: 0,
      tileCount: 1,
    );
    expect(s.kind, HomeStatusKind.noneLive);
    expect(s.line, 'Scanning · none live');
  });

  test('radio on, live tiles counted as heard N', () {
    final s = HomeStatus.of(
      radio: RadioState.on,
      liveCount: 2,
      tileCount: 3,
    );
    expect(s.kind, HomeStatusKind.heard);
    expect(s.line, 'Scanning · heard 2');
  });
}
