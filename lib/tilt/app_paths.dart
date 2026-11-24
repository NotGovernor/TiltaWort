import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Resolves the on-disk root for prefs.json + logs/.
///
/// Windows keeps `%APPDATA%\Tilt-a-Wort` so existing installs keep their files.
/// Every other OS uses the app-support directory (writable on Android/iOS).
Directory tiltAppRoot({
  required String? appData,
  required String documentsPath,
  required bool isWindows,
  required String separator,
}) {
  if (isWindows && appData != null && appData.isNotEmpty) {
    return Directory('$appData${separator}Tilt-a-Wort');
  }
  return Directory('$documentsPath${separator}Tilt-a-Wort');
}

Future<Directory> resolveAppRoot() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    return tiltAppRoot(
      appData: Platform.environment['APPDATA'],
      documentsPath: '',
      isWindows: true,
      separator: Platform.pathSeparator,
    );
  }
  final support = await getApplicationSupportDirectory();
  return tiltAppRoot(
    appData: null,
    documentsPath: support.path,
    isWindows: false,
    separator: Platform.pathSeparator,
  );
}
