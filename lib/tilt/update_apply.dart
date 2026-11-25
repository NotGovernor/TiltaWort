import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tiltawort/tilt/updates.dart';

const updatesChannel = MethodChannel('tiltawort/updates');

Future<void> applyUpdate(UpdateOffer offer) async {
  if (Platform.isWindows) {
    await applyWindowsUpdate(offer);
  } else if (Platform.isAndroid) {
    await applyAndroidUpdate(offer);
  } else {
    throw UpdateException(
      'Updates are not available on this platform yet.',
    );
  }
}

Future<void> applyWindowsUpdate(UpdateOffer offer) async {
  final destDir = File(Platform.resolvedExecutable).parent.path;
  const exeName = 'tiltawort.exe';
  if (destDir.trim().isEmpty) {
    throw ArgumentError('empty dest');
  }
  final zip = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}tiltawort-update.zip',
  );
  await downloadToFile(Uri.parse(offer.asset.url), zip);
  if (zip.path.trim().isEmpty) {
    throw ArgumentError('empty zip');
  }
  final helper = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}tiltawort-update.cmd',
  );
  final cmd = windowsUpdateCmd(
    pid: pid,
    zipPath: zip.path,
    destDir: destDir,
    exeName: exeName,
  );
  await helper.writeAsString(cmd);
  if (helper.path.trim().isEmpty) {
    throw ArgumentError('empty helper');
  }
  await Process.start(helper.path, const <String>[], runInShell: true);
  exit(0);
}

Future<void> applyAndroidUpdate(UpdateOffer offer) async {
  final dir = await getTemporaryDirectory();
  final apk = File('${dir.path}${Platform.pathSeparator}tiltawort-update.apk');
  await downloadToFile(Uri.parse(offer.asset.url), apk);
  if (apk.path.trim().isEmpty) {
    throw ArgumentError('empty apk');
  }
  await updatesChannel.invokeMethod<void>('installApk', {'path': apk.path});
}
