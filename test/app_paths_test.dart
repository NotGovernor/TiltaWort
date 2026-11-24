import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/app_paths.dart';

void main() {
  test('Windows APPDATA wins over documents', () {
    final dir = tiltAppRoot(
      appData: r'C:\\Users\\x\\AppData\\Roaming',
      documentsPath: r'C:\\Users\\x\\Documents',
      isWindows: true,
      separator: r'\\',
    );
    expect(dir.path, r'C:\\Users\\x\\AppData\\Roaming\\Tilt-a-Wort');
  });

  test('Windows empty APPDATA falls through to documents', () {
    final dir = tiltAppRoot(
      appData: '',
      documentsPath: r'C:\\Users\\x\\AppData\\Roaming\\com.example\\tiltawort',
      isWindows: true,
      separator: r'\\',
    );
    expect(
      dir.path,
      r'C:\\Users\\x\\AppData\\Roaming\\com.example\\tiltawort\\Tilt-a-Wort',
    );
  });

  test('Android / iOS / Linux / macOS use documents, ignore APPDATA', () {
    final dir = tiltAppRoot(
      appData: r'C:\\should-not-use',
      documentsPath: '/data/user/0/com.notgovernor.tiltawort/app_flutter',
      isWindows: false,
      separator: '/',
    );
    expect(
      dir.path,
      '/data/user/0/com.notgovernor.tiltawort/app_flutter/Tilt-a-Wort',
    );
  });
}
