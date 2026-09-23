import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/cineva_toast.dart';

/// Manages the runtime app mode (Normal vs 18+ Easter Egg).
/// CRITICAL: In-memory only! Never persist to SharedPreferences or disk.
/// When the user closes or restarts the app, it always resets to normal mode.
class AppModeState extends ChangeNotifier {
  bool _is18Plus = false;

  bool get is18Plus => _is18Plus;

  void toggle18Plus(BuildContext context) {
    _is18Plus = !_is18Plus;
    notifyListeners();
    HapticFeedback.heavyImpact();
    if (_is18Plus) {
      showCinevaToast(
        context,
        '🔥 Đã kích hoạt chế độ Cineva 18+',
      );
    } else {
      showCinevaToast(
        context,
        '🎬 Đã trở về chế độ Cineva thông thường',
      );
    }
  }

  void exit18Plus(BuildContext context) {
    if (!_is18Plus) return;
    _is18Plus = false;
    notifyListeners();
    HapticFeedback.mediumImpact();
    showCinevaToast(
      context,
      '🎬 Đã trở về chế độ Cineva thông thường',
    );
  }
}
