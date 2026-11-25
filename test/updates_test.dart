import 'package:flutter_test/flutter_test.dart';
import 'package:tiltawort/tilt/updates.dart';

void main() {
  group('isNewer', () {
    test('v0.1.0 vs 0.1.0 is not newer', () {
      expect(isNewer('v0.1.0', '0.1.0'), isFalse);
    });

    test('v0.2.0 vs 0.1.0 is newer', () {
      expect(isNewer('v0.2.0', '0.1.0'), isTrue);
    });

    test('ignores a +build suffix', () {
      expect(isNewer('v0.1.0', '0.1.0+1'), isFalse);
      expect(isNewer('0.1.0+5', '0.1.0'), isFalse);
      expect(isNewer('v0.2.0+9', '0.1.0+1'), isTrue);
    });
  });

  group('pickAsset', () {
    const windows = ReleaseAsset(
      name: 'Tilt-a-Wort-windows-x64.zip',
      url: 'https://example.com/win.zip',
    );
    const android = ReleaseAsset(
      name: 'tiltawort-android.apk',
      url: 'https://example.com/app.apk',
    );

    test('picks the Windows zip on Windows', () {
      expect(
        pickAsset(const [windows, android], os: UpdateOs.windows).name,
        'Tilt-a-Wort-windows-x64.zip',
      );
    });

    test('picks the Android apk on Android', () {
      expect(
        pickAsset(const [windows, android], os: UpdateOs.android).name,
        'tiltawort-android.apk',
      );
    });

    test('missing asset is an error, not a silent success', () {
      expect(
        () => pickAsset(const [windows], os: UpdateOs.android),
        throwsA(isA<UpdateException>()),
      );
      expect(
        () => pickAsset(const [android], os: UpdateOs.windows),
        throwsA(isA<UpdateException>()),
      );
    });
  });

  group('parseLatestRelease', () {
    test('reads tag, notes, and assets from GitHub JSON', () {
      const json = '''
{
  "tag_name": "v0.2.0",
  "body": "fixes",
  "assets": [
    {"name": "Tilt-a-Wort-windows-x64.zip", "browser_download_url": "https://example.com/win.zip"},
    {"name": "tiltawort-android.apk", "browser_download_url": "https://example.com/app.apk"}
  ]
}
''';
      final rel = parseLatestRelease(json);
      expect(rel.tag, 'v0.2.0');
      expect(rel.notes, 'fixes');
      expect(rel.assets.map((a) => a.name).toList(), [
        'Tilt-a-Wort-windows-x64.zip',
        'tiltawort-android.apk',
      ]);
    });
  });

  group('checkForUpdate', () {
    Future<String> okFetch(Uri uri, Map<String, String> headers) async {
      expect(uri.toString(), githubLatestUrl);
      expect(headers['User-Agent'], 'Tilt-a-Wort');
      expect(headers['Accept'], 'application/vnd.github+json');
      return '''
{"tag_name":"v0.2.0","body":"notes","assets":[
  {"name":"Tilt-a-Wort-windows-x64.zip","browser_download_url":"https://example.com/win.zip"},
  {"name":"tiltawort-android.apk","browser_download_url":"https://example.com/app.apk"}
]}
''';
    }

    test('launch check: debug skip', () async {
      final result = await checkForUpdate(
        currentVersion: '0.1.0',
        os: UpdateOs.windows,
        releaseBuild: false,
        fromLaunch: true,
        fetch: okFetch,
      );
      expect(result, isNull);
    });

    test('launch check: release error returns null (no dialog)', () async {
      final result = await checkForUpdate(
        currentVersion: '0.1.0',
        os: UpdateOs.windows,
        releaseBuild: true,
        fromLaunch: true,
        fetch: (uri, headers) async => throw Exception('network'),
      );
      expect(result, isNull);
    });

    test('launch check: same version is null', () async {
      final result = await checkForUpdate(
        currentVersion: '0.1.0',
        os: UpdateOs.windows,
        releaseBuild: true,
        fromLaunch: true,
        fetch: (uri, headers) async =>
            '{"tag_name":"v0.1.0","body":"","assets":[{"name":"Tilt-a-Wort-windows-x64.zip","browser_download_url":"https://example.com/win.zip"}]}',
      );
      expect(result, isNull);
    });

    test('launch check: newer returns offer after headers', () async {
      final result = await checkForUpdate(
        currentVersion: '0.1.0',
        os: UpdateOs.windows,
        releaseBuild: true,
        fromLaunch: true,
        fetch: okFetch,
      );
      expect(result, isNotNull);
      expect(result!.tag, 'v0.2.0');
      expect(result.asset.name, 'Tilt-a-Wort-windows-x64.zip');
    });

    test('settings check: error is not swallowed', () async {
      await expectLater(
        checkForUpdate(
          currentVersion: '0.1.0',
          os: UpdateOs.android,
          releaseBuild: true,
          fromLaunch: false,
          fetch: (uri, headers) async => throw Exception('network'),
        ),
        throwsA(isA<UpdateException>()),
      );
    });
  });

  group('windows helper', () {
    test('refuses an empty dest or exe so start is never empty', () {
      expect(
        () => windowsUpdateCmd(
          pid: 1,
          zipPath: r'C:\t\a.zip',
          destDir: '',
          exeName: 'tiltawort.exe',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => windowsUpdateCmd(
          pid: 1,
          zipPath: r'C:\t\a.zip',
          destDir: r'C:\app',
          exeName: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('starts the exe with a full path, copies inner folder contents', () {
      final cmd = windowsUpdateCmd(
        pid: 42,
        zipPath: r'C:\t\Tilt-a-Wort-windows-x64.zip',
        destDir: r'C:\app\Tilt-a-Wort',
        exeName: 'tiltawort.exe',
      );
      expect(cmd, contains(r'set EXE=C:\app\Tilt-a-Wort\tiltawort.exe'));
      expect(cmd, contains('start "" "%EXE%"'));
      expect(cmd, isNot(contains(r'start "" "\"')));
      expect(cmd, contains(r'Tilt-a-Wort-windows-x64'));
      expect(cmd, contains('42'));
    });
  });
}
