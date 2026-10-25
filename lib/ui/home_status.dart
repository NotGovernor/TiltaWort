import 'package:tiltawort/tilt/scanner.dart';

enum HomeStatusKind { radioOff, empty, noneLive, heard }

class HomeStatus {
  const HomeStatus({required this.kind, this.liveCount = 0});

  final HomeStatusKind kind;
  final int liveCount;

  String get line {
    switch (kind) {
      case HomeStatusKind.radioOff:
        return 'Bluetooth is off. This app only listens.';
      case HomeStatusKind.empty:
        return 'No Tilts heard. They broadcast about every 5 seconds. This app only listens.';
      case HomeStatusKind.noneLive:
        return 'Scanning · none live';
      case HomeStatusKind.heard:
        return 'Scanning · heard $liveCount';
    }
  }

  static HomeStatus of({
    required RadioState radio,
    required int liveCount,
    required int tileCount,
  }) {
    if (radio == RadioState.off) {
      return const HomeStatus(kind: HomeStatusKind.radioOff);
    }
    if (tileCount == 0) {
      return const HomeStatus(kind: HomeStatusKind.empty);
    }
    if (liveCount == 0) {
      return const HomeStatus(kind: HomeStatusKind.noneLive);
    }
    return HomeStatus(kind: HomeStatusKind.heard, liveCount: liveCount);
  }
}
