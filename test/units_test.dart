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
}
