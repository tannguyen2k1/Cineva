import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../theme/cineva_theme.dart';

Widget hidePlayerSpinner(BuildContext _) => const SizedBox.shrink();

class NativeVideoView extends StatefulWidget {
  const NativeVideoView({
    super.key,
    required this.controller,
    required this.bottomPadding,
    required this.hideBuffering,
  });

  final VideoController controller;
  final double bottomPadding;
  final bool hideBuffering;

  @override
  State<NativeVideoView> createState() => _NativeVideoViewState();
}

class _NativeVideoViewState extends State<NativeVideoView> {
  final _brightness = ScreenBrightness();
  double _level = 1;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_readBrightness());
  }

  Future<void> _readBrightness() async {
    try {
      final current = await _brightness.system.timeout(
        const Duration(milliseconds: 800),
      );
      _level = current.clamp(0.0, 1.0);
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _setBrightness(double value) async {
    try {
      await _brightness.setApplicationScreenBrightness(value.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> _resetBrightness() async {
    try {
      await _brightness.resetApplicationScreenBrightness();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.expand();
    final volume =
        (widget.controller.player.state.volume / 100).clamp(0.0, 1.0);
    final theme = MaterialVideoControlsThemeData(
      seekBarPositionColor: CinevaColors.accent,
      seekBarThumbColor: CinevaColors.accent,
      seekBarMargin: const EdgeInsets.only(bottom: 16),
      bottomButtonBarMargin: const EdgeInsets.only(
        left: 16,
        right: 8,
        bottom: 16,
      ),
      seekGesture: true,
      seekOnDoubleTap: true,
      seekOnDoubleTapEnabledWhileControlsVisible: true,
      gesturesEnabledWhileControlsVisible: true,
      volumeGesture: true,
      initialVolume: volume,
      onVolumeChanged: (value) {
        widget.controller.player.setVolume(value * 100);
      },
      brightnessGesture: true,
      initialBrightness: _level,
      onBrightnessChanged: (value) {
        unawaited(_setBrightness(value));
      },
      onBrightnessReset: () {
        unawaited(_resetBrightness());
      },
      bufferingIndicatorBuilder:
          widget.hideBuffering ? hidePlayerSpinner : null,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: MaterialVideoControlsTheme(
        normal: theme,
        fullscreen: theme,
        child: Video(
          controller: widget.controller,
          fill: Colors.black,
          fit: BoxFit.contain,
          controls: MaterialVideoControls,
        ),
      ),
    );
  }
}
