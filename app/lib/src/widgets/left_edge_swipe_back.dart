import 'package:flutter/material.dart';

/// Thin left-edge hit target for swipe-from-left → back.
///
/// Use when [PopScope.canPop] is false (e.g. watch screen) so Cupertino's
/// native back gesture is disabled, but users still get edge-swipe back.
class LeftEdgeSwipeBack extends StatefulWidget {
  const LeftEdgeSwipeBack({
    super.key,
    required this.onBack,
    required this.child,
    this.edgeWidth = 28,
    this.minVelocity = 280,
    this.minDistance = 64,
  });

  final VoidCallback onBack;
  final Widget child;
  final double edgeWidth;
  final double minVelocity;
  final double minDistance;

  @override
  State<LeftEdgeSwipeBack> createState() => _LeftEdgeSwipeBackState();
}

class _LeftEdgeSwipeBackState extends State<LeftEdgeSwipeBack> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _dx = 0,
            onHorizontalDragUpdate: (d) {
              _dx += d.delta.dx;
            },
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (_dx >= widget.minDistance || v >= widget.minVelocity) {
                widget.onBack();
              }
              _dx = 0;
            },
            onHorizontalDragCancel: () => _dx = 0,
          ),
        ),
      ],
    );
  }
}
