import 'package:flutter/material.dart';

import '../../theme/cineva_theme.dart';
import 'hls_source.dart';

const _skipStep = Duration(seconds: 10);

/// Shared watch gestures. Each player applies seek, volume, and brightness.
class PlaybackGestures extends StatefulWidget {
  const PlaybackGestures({
    super.key,
    required this.position,
    required this.duration,
    required this.volume,
    required this.brightness,
    required this.onSeek,
    required this.onVolume,
    required this.onBrightness,
    this.onVolumeEnd,
    this.onTap,
    this.bottomReserve = 0,
    required this.child,
  });

  final Duration Function() position;
  final Duration Function() duration;
  final double Function() volume;
  final double Function() brightness;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onBrightness;
  final VoidCallback? onVolumeEnd;
  final VoidCallback? onTap;
  final double bottomReserve;
  final Widget child;

  @override
  State<PlaybackGestures> createState() => _PlaybackGesturesState();
}

class _PlaybackGesturesState extends State<PlaybackGestures> {
  Duration? _seekFrom;
  double _seekDx = 0;
  Duration? _seekTarget;
  DateTime? _lastSeekEmit;

  double? _slideOrigin;
  bool _slideVolume = false;
  double? _slideValue;

  String? _skipLabel;
  int _skipGen = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: widget.bottomReserve,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onSeekStart,
            onHorizontalDragUpdate: _onSeekUpdate,
            onHorizontalDragEnd: (_) => _onSeekEnd(),
            onHorizontalDragCancel: _onSeekEnd,
            onVerticalDragStart: _onSlideStart,
            onVerticalDragUpdate: _onSlideUpdate,
            onVerticalDragEnd: (_) => _onSlideEnd(),
            onVerticalDragCancel: _onSlideEnd,
            onDoubleTapDown: _onDoubleTapDown,
            onTap: widget.onTap,
            child: const SizedBox.expand(),
          ),
        ),
        if (_seekTarget != null || _slideValue != null || _skipLabel != null)
          IgnorePointer(
            child: Center(child: _hud()),
          ),
      ],
    );
  }

  void _onSeekStart(DragStartDetails details) {
    if (widget.duration() <= Duration.zero) return;
    _seekFrom = widget.position();
    _seekDx = 0;
    _seekTarget = _seekFrom;
    _lastSeekEmit = null;
  }

  void _onSeekUpdate(DragUpdateDetails details) {
    final from = _seekFrom;
    final total = widget.duration();
    if (from == null || total <= Duration.zero) return;
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    _seekDx += details.delta.dx;
    final deltaMs = total.inMilliseconds * (_seekDx / width);
    final target = _clamp(from + Duration(milliseconds: deltaMs.round()), total);
    setState(() => _seekTarget = target);
    _emitSeek(target);
  }

  void _onSeekEnd() {
    final target = _seekTarget;
    if (target != null) _emitSeek(target, force: true);
    _seekFrom = null;
    _seekTarget = null;
    _lastSeekEmit = null;
    if (mounted) setState(() {});
  }

  void _emitSeek(Duration target, {bool force = false}) {
    final now = DateTime.now();
    final last = _lastSeekEmit;
    if (!force && last != null && now.difference(last).inMilliseconds < 200) {
      return;
    }
    _lastSeekEmit = now;
    widget.onSeek(target);
  }

  void _onSlideStart(DragStartDetails details) {
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    _slideVolume = details.localPosition.dx >= width / 2;
    _slideOrigin = (_slideVolume ? widget.volume() : widget.brightness())
        .clamp(0.0, 1.0);
    _slideValue = _slideOrigin;
  }

  void _onSlideUpdate(DragUpdateDetails details) {
    final origin = _slideOrigin;
    if (origin == null) return;
    final height = context.size?.height ?? 0;
    if (height <= 0) return;
    final next = (origin - details.delta.dy / height).clamp(0.0, 1.0);
    _slideOrigin = next;
    setState(() => _slideValue = next);
    if (_slideVolume) {
      widget.onVolume(next);
    } else {
      widget.onBrightness(next);
    }
  }

  void _onSlideEnd() {
    if (_slideVolume) widget.onVolumeEnd?.call();
    _slideOrigin = null;
    _slideVolume = false;
    _slideValue = null;
    if (mounted) setState(() {});
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final total = widget.duration();
    if (total <= Duration.zero) return;
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    final x = details.localPosition.dx;
    final backward = x < width / 3;
    final forward = x > width * 2 / 3;
    if (!backward && !forward) return;
    final step = backward ? -_skipStep : _skipStep;
    final target = _clamp(widget.position() + step, total);
    widget.onSeek(target);
    final gen = ++_skipGen;
    setState(() => _skipLabel = backward ? '-10s' : '+10s');
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || gen != _skipGen) return;
      setState(() => _skipLabel = null);
    });
  }

  Duration _clamp(Duration value, Duration max) {
    if (value < Duration.zero) return Duration.zero;
    if (value > max) return max;
    return value;
  }

  Widget _hud() {
    final seek = _seekTarget;
    final slide = _slideValue;
    final skip = _skipLabel;
    late final IconData icon;
    late final String label;
    if (seek != null) {
      icon = Icons.swap_horiz;
      label = clockLabel(seek.inSeconds);
    } else if (slide != null) {
      icon = _slideVolume ? Icons.volume_up : Icons.brightness_medium;
      label = '${(slide * 100).round()}%';
    } else {
      icon = skip == '-10s' ? Icons.replay_10 : Icons.forward_10;
      label = skip ?? '';
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC111111),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CinevaColors.accent, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
