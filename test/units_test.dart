import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/units.dart';

void main() {
  test('plato is 259 - (259 / sg)', () {
    expect(sgToPlato(1.040), closeTo(259 - (259 / 1.040), 1e-9));
    expect(sgToPlato(1.000), closeTo(0.0, 1e-9));
  });

  test('F to C', () {
    expect(fToC(32), closeTo(0.0, 1e-9));
    expect(fToC(72), closeTo(22.222222, 1e-5));
  });

  test('format SG three vs four decimals', () {
    expect(formatSg(1.016, isPro: false), '1.016');
    expect(formatSg(1.0000, isPro: true), '1.0000');
  });

  test('epoch last-heard is blank, never 20000 d ago', () {
    final now = DateTime.utc(2026, 10, 25, 19);
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    expect(isEpoch(epoch), isTrue);
    expect(isNonsenseHeard(epoch), isTrue);
    expect(lastHeardLabel(epoch, now), '');
    expect(relativeAgo(epoch, now), isNot(''));
    expect(lastHeardLabel(epoch, now).contains('d ago'), isFalse);
  });

  test('local DateTime(1970, 1, 1) last-heard is blank, not 20752 d ago', () {
    final now = DateTime.utc(2026, 10, 25, 19);
    final localEpoch = DateTime(1970, 1, 1);
    expect(isNonsenseHeard(localEpoch), isTrue);
    expect(lastHeardLabel(localEpoch, now), '');
    expect(lastHeardLabel(localEpoch, now).contains('d ago'), isFalse);
  });

  test('12 min ago last-heard is 12 min ago', () {
    final now = DateTime.utc(2026, 10, 25, 19);
    final at = now.subtract(const Duration(minutes: 12));
    expect(isEpoch(at), isFalse);
    expect(isNonsenseHeard(at), isFalse);
    expect(lastHeardLabel(at, now), '12 min ago');
  });
}
