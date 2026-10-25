import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/models.dart';
import 'package:tiltawort/tilt/scanner.dart';

void main() {
  const pink = TiltAdvertisement(
    color: 'Pink',
    uuid: 'A495BB80-C5B1-4B44-B512-1370F02D74DE',
    tempF: 72.0,
    sg: 1.0000,
    isPro: true,
  );

  test('after start, one Pink event is Live', () async {
    final t0 = DateTime.utc(2026, 10, 24, 21, 0, 0);
    final scanner = FakeTiltScanner(
      script: [
        TiltAdvertisementEvent(advertisement: pink, receivedAt: t0, rssiDbm: -97),
      ],
    );
    final ads = <TiltAdvertisementEvent>[];
    final sub = scanner.advertisements.listen(ads.add);
    await scanner.start();
    await Future<void>.delayed(Duration.zero);
    expect(ads, hasLength(1));
    expect(ads.first.advertisement.color, 'Pink');
    expect(ads.first.advertisement.isPro, isTrue);
    expect(ads.first.advertisement.sg, closeTo(1.0000, 1e-9));
    final view = TiltView.fromEvent(ads.first);
    expect(view.isLiveAt(t0), isTrue);
    expect(view.isLiveAt(t0.add(const Duration(seconds: 30))), isTrue);
    await sub.cancel();
    await scanner.stop();
  });

  test('after 31s with no events, Stale but last SG remains', () {
    final t0 = DateTime.utc(2026, 10, 24, 21, 0, 0);
    final view = TiltView.fromEvent(
      TiltAdvertisementEvent(advertisement: pink, receivedAt: t0, rssiDbm: -97),
    );
    final later = t0.add(const Duration(seconds: 31));
    expect(view.isLiveAt(later), isFalse);
    expect(view.rawSg, closeTo(1.0000, 1e-9));
    expect(view.calSg, closeTo(1.0000, 1e-9));
  });

  test('kUseFakeScanner defaults false (tests inject FakeTiltScanner)', () {
    expect(kUseFakeScanner, isFalse);
  });
}
