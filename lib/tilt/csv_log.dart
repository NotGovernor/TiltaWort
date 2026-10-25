import 'dart:io';

class CsvLogStore {
  CsvLogStore(this.directory, {this.reveal});

  static const header = 'Timestamp,Timepoint,SG,Temp,Color,Beer,Comment';

  final Directory directory;
  final Future<void> Function(String path)? reveal;

  File? active;
  DateTime? logStart;
  String? activeColor;

  bool get isOpen => active != null;

  Future<File> startLog({
    required String color,
    required String beer,
    DateTime? at,
  }) async {
    await directory.create(recursive: true);
    final when = at ?? DateTime.now();
    logStart = when;
    activeColor = color;
    final stamp = _stamp(when);
    final safe = _safe(beer.trim().isEmpty ? 'Untitled' : beer);
    final name = '$safe ($color TILT) $stamp.csv';
    active = File('${directory.path}${Platform.pathSeparator}$name');
    await active!.writeAsString('$header\n');
    return active!;
  }

  Future<void> endLog() async {
    active = null;
    logStart = null;
    activeColor = null;
  }

  Future<void> append({
    required DateTime timestamp,
    required double sg,
    required double temp,
    required String color,
    required String beer,
    String comment = '',
  }) async {
    if (active == null || logStart == null) return;
    final timepoint =
        timestamp.difference(logStart!).inMicroseconds / Duration.microsecondsPerDay;
    final row = [
      timestamp.toIso8601String(),
      timepoint.toStringAsFixed(6),
      sg.toString(),
      temp.toString(),
      _csv(color),
      _csv(beer),
      _csv(comment),
    ].join(',');
    await active!.writeAsString('$row\n', mode: FileMode.append);
  }

  Future<List<File>> listForColor(String color) async {
    if (!await directory.exists()) return const [];
    final needle = '($color TILT)';
    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.contains(needle))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> deleteFile(File file) async {
    if (active != null && _same(active!, file)) {
      await endLog();
    }
    if (await file.exists()) await file.delete();
  }

  Future<void> revealFile(File file) async {
    if (reveal != null) {
      await reveal!(file.path);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', file.path]);
    }
  }

  static String _safe(String name) =>
      name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

  static String _csv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _stamp(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    final l = at.toLocal();
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}${two(l.minute)}';
  }

  static bool _same(File a, File b) => a.absolute.path == b.absolute.path;
}
