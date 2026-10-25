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
  });

  final String name;
  final String tempUnit;
  final String gravityUnit;
  final List<CalPoint> cal;
  final bool logging;

  static const defaults = TiltPrefs();

  Map<String, dynamic> toJson() => {
        'name': name,
        'tempUnit': tempUnit,
        'gravityUnit': gravityUnit,
        'cal': [
          for (final p in cal) {'uncalSg': p.uncalSg, 'actualSg': p.actualSg},
        ],
        'logging': logging,
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
    );
  }
}

class PrefsStore {
  PrefsStore(this.file);

  final File file;

  Future<Map<String, dynamic>> _readAll() async {
    if (!await file.exists()) return {};
    final text = await file.readAsString();
    if (text.trim().isEmpty) return {};
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
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
}
