import 'dart:async';

import 'package:tiltawort/tilt/calibrate.dart';
import 'package:tiltawort/tilt/csv_log.dart';
import 'package:tiltawort/tilt/history.dart';
import 'package:tiltawort/tilt/prefs.dart';
import 'package:tiltawort/tilt/scanner.dart';
import 'package:tiltawort/tilt/units.dart';

/// Process-wide CSV logger. Device Start/Stop/Snapshot call this; ads append here.
class LogRunner {
  LogRunner({
    required this.scanner,
    required this.logs,
    required this.prefs,
    this.history,
  });

  final TiltScanner scanner;
  final CsvLogStore logs;
  final PrefsStore prefs;
  final SessionHistory? history;

  final _cache = <String, TiltPrefs>{};
  StreamSubscription<TiltAdvertisementEvent>? _sub;
  var _attached = false;

  bool isRecording(String color) => logs.isOpenFor(color);

  void attach() {
    if (_attached) return;
    _attached = true;
    _sub = scanner.advertisements.listen(ingest);
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
    _attached = false;
  }

  Future<TiltPrefs> prefsFor(String uuid) async {
    final cached = _cache[uuid];
    if (cached != null) return cached;
    final loaded = await prefs.load(uuid);
    _cache[uuid] = loaded;
    return loaded;
  }

  void forgetPrefs(String uuid) => _cache.remove(uuid);

  Future<void> startRecording({
    required String uuid,
    required String color,
    required String beer,
    DateTime? at,
  }) async {
    await logs.startLog(color: color, beer: beer, at: at);
    final current = await prefsFor(uuid);
    final next = current.copyWith(logging: true, name: beer);
    _cache[uuid] = next;
    await prefs.save(uuid, next);
  }

  Future<void> stopRecording({
    required String uuid,
    required String color,
  }) async {
    await logs.endLog(color);
    final current = await prefsFor(uuid);
    final next = current.copyWith(logging: false);
    _cache[uuid] = next;
    await prefs.save(uuid, next);
  }

  Future<void> snapshot({
    required String uuid,
    required String color,
    required String beer,
    required double sg,
    required double tempF,
    DateTime? at,
    String comment = '',
    String tempUnit = 'F',
  }) async {
    if (!logs.isOpenFor(color)) {
      await startRecording(uuid: uuid, color: color, beer: beer, at: at);
    }
    final p = await prefsFor(uuid);
    await logs.append(
      timestamp: at ?? DateTime.now(),
      sg: sg,
      temp: tempF,
      color: color,
      beer: beer,
      comment: comment,
      force: true,
      tempUnit: tempUnit.isEmpty ? p.tempUnit : tempUnit,
    );
  }

  Future<void> ingest(TiltAdvertisementEvent event) async {
    final ad = event.advertisement;
    if (!logs.isOpenFor(ad.color)) return;
    final p = await prefsFor(ad.uuid);
    final sg = applyCal(ad.sg, p.cal);
    final temp = p.tempUnit == 'C' ? fToC(ad.tempF) : ad.tempF;
    await logs.append(
      timestamp: event.receivedAt,
      sg: sg,
      temp: temp,
      color: ad.color,
      beer: p.name,
      intervalSeconds: p.logIntervalSeconds,
      tempUnit: p.tempUnit,
    );
    history?.add(
      ad.uuid,
      SessionSample(at: event.receivedAt, sg: sg, tempF: ad.tempF),
    );
  }
}
