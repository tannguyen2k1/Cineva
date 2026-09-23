import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_mode_state.dart';
import '../theme/cineva_theme.dart';
import 'cineva_brand_mark.dart';
import 'notification_bell.dart';

class CinevaHeader extends StatefulWidget {
  const CinevaHeader({
    super.key,
    this.onSearch,
    this.trailing,
    this.showTagline = false,
    this.showNotifications = true,
  });

  final VoidCallback? onSearch;
  final Widget? trailing;
  final bool showTagline;
  final bool showNotifications;

  @override
  State<CinevaHeader> createState() => _CinevaHeaderState();
}

class _CinevaHeaderState extends State<CinevaHeader> {
  Timer? _holdTimer;
  Offset? _pointerStart;
  int _secondsHeld = 0;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerStart = event.position;
    _secondsHeld = 0;
    _holdTimer?.cancel();
    // Countdown with haptic feedback tick each second
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _secondsHeld++;
      HapticFeedback.selectionClick();
      if (_secondsHeld >= 4) {
        timer.cancel();
        _holdTimer = null;
        context.read<AppModeState>().toggle18Plus(context);
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerStart != null &&
        (event.position - _pointerStart!).distance > 35) {
      _cancelHold();
    }
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pointerStart = null;
    _secondsHeld = 0;
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeState>();
    final is18 = appMode.is18Plus;

    return Material(
      color: CinevaColors.bg.withValues(alpha: 0.82),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: is18
                  ? const Color(0xFFFF2A85).withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: (_) => _cancelHold(),
                  onPointerCancel: (_) => _cancelHold(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CinevaBrandMark(size: 30, is18Plus: is18),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Cineva',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.3,
                                  color: is18 ? Colors.white : null,
                                ),
                              ),
                              if (is18) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF1475).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFFF1475).withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    '18+',
                                    style: TextStyle(
                                      color: Color(0xFFFF529D),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (widget.showTagline && !is18)
                            const Text(
                              'Xem phim chất lượng cao',
                              style: TextStyle(
                                color: CinevaColors.muted,
                                fontSize: 11,
                                height: 1.1,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (is18)
                  IconButton(
                    tooltip: 'Thoát chế độ 18+',
                    onPressed: () => appMode.exit18Plus(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      foregroundColor: const Color(0xFFFF529D),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 19),
                  ),
                if (widget.showNotifications && !is18) ...[
                  const NotificationBell(),
                  const SizedBox(width: 4),
                ],
                if (widget.onSearch != null)
                  IconButton(
                    tooltip: 'Tìm kiếm',
                    onPressed: widget.onSearch,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.search_rounded, size: 20),
                  ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 4),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
