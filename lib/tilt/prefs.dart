import 'dart:convert';
import 'dart:io';

import 'package:tiltawort/tilt/calibrate.dart';

class TiltPrefs {
  const TiltPrefs({
    this.name = '',
    this.tempUnit = 'F',
    this.gravityUnit = 'SG',
    this.cal = const [],
    this.logging = false,
    this.logIntervalSeconds = 0,
  });

  final String name;
  final String tempUnit;
  final String gravityUnit;
  final List<CalPoint> cal;
  final bool logging;
  final int logIntervalSeconds;

  static const defaults = TiltPrefs();

  TiltPrefs copyWith({
    String? name,
    String? tempUnit,
    String? gravityUnit,
    List<CalPoint>? cal,
    bool? logging,
    int? logIntervalSeconds,
  }) {
    return TiltPrefs(
      name: name ?? this.name,
      tempUnit: tempUnit ?? this.tempUnit,
      gravityUnit: gravityUnit ?? this.gravityUnit,
      cal: cal ?? this.cal,
      logging: logging ?? this.logging,
      logIntervalSeconds: logIntervalSeconds ?? this.logIntervalSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'tempUnit': tempUnit,
        'gravityUnit': gravityUnit,
        'cal': [
          for (final p in cal) {'uncalSg': p.uncalSg, 'actualSg': p.actualSg},
        ],
        'logging': logging,
        'logIntervalSeconds': logIntervalSeconds,
      };

  factory TiltPrefs.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final rawCal = json['cal'];
    final cal = <CalPoint>[];
    if (rawCal is List) {
      for (final item in rawCal) {
        if (item is Map) {
          final uncal = item['uncalSg'];
          final actual = item['actualSg'];
          if (uncal is num && actual is num) {
            cal.add(CalPoint(uncalSg: uncal.toDouble(), actualSg: actual.toDouble()));
          }
        }
      }
    }
    return TiltPrefs(
      name: json['name'] as String? ?? '',
      tempUnit: json['tempUnit'] as String? ?? 'F',
      gravityUnit: json['gravityUnit'] as String? ?? 'SG',
      cal: cal,
      logging: json['logging'] as bool? ?? false,
      logIntervalSeconds: json['logIntervalSeconds'] is num
          ? (json['logIntervalSeconds'] as num).toInt()
          : 0,
    );
  }
}

class PrefsStore {
  PrefsStore(this.file);

  final File file;

  Future<Map<String, dynamic>> _readAll() async {
    if (!await file.exists()) return {};
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return {};
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<TiltPrefs> load(String uuid) async {
    final all = await _readAll();
    final raw = all[uuid];
    if (raw is Map<String, dynamic>) return TiltPrefs.fromJson(raw);
    if (raw is Map) return TiltPrefs.fromJson(Map<String, dynamic>.from(raw));
    return TiltPrefs.defaults;
  }

  Future<void> save(String uuid, TiltPrefs prefs) async {
    final all = await _readAll();
    all[uuid] = prefs.toJson();
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(all));
  }

  Future<List<String>> loggingUuids() async {
    final all = await _readAll();
    final out = <String>[];
    for (final entry in all.entries) {
      Map<String, dynamic>? raw;
      if (entry.value is Map<String, dynamic>) {
        raw = entry.value as Map<String, dynamic>;
      } else if (entry.value is Map) {
        raw = Map<String, dynamic>.from(entry.value as Map);
      }
      if (raw == null) continue;
      if (TiltPrefs.fromJson(raw).logging) out.add(entry.key);
    }
    return out;
  }

  Future<void> remove(String uuid) async {
    final all = await _readAll();
    all.remove(uuid);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(all));
  }
}
