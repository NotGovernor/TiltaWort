class SessionSample {
  const SessionSample({
    required this.at,
    required this.sg,
    required this.tempF,
  });

  final DateTime at;
  final double sg;
  final double tempF;
}

/// In-memory session ring. Empty means empty — never invent 1.000.
class SessionHistory {
  SessionHistory({this.cap = 2000});

  final int cap;
  final _byUuid = <String, List<SessionSample>>{};

  List<SessionSample> of(String uuid) =>
      List.unmodifiable(_byUuid[uuid] ?? const <SessionSample>[]);

  void add(String uuid, SessionSample sample) {
    final list = _byUuid.putIfAbsent(uuid, () => <SessionSample>[]);
    for (final existing in list) {
      if (existing.at == sample.at) return;
    }
    var i = list.length;
    while (i > 0 && list[i - 1].at.isAfter(sample.at)) {
      i--;
    }
    list.insert(i, sample);
    if (list.length > cap) {
      list.removeRange(0, list.length - cap);
    }
  }

  void mergeAll(String uuid, Iterable<SessionSample> samples) {
    for (final sample in samples) {
      add(uuid, sample);
    }
  }
}
