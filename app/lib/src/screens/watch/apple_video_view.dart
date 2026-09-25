import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../theme/cineva_theme.dart';
import 'hls_source.dart';
import 'playback_gestures.dart';

/// AVPlayer surface on iOS. Gestures come from [PlaybackGestures].
class AppleVideoController {
  AppleVideoController() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('cineva/apple');

  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _volumes = StreamController<double>.broadcast();

  Stream<Duration> get position => _positions.stream;
  Stream<Duration> get duration => _durations.stream;
  Stream<bool> get completed => _completed.stream;
  Stream<String> get errors => _errors.stream;
  Stream<bool> get playing => _playing.stream;
  Stream<double> get volumes => _volumes.stream;

  Future<void> open({
    required String url,
    required Map<String, String> headers,
    required bool play,
  }) {
    return _channel.invokeMethod('open', {
      'url': url,
      'headers': headers,
      'play': play,
    });
  }

  Future<void> play() => _channel.invokeMethod('play');

  Future<void> pause() => _channel.invokeMethod('pause');

  Future<void> seek(Duration position) {
    return _channel.invokeMethod('seek', {'positionMs': position.inMilliseconds});
  }

  Future<void> setVolume(double volume) {
    return _channel.invokeMethod('setVolume', {'volume': volume.clamp(0.0, 1.0)});
  }

  Future<void> stop() => _channel.invokeMethod('stop');

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'state') return;
    final raw = call.arguments;
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final error = map['error']?.toString() ?? '';
    if (error.isNotEmpty && !_errors.isClosed) _errors.add(error);
    final durationMs = map['durationMs'];
    if (durationMs is num && durationMs > 0 && !_durations.isClosed) {
      _durations.add(Duration(milliseconds: durationMs.round()));
    }
    final positionMs = map['positionMs'];
    if (positionMs is num && !_positions.isClosed) {
      _positions.add(Duration(milliseconds: positionMs.round()));
    }
    if (map['completed'] == true && !_completed.isClosed) _completed.add(true);
    if (map['playing'] is bool && !_playing.isClosed) {
      _playing.add(map['playing'] as bool);
    }
    final volume = map['volume'];
    if (volume is num && !_volumes.isClosed) {
      _volumes.add(volume.toDouble().clamp(0.0, 1.0));
    }
  }

  void close() {
    unawaited(stop());
    unawaited(_positions.close());
    unawaited(_durations.close());
    unawaited(_completed.close());
    unawaited(_errors.close());
    unawaited(_playing.close());
    unawaited(_volumes.close());
  }
}

class AppleVideoView extends StatefulWidget {
  const AppleVideoView({super.key, required this.controller});

  final AppleVideoController controller;

  @override
  State<AppleVideoView> createState() => _AppleVideoViewState();
}

class _AppleVideoViewState extends State<AppleVideoView> {
  final _brightnessApi = ScreenBrightness();
  final _subs = <StreamSubscription<dynamic>>[];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1;
  double _brightness = 1;
  bool _playing = false;
  bool _ready = false;
  bool _holdVolume = false;
  bool _scrubbing = false;
  double _scrubSec = 0;

  @override
  void initState() {
    super.initState();
    _subs.add(widget.controller.position.listen((value) {
      if (!mounted || _scrubbing) return;
      setState(() => _position = value);
    }));
    _subs.add(widget.controller.duration.listen((value) {
      if (!mounted) return;
      setState(() => _duration = value);
    }));
    _subs.add(widget.controller.playing.listen((value) {
      if (!mounted) return;
      setState(() => _playing = value);
    }));
    _subs.add(widget.controller.volumes.listen((value) {
      if (!mounted || _holdVolume) return;
      setState(() => _volume = value);
    }));
    unawaited(_readLevels());
  }

  Future<void> _readLevels() async {
    try {
      final current = await _brightnessApi.system.timeout(
        const Duration(milliseconds: 800),
      );
      _brightness = current.clamp(0.0, 1.0);
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _setBrightness(double value) async {
    try {
      await _brightnessApi.setApplicationScreenBrightness(value.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> _resetBrightness() async {
    try {
      await _brightnessApi.resetApplicationScreenBrightness();
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_resetBrightness());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _scrubbing ? Duration(seconds: _scrubSec.round()) : _position;
    final totalSec = _duration.inMilliseconds / 1000;
    return Stack(
      fit: StackFit.expand,
      children: [
        const UiKitView(
          viewType: 'cineva/apple-view',
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{},
          creationParamsCodec: StandardMessageCodec(),
        ),
        if (_ready)
          PlaybackGestures(
            position: () => _position,
            duration: () => _duration,
            volume: () => _volume,
            brightness: () => _brightness,
            onSeek: (position) {
              _position = position;
              unawaited(widget.controller.seek(position));
            },
            onVolume: (value) {
              _holdVolume = true;
              _volume = value;
              unawaited(widget.controller.setVolume(value));
            },
            onVolumeEnd: () => _holdVolume = false,
            onBrightness: (value) {
              _brightness = value;
              unawaited(_setBrightness(value));
            },
            bottomReserve: 84,
            child: const SizedBox.expand(),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xE6000000)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_playing) {
                        unawaited(widget.controller.pause());
                      } else {
                        unawaited(widget.controller.play());
                      }
                    },
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    color: Colors.white,
                  ),
                  Text(
                    clockLabel(shown.inSeconds),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: CinevaColors.accent,
                        inactiveTrackColor: const Color(0x55FFFFFF),
                        thumbColor: CinevaColors.accent,
                        overlayShape: SliderComponentShape.noOverlay,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: totalSec <= 0
                            ? 0
                            : (shown.inMilliseconds / 1000).clamp(0, totalSec).toDouble(),
                        max: totalSec <= 0 ? 1 : totalSec,
                        onChanged: totalSec <= 0
                            ? null
                            : (value) {
                                setState(() {
                                  _scrubbing = true;
                                  _scrubSec = value;
                                });
                              },
                        onChangeEnd: (value) {
                          final target = Duration(milliseconds: (value * 1000).round());
                          setState(() {
                            _scrubbing = false;
                            _position = target;
                          });
                          unawaited(widget.controller.seek(target));
                        },
                      ),
                    ),
                  ),
                  Text(
                    clockLabel(_duration.inSeconds),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: UiKitView(
                      viewType: 'cineva/apple-route',
                      creationParamsCodec: StandardMessageCodec(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
