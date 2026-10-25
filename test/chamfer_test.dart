import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/ui/chamfer.dart';

void main() {
  test('clipper cuts all four corners, keeps interior', () {
    final path = ChamferClipper(chamfer: 10).getClip(const Size(100, 80));
    expect(path.contains(const Offset(50, 40)), isTrue);
    expect(path.contains(const Offset(1, 1)), isFalse); // top-left cut
    expect(path.contains(const Offset(99, 1)), isFalse); // top-right cut
    expect(path.contains(const Offset(99, 79)), isFalse); // bottom-right cut
    expect(path.contains(const Offset(1, 79)), isFalse); // bottom-left cut
  });

  test('chamfer does not use a radius', () {
    expect(ChamferClipper.radius, Radius.zero);
  });
}
