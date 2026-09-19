import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/cineva_theme.dart';

/// Netflix-style toast: slides in under the status bar (not from the bottom nav).
void showCinevaToast(
  BuildContext context,
  String message, {
  bool error = false,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _CinevaToastHost(
      message: message,
      error: error,
      duration: duration,
      onDone: () {
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _CinevaToastHost extends StatefulWidget {
  const _CinevaToastHost({
    required this.message,
    required this.error,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final bool error;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_CinevaToastHost> createState() => _CinevaToastHostState();
}

class _CinevaToastHostState extends State<_CinevaToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 10;
    final bg = widget.error ? const Color(0xFF7F1D1D) : const Color(0xF01A1A22);
    final border = widget.error
        ? const Color(0xFFF87171).withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.12);

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.error
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 20,
                      color: widget.error
                          ? const Color(0xFFFCA5A5)
                          : CinevaColors.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Color(0xFFF4F4F5),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
