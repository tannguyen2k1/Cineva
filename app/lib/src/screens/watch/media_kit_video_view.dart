import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../theme/cineva_theme.dart';
import 'playback_gestures.dart';

Widget hidePlayerSpinner(BuildContext _) => const SizedBox.shrink();

class MediaKitVideoView extends StatefulWidget {
  const MediaKitVideoView({
    super.key,
    required this.controller,
    required this.bottomPadding,
    required this.hideBuffering,
  });

  final VideoController controller;
  final double bottomPadding;
  final bool hideBuffering;

  @override
  State<MediaKitVideoView> createState() => _MediaKitVideoViewState();
}

class _MediaKitVideoViewState extends State<MediaKitVideoView> {
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
  void dispose() {
    unawaited(_resetBrightness());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.expand();
    final player = widget.controller.player;
    final theme = MaterialVideoControlsThemeData(
      seekBarPositionColor: CinevaColors.accent,
      seekBarThumbColor: CinevaColors.accent,
      seekBarMargin: const EdgeInsets.only(bottom: 16),
      bottomButtonBarMargin: const EdgeInsets.only(
        left: 16,
        right: 8,
        bottom: 16,
      ),
      seekGesture: false,
      seekOnDoubleTap: false,
      volumeGesture: false,
      brightnessGesture: false,
      bufferingIndicatorBuilder:
          widget.hideBuffering ? hidePlayerSpinner : null,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: PlaybackGestures(
        position: () => player.state.position,
        duration: () => player.state.duration,
        volume: () => (player.state.volume / 100).clamp(0.0, 1.0),
        brightness: () => _level,
        onSeek: (position) {
          unawaited(player.seek(position));
        },
        onVolume: (value) {
          unawaited(player.setVolume(value * 100));
        },
        onBrightness: (value) {
          _level = value;
          unawaited(_setBrightness(value));
        },
        bottomReserve: 96,
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
      ),
    );
  }
}
