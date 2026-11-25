import 'package:flutter/material.dart';
import 'package:tiltawort/tilt/updates.dart';
import 'package:tiltawort/ui/theme.dart';

Future<bool> showUpdateDialog(
  BuildContext context, {
  required UpdateOffer offer,
  required UpdateOs os,
}) async {
  final p = TiltPalette.of(context);
  final notes = offer.notes.trim().isEmpty
      ? 'A newer build is on GitHub Releases.'
      : offer.notes.trim();
  final smart = os == UpdateOs.windows
      ? '\n\nWindows may show SmartScreen again (More info, Run anyway).'
      : os == UpdateOs.android
          ? '\n\nAndroid will open the system installer. Confirm there.'
          : '';
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: p.surface,
        title: Text(
          'Update to ${offer.tag}',
          style: soraTitle.copyWith(color: p.primary, fontSize: 18),
        ),
        content: Text(
          '$notes$smart',
          style: soraBody.copyWith(color: p.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not now', style: soraBody.copyWith(color: p.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Update', style: soraBody.copyWith(color: p.primary)),
          ),
        ],
      );
    },
  );
  return go == true;
}
