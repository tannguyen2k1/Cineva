import 'package:flutter/services.dart';

/// Phone orientation helpers. iPad/UIScene often rejects these — ignore errors.
///
/// App stays portrait-locked; only watch fullscreen temporarily forces landscape.
class PhoneOrientation {
  PhoneOrientation._();

  static Future<void> lockPortrait() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    } catch (_) {}
  }

  /// Force landscape after user taps fullscreen on the watch screen.
  static Future<void> forceLandscape() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}
  }
}
