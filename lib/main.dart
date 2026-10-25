import 'package:flutter/material.dart';
import 'package:tiltawort/app.dart';
import 'package:tiltawort/tilt/create_scanner.dart';
import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/scanner.dart';

void main() {
  runApp(
    TiltawortApp(
      scanner: createScanner(),
      names: kUseFakeScanner
          ? const {FakeTiltScanner.pinkUuid: 'House Pale'}
          : const {},
    ),
  );
}
