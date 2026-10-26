String formatSg(double sg, {required bool isPro}) =>
    sg.toStringAsFixed(isPro ? 4 : 3);

String formatTempF(double tempF, {required bool isPro}) {
  if (isPro) return '${tempF.toStringAsFixed(1)} °F';
  return '${tempF.round()} °F';
}

String formatTempC(double tempF, {required bool isPro}) {
  final c = fToC(tempF);
  if (isPro) return '${c.toStringAsFixed(1)} °C';
  return '${c.round()} °C';
}

double sgToPlato(double sg) => 259 - (259 / sg);

double fToC(double tempF) => (tempF - 32) * 5 / 9;

String formatGravity(double sg, {required bool isPro, required String unit}) {
  if (unit == 'P') {
    return sgToPlato(sg).toStringAsFixed(isPro ? 2 : 1);
  }
  return formatSg(sg, isPro: isPro);
}

String formatTemp(double tempF, {required bool isPro, required String unit}) {
  if (unit == 'C') return formatTempC(tempF, isPro: isPro);
  return formatTempF(tempF, isPro: isPro);
}

String relativeAgo(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inSeconds < 60) return '${d.inSeconds} s ago';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 48) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

bool isEpoch(DateTime at) => at.millisecondsSinceEpoch == 0;

String lastHeardLabel(DateTime at, DateTime now) {
  if (isEpoch(at)) return '';
  return relativeAgo(at, now);
}

String localStamp(DateTime at) {
  final l = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

String rssiLabel(int? rssiDbm) => rssiDbm == null ? '—' : '$rssiDbm dBm';
