class TiltAdvertisement {
  const TiltAdvertisement({
    required this.color,
    required this.uuid,
    required this.tempF,
    required this.sg,
    required this.isPro,
  });
  final String color;
  final String uuid;
  final double tempF;
  final double sg;
  final bool isPro;
  double get tempC => (tempF - 32) * 5 / 9;
}

const tiltColors = <String, String>{
  'A495BB10-C5B1-4B44-B512-1370F02D74DE': 'Red',
  'A495BB20-C5B1-4B44-B512-1370F02D74DE': 'Green',
  'A495BB30-C5B1-4B44-B512-1370F02D74DE': 'Black',
  'A495BB40-C5B1-4B44-B512-1370F02D74DE': 'Purple',
  'A495BB50-C5B1-4B44-B512-1370F02D74DE': 'Orange',
  'A495BB60-C5B1-4B44-B512-1370F02D74DE': 'Blue',
  'A495BB70-C5B1-4B44-B512-1370F02D74DE': 'Yellow',
  'A495BB80-C5B1-4B44-B512-1370F02D74DE': 'Pink',
};

String _uuid(List<int> b) {
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final s = StringBuffer();
  for (var i = 0; i < 16; i++) {
    s.write(h(i));
    if (i == 3 || i == 5 || i == 7 || i == 9) s.write('-');
  }
  return s.toString().toUpperCase();
}

TiltAdvertisement? decodeTilt({required int companyId, required List<int> payload}) {
  if (companyId != 0x004C) return null;
  var p = payload;
  if (p.length >= 2 && p[0] == 0x4C && p[1] == 0x00) p = p.sublist(2);
  if (p.length < 23 || p[0] != 0x02 || p[1] != 0x15) return null;
  final uuid = _uuid(p.sublist(2, 18));
  final color = tiltColors[uuid];
  if (color == null) return null;
  final major = (p[18] << 8) | p[19];
  final minor = (p[20] << 8) | p[21];
  final isPro = minor > 5000;
  return TiltAdvertisement(
    color: color,
    uuid: uuid,
    tempF: isPro ? major / 10.0 : major.toDouble(),
    sg: isPro ? minor / 10000.0 : minor / 1000.0,
    isPro: isPro,
  );
}
