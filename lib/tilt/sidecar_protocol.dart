import 'dart:convert';

import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/scanner.dart';

class SidecarAdapterLine {
  const SidecarAdapterLine(this.state);
  final String state;
  bool get isOn => state == 'PoweredOn';
}

class SidecarAdLine {
  const SidecarAdLine({
    required this.companyId,
    required this.payload,
    this.rssi,
    this.address,
  });
  final int companyId;
  final List<int> payload;
  final int? rssi;
  final String? address;
}

/// One JSON object per sidecar stdout line. Unknown lines → null.
Object? parseSidecarLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return null;
  final decoded = jsonDecode(trimmed);
  if (decoded is! Map) return null;
  final map = Map<String, dynamic>.from(decoded);
  final type = map['type'] as String?;
  if (type == 'adapter') {
    return SidecarAdapterLine(map['state'] as String? ?? '');
  }
  if (type == 'ad') {
    final company = map['companyId'];
    if (company is! num) return null;
    final raw = map['payload'];
    if (raw is! List) return null;
    final payload = <int>[];
    for (final b in raw) {
      if (b is num) payload.add(b.toInt());
    }
    final rssi = map['rssi'];
    return SidecarAdLine(
      companyId: company.toInt(),
      payload: payload,
      rssi: rssi is num ? rssi.toInt() : null,
      address: map['address'] as String?,
    );
  }
  return null;
}

TiltAdvertisementEvent? eventFromSidecarAd(SidecarAdLine ad, {DateTime? now}) {
  final decoded = decodeTilt(companyId: ad.companyId, payload: ad.payload);
  if (decoded == null) return null;
  return TiltAdvertisementEvent(
    advertisement: decoded,
    receivedAt: now ?? DateTime.now(),
    rssiDbm: ad.rssi,
  );
}
