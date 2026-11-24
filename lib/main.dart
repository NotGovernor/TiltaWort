import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tiltawort/app.dart';
import 'package:tiltawort/tilt/app_paths.dart';
import 'package:tiltawort/tilt/create_scanner.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/fake_scanner.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';

Future<void> main() async {
  final root = await resolveAppRoot();
  runApp(
    TiltawortApp(
      scanner: createScanner(),
      names: kUseFakeScanner
          ? const {FakeTiltScanner.pinkUuid: 'House Pale'}
          : const {},
      prefs: PrefsStore(File('${root.path}${Platform.pathSeparator}prefs.json')),
      logs: CsvLogStore(Directory('${root.path}${Platform.pathSeparator}logs')),
      history: SessionHistory(),
    ),
  );
}
