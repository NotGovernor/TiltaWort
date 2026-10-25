import 'package:tiltawort/tilt/calibrate.dart';
import 'package:tiltawort/tilt/decode.dart';
import 'package:tiltawort/tilt/scanner.dart';

class TiltView {
  const TiltView({
    required this.uuid,
    required this.color,
    this.name = '',
    required this.rawSg,
    required this.rawTempF,
    required this.calSg,
    required this.calTempF,
    required this.isPro,
    this.rssiDbm,
    required this.lastPacket,
  });

  final String uuid;
  final String color;
  final String name;
  final double rawSg;
  final double rawTempF;
  final double calSg;
  final double calTempF;
  final bool isPro;
  final int? rssiDbm;
  final DateTime lastPacket;

  bool isLiveAt(DateTime now) =>
      now.difference(lastPacket) <= const Duration(seconds: 30);

  factory TiltView.fromEvent(
    TiltAdvertisementEvent event, {
    String name = '',
    List<CalPoint> cal = const [],
  }) {
    final ad = event.advertisement;
    return TiltView(
      uuid: ad.uuid,
      color: ad.color,
      name: name,
      rawSg: ad.sg,
      rawTempF: ad.tempF,
      calSg: applyCal(ad.sg, cal),
      calTempF: ad.tempF,
      isPro: ad.isPro,
      rssiDbm: event.rssiDbm,
      lastPacket: event.receivedAt,
    );
  }
}
