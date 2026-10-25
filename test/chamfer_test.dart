import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/ui/chamfer.dart';

void main() {
  test('clipper cuts top-right and bottom-left, keeps TL and BR', () {
    final path = ChamferClipper(chamfer: 10).getClip(const Size(100, 80));
    expect(path.contains(const Offset(1, 1)), isTrue); // top-left
    expect(path.contains(const Offset(99, 1)), isFalse); // top-right cut
    expect(path.contains(const Offset(99, 79)), isTrue); // bottom-right
    expect(path.contains(const Offset(1, 79)), isFalse); // bottom-left cut
  });

  test('chamfer does not use a radius', () {
    expect(ChamferClipper.radius, Radius.zero);
  });
}
