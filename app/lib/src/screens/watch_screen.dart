import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({
    super.key,
    required this.slug,
    required this.title,
    required this.playUrl,
    this.episodeSlug,
    this.episodeName,
    this.serverName,
    this.startPositionSec,
  });

  final String slug;
  final String title;
  final String playUrl;
  final String? episodeSlug;
  final String? episodeName;
  final String? serverName;
  final int? startPositionSec;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  VideoPlayerController? _controller;
  String? _error;
  Timer? _saveTimer;
  ApiClient? _api;
  bool _loggedIn = false;
  int _lastSavedSec = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _loggedIn = context.read<AuthState>().isLoggedIn;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _api = context.read<ApiClient>();
    _loggedIn = context.read<AuthState>().isLoggedIn;
    final url = widget.playUrl.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Không có link phát');
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      final start = await _resolveStartPosition();
      if (start != null && start > 5) {
        final maxSeek = controller.value.duration.inSeconds - 10;
        if (maxSeek > 5 && start < maxSeek) {
          await controller.seekTo(Duration(seconds: start));
        }
      }
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      _startProgressLoop();
      unawaited(_saveProgress(force: true));
    } catch (e) {
      await controller.dispose();
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<int?> _resolveStartPosition() async {
    if (widget.startPositionSec != null) return widget.startPositionSec;
    final episodeSlug = widget.episodeSlug;
    if (!_loggedIn || episodeSlug == null || episodeSlug.isEmpty) return null;
    final api = _api ?? context.read<ApiClient>();
    try {
      final items = await api.listContinue();
      for (final item in items) {
        if (item.slug == widget.slug && item.episodeSlug == episodeSlug) {
          return item.positionSec;
        }
      }
    } catch (_) {}
    return null;
  }

  void _startProgressLoop() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_saveProgress());
    });
  }

  Future<void> _saveProgress({bool force = false}) async {
    final episodeSlug = widget.episodeSlug;
    final c = _controller;
    final api = _api;
    if (!_loggedIn ||
        api == null ||
        episodeSlug == null ||
        episodeSlug.isEmpty ||
        c == null ||
        !c.value.isInitialized) {
      return;
    }
    final sec = c.value.position.inSeconds;
    if (!force && (sec < 3 || (sec - _lastSavedSec).abs() < 5)) return;
    _lastSavedSec = sec;
    try {
      await api.saveProgress(
        slug: widget.slug,
        episodeSlug: episodeSlug,
        episodeName: widget.episodeName,
        serverName: widget.serverName,
        positionSec: sec,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    final c = _controller;
    final api = _api;
    final episodeSlug = widget.episodeSlug;
    if (_loggedIn &&
        api != null &&
        episodeSlug != null &&
        episodeSlug.isNotEmpty &&
        c != null &&
        c.value.isInitialized) {
      final sec = c.value.position.inSeconds;
      unawaited(
        api.saveProgress(
          slug: widget.slug,
          episodeSlug: episodeSlug,
          episodeName: widget.episodeName,
          serverName: widget.serverName,
          positionSec: sec,
        ),
      );
    }
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_saveProgress(force: true));
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
            [
              widget.title,
              if (widget.episodeName != null) widget.episodeName,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFA1A1AA)),
                  ),
                )
              : c == null || !c.value.isInitialized
              ? const CircularProgressIndicator(color: Color(0xFFFFD66B))
              : AspectRatio(
                  aspectRatio: c.value.aspectRatio == 0
                      ? 16 / 9
                      : c.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      VideoPlayer(c),
                      _Controls(
                        controller: c,
                        onPause: () => unawaited(_saveProgress(force: true)),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.onPause});

  final VideoPlayerController controller;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final playing = controller.value.isPlaying;
        final pos = controller.value.position;
        final dur = controller.value.duration;
        return ColoredBox(
          color: Colors.black45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                colors: const VideoProgressColors(
                  playedColor: Color(0xFFFFD66B),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (playing) {
                        controller.pause();
                        onPause();
                      } else {
                        controller.play();
                      }
                    },
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    color: Colors.white,
                  ),
                  Text(
                    '${_fmt(pos)} / ${_fmt(dur)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
