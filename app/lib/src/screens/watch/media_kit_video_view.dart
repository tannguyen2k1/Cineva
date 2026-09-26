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
    this.loading = false,
  });

  final VideoController controller;
  final double bottomPadding;
  final bool hideBuffering;
  final bool loading;

  @override
  State<MediaKitVideoView> createState() => _MediaKitVideoViewState();
}

class _MediaKitVideoViewState extends State<MediaKitVideoView> {
  final _brightness = ScreenBrightness();
  double _level = 1;
  bool _ready = false;
  bool _locked = false;
  bool _lockHint = false;
  Timer? _lockTimer;

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

  void _armLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _lockHint = false);
    });
  }

  void _lock() {
    setState(() {
      _locked = true;
      _lockHint = true;
    });
    _armLockTimer();
  }

  void _unlock() {
    _lockTimer?.cancel();
    setState(() {
      _locked = false;
      _lockHint = false;
    });
  }

  void _onLockedTap() {
    if (_lockHint) {
      _lockTimer?.cancel();
      setState(() => _lockHint = false);
      return;
    }
    setState(() => _lockHint = true);
    _armLockTimer();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    unawaited(_resetBrightness());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.expand();
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
      topButtonBar: [
        IconButton(
          onPressed: _lock,
          icon: const Icon(Icons.lock_open_rounded),
          color: Colors.white,
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: _locked,
            child: _player(theme),
          ),
          if (_locked)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onLockedTap,
              child: Stack(
                children: [
                  if (_lockHint)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Material(
                          color: const Color(0x66000000),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            onPressed: _unlock,
                            icon: const Icon(Icons.lock_rounded),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (widget.loading)
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: CinevaColors.accent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _player(MaterialVideoControlsThemeData theme) {
    final player = widget.controller.player;
    return PlaybackGestures(
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
          controls: _locked ? _hiddenControls : MaterialVideoControls,
        ),
      ),
    );
  }
}

Widget _hiddenControls(VideoState _) => const SizedBox.shrink();
