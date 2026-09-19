import 'package:flutter/services.dart';

/// Phone orientation helpers. iPad/UIScene often rejects these — ignore errors.
///
/// Rest of the app stays portrait-locked. Watch screen unlocks rotation while
/// the player is open (Netflix / YouTube style).
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

  /// Allow portrait + landscape while the watch player is open.
  static Future<void> unlockForPlayer() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    } catch (_) {}
  }

  static Future<void> enterImmersive() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}
  }

  static Future<void> exitImmersive() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    } catch (_) {}
  }

  /// Snap UI to portrait once, then keep player rotation unlocked.
  static Future<void> snapToPortraitThenUnlock() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await unlockForPlayer();
    } catch (_) {}
  }
}
