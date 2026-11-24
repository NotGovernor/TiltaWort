import 'dart:io';

/// SIGTERM/`Process.kill()` leaves WinRT listeners alive on this PC.
/// SIGKILL + `taskkill /F /PID /T` actually reaps.
Future<void> forceKillPid(int pid) async {
  if (pid <= 0) return;
  Process.killPid(pid, ProcessSignal.sigkill);
  if (Platform.isWindows) {
    await Process.run(
      'taskkill',
      ['/F', '/PID', '$pid', '/T'],
      runInShell: false,
    );
  }
  for (var i = 0; i < 20; i++) {
    if (!await pidIsRunning(pid)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<bool> pidIsRunning(int pid) async {
  if (pid <= 0) return false;
  if (!Platform.isWindows) {
    return Process.killPid(pid, ProcessSignal.sigusr1);
  }
  final result = await Process.run(
    'tasklist',
    ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH'],
    runInShell: false,
  );
  final out = result.stdout.toString();
  if (out.contains('No tasks are running')) return false;
  return RegExp(',"$pid"|,"$pid",').hasMatch(out) ||
      RegExp('"$pid"').hasMatch(out);
}

/// Kill leftover `tilt_listen.exe` so they cannot contend the Intel adapter.
Future<void> killLeftoverTiltListenExe() async {
  if (!Platform.isWindows) return;
  await Process.run(
    'taskkill',
    ['/F', '/IM', 'tilt_listen.exe'],
    runInShell: false,
  );
}

/// Opens Windows Bluetooth settings. Does not toggle radio itself.
Future<void> openBluetoothSettings() async {
  if (!Platform.isWindows) return;
  await Process.start('explorer.exe', ['ms-settings:bluetooth'], runInShell: false);
}
