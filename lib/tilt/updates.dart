import 'dart:convert';
import 'dart:io';

const githubLatestUrl =
    'https://api.github.com/repos/NotGovernor/TiltaWort/releases/latest';

const githubHeaders = {
  'User-Agent': 'Tilt-a-Wort',
  'Accept': 'application/vnd.github+json',
};

typedef ReleaseFetch = Future<String> Function(
  Uri uri,
  Map<String, String> headers,
);

enum UpdateOs { windows, android, other }

class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url});
  final String name;
  final String url;
}

class LatestRelease {
  const LatestRelease({
    required this.tag,
    required this.notes,
    required this.assets,
  });
  final String tag;
  final String notes;
  final List<ReleaseAsset> assets;
}

class UpdateOffer {
  const UpdateOffer({
    required this.tag,
    required this.notes,
    required this.asset,
  });
  final String tag;
  final String notes;
  final ReleaseAsset asset;
}

UpdateOs updateOsFrom({bool? windows, bool? android}) {
  if (windows ?? Platform.isWindows) return UpdateOs.windows;
  if (android ?? Platform.isAndroid) return UpdateOs.android;
  return UpdateOs.other;
}

String normalizeVersion(String raw) {
  var s = raw.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  final plus = s.indexOf('+');
  if (plus >= 0) s = s.substring(0, plus);
  return s;
}

bool isNewer(String tag, String current) {
  final a = _parts(normalizeVersion(tag));
  final b = _parts(normalizeVersion(current));
  final n = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final ai = i < a.length ? a[i] : 0;
    final bi = i < b.length ? b[i] : 0;
    if (ai > bi) return true;
    if (ai < bi) return false;
  }
  return false;
}

List<int> _parts(String v) => [
      for (final p in v.split('.')) int.tryParse(p) ?? 0,
    ];

String expectedAssetName(UpdateOs os) {
  switch (os) {
    case UpdateOs.windows:
      return 'Tilt-a-Wort-windows-x64.zip';
    case UpdateOs.android:
      return 'tiltawort-android.apk';
    case UpdateOs.other:
      throw UpdateException(
        'Updates are not available on this platform yet.',
      );
  }
}

ReleaseAsset pickAsset(List<ReleaseAsset> assets, {required UpdateOs os}) {
  final want = expectedAssetName(os);
  for (final a in assets) {
    if (a.name == want) return a;
  }
  throw UpdateException('Release is missing $want');
}

LatestRelease parseLatestRelease(String body) {
  final json = jsonDecode(body);
  if (json is! Map<String, dynamic>) {
    throw UpdateException('Unexpected GitHub response');
  }
  final tag = json['tag_name'] as String? ?? '';
  if (tag.isEmpty) throw UpdateException('Release has no tag');
  final notes = (json['body'] as String?)?.trim() ?? '';
  final raw = json['assets'];
  final assets = <ReleaseAsset>[];
  if (raw is List) {
    for (final item in raw) {
      if (item is Map) {
        final name = item['name'] as String? ?? '';
        final url = item['browser_download_url'] as String? ?? '';
        if (name.isNotEmpty && url.isNotEmpty) {
          assets.add(ReleaseAsset(name: name, url: url));
        }
      }
    }
  }
  return LatestRelease(tag: tag, notes: notes, assets: assets);
}

Future<String> githubFetch(Uri uri, Map<String, String> headers) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    headers.forEach(req.headers.set);
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw UpdateException('GitHub returned ${res.statusCode}');
    }
    return text;
  } on UpdateException {
    rethrow;
  } catch (e) {
    throw UpdateException('Could not reach GitHub');
  } finally {
    client.close();
  }
}

Future<UpdateOffer?> checkForUpdate({
  required String currentVersion,
  required UpdateOs os,
  required bool releaseBuild,
  required bool fromLaunch,
  required ReleaseFetch fetch,
}) async {
  if (fromLaunch && !releaseBuild) return null;
  if (os == UpdateOs.other) {
    if (fromLaunch) return null;
    throw UpdateException(
      'Updates are not available on this platform yet.',
    );
  }
  try {
    final body = await fetch(Uri.parse(githubLatestUrl), githubHeaders);
    final rel = parseLatestRelease(body);
    if (!isNewer(rel.tag, currentVersion)) return null;
    final asset = pickAsset(rel.assets, os: os);
    return UpdateOffer(tag: rel.tag, notes: rel.notes, asset: asset);
  } catch (e) {
    if (fromLaunch) return null;
    if (e is UpdateException) rethrow;
    throw UpdateException('Could not check for updates');
  }
}

String windowsUpdateCmd({
  required int pid,
  required String zipPath,
  required String destDir,
  required String exeName,
}) {
  if (destDir.trim().isEmpty) {
    throw ArgumentError('empty dest');
  }
  if (exeName.trim().isEmpty) {
    throw ArgumentError('empty exe');
  }
  if (zipPath.trim().isEmpty) {
    throw ArgumentError('empty zip');
  }
  final exe = '$destDir\\$exeName';
  return '''
@echo off
setlocal
set PID=$pid
set ZIP=$zipPath
set DEST=$destDir
set EXE=$exe
if "%DEST%"=="" exit /b 1
if "%EXE%"=="" exit /b 1
:wait
tasklist /FI "PID eq %PID%" | findstr /I /C:"%PID%" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto wait
)
set STAGE=%TEMP%\\tiltawort-update-unpack
rmdir /s /q "%STAGE%" 2>nul
mkdir "%STAGE%"
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%STAGE%' -Force"
xcopy /E /Y /I "%STAGE%\\Tilt-a-Wort-windows-x64\\*" "%DEST%\\"
start "" "%EXE%"
del "%~f0"
''';
}

Future<void> downloadToFile(Uri url, File dest) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    githubHeaders.forEach(req.headers.set);
    final res = await req.close();
    if (res.statusCode != 200) {
      throw UpdateException('Download failed (${res.statusCode})');
    }
    final sink = dest.openWrite();
    await res.pipe(sink);
  } finally {
    client.close();
  }
}
