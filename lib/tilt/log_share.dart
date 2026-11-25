import 'package:flutter/foundation.dart';

String logFileActionLabel(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return 'Share';
    default:
      return 'Reveal';
  }
}

bool logFileActionIsShare(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS;
