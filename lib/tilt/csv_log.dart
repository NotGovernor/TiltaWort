import 'dart:io';

import 'package:tiltawort/tilt/units.dart';

/// Recording UI is the open file, not the leftover prefs.logging flag.
bool recordingUi({required bool prefsLogging, required bool fileOpen}) =>
    fileOpen;

class LogInterval {
  const LogInterval(this.seconds, this.chip, this.status);
  final int seconds;
  final String chip;
  final String status;
}

const logIntervals = [
  LogInterval(0, 'Every reading (~5 s)', 'every reading'),
  LogInterval(60, 'Every 1 min', 'every 1 min'),
  LogInterval(300, 'Every 5 min', 'every 5 min'),
  LogInterval(900, 'Every 15 min', 'every 15 min'),
  LogInterval(3600, 'Every 1 hour', 'every 1 hour'),
  LogInterval(21600, 'Every 6 hours', 'every 6 hours'),
  LogInterval(86400, 'Once a day', 'once a day'),
];

String intervalStatus(int seconds) {
  for (final i in logIntervals) {
    if (i.seconds == seconds) return i.status;
  }
  return 'every ${seconds}s';
}

String recordingStatusLine({
  required bool isOpen,
  String? fileName,
  required int intervalSeconds,
}) {
  if (!isOpen) return 'Not recording';
  final name = (fileName == null || fileName.isEmpty) ? 'log.csv' : fileName;
  return 'Recording · $name · ${intervalStatus(intervalSeconds)}';
}

class _ActiveLog {
  _ActiveLog({required this.file, required this.logStart, this.lastWrite});

  File file;
  DateTime logStart;
  DateTime? lastWrite;
}

class CsvLogStore {
  CsvLogStore(this.directory, {this.reveal});

  static const header = 'Timestamp,Timepoint,SG,Plato,Temp,TempUnit,Color,Beer,Comment';

  final Directory directory;
  final Future<void> Function(String path)? reveal;
  final _active = <String, _ActiveLog>{};

  bool isOpenFor(String color) => _active.containsKey(color);

  File? activeFor(String color) => _active[color]?.file;

  DateTime? lastWriteFor(String color) => _active[color]?.lastWrite;

  bool get isOpen => _active.isNotEmpty;

  File? get active => _active.length == 1 ? _active.values.first.file : null;

  DateTime? get lastWrite =>
      _active.length == 1 ? _active.values.first.lastWrite : null;

  bool shouldWrite(String color, DateTime now, int intervalSeconds) {
    final log = _active[color];
    if (log == null) return false;
    if (intervalSeconds <= 0) return true;
    if (log.lastWrite == null) return true;
    return now.difference(log.lastWrite!) >= Duration(seconds: intervalSeconds);
  }

  Future<File> startLog({
    required String color,
    required String beer,
    DateTime? at,
  }) async {
    await directory.create(recursive: true);
    final when = at ?? DateTime.now();
    final stamp = _stamp(when);
    final safe = _safe(beer.trim().isEmpty ? 'Untitled' : beer);
    final name = '$safe ($color TILT) $stamp.csv';
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsString('$header\n');
    _active[color] = _ActiveLog(file: file, logStart: when);
    return file;
  }

  Future<void> endLog([String? color]) async {
    if (color == null) {
      _active.clear();
    } else {
      _active.remove(color);
    }
  }

  Future<void> append({
    required DateTime timestamp,
    required double sg,
    required double temp,
    required String color,
    required String beer,
    String comment = '',
    bool force = false,
    int intervalSeconds = 0,
    String tempUnit = 'F',
  }) async {
    final log = _active[color];
    if (log == null) return;
    if (!force && !shouldWrite(color, timestamp, intervalSeconds)) return;
    final timepoint =
        timestamp.difference(log.logStart).inMicroseconds / Duration.microsecondsPerDay;
    final row = [
      timestamp.toIso8601String(),
      timepoint.toStringAsFixed(6),
      sg.toString(),
      sgToPlato(sg).toStringAsFixed(2),
      temp.toString(),
      _csv(tempUnit),
      _csv(color),
      _csv(beer),
      _csv(comment),
    ].join(',');
    await log.file.writeAsString('$row\n', mode: FileMode.append);
    log.lastWrite = timestamp;
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
    final colors = _active.entries
        .where((e) => _same(e.value.file, file))
        .map((e) => e.key)
        .toList();
    for (final color in colors) {
      await endLog(color);
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
