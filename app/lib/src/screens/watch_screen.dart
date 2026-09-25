import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../utils/phone_orientation.dart';
import 'watch/embed_scripts.dart';
import 'watch/episode_chrome.dart';
import 'watch/hls_source.dart';
import 'watch/native_video_view.dart';
import 'watch/resume_overlay.dart';

/// Phim thường phát HLS native. 18+ vẫn mở trang embed trong WebView.
/// Rotation unlocked on this screen; rest of app stays portrait-locked.
class WatchScreen extends StatefulWidget {
  const WatchScreen({
    super.key,
    required this.slug,
    required this.title,
    required this.playUrl,
    this.embedUrl,
    this.episodeSlug,
    this.episodeName,
    this.serverName,
    this.startPositionSec,
    this.posterUrl,
  });

  final String slug;
  final String title;
  final String playUrl;
  final String? embedUrl;
  final String? episodeSlug;
  final String? episodeName;
  final String? serverName;
  final int? startPositionSec;
  final String? posterUrl;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver {
  WebViewController? _web;
  Player? _player;
  VideoController? _video;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _doneSub;
  StreamSubscription<String>? _errSub;
  String? _hlsUrl;
  bool _askResume = false;
  Timer? _resumeTimer;
  int _resumeLeft = 0;
  Duration _position = Duration.zero;
  Duration _mediaDuration = Duration.zero;
  String? _error;
  bool _loading = true;
  bool _cinema = false;
  bool _ended = false;
  bool _nearEnd = false;
  Timer? _autoNextTimer;
  int _autoNextSec = 0;

  Timer? _saveTimer;
  Timer? _loadingTimeout;
  ApiClient? _api;
  bool _loggedIn = false;
  int _lastSavedSec = -1;
  int _currentStartSec = 0;

  late String _playUrl;
  late String? _embedUrl;
  late String? _episodeSlug;
  late String? _episodeName;
  late String? _serverName;

  List<EpisodeServer> _servers = const [];
  EpisodeItem? _nextEpisode;
  String? _nextServerName;

  bool get _useNative => _hlsUrl != null;

  void _bindNative(Player player) {
    _posSub = player.stream.position.listen((pos) {
      _position = pos;
      _notePlayback();
    });
    _durSub = player.stream.duration.listen((dur) {
      _mediaDuration = dur;
      if (dur > Duration.zero && _loading && mounted && !_askResume) {
        setState(() => _loading = false);
      }
    });
    _doneSub = player.stream.completed.listen((done) {
      if (!done || !mounted || _askResume || _ended) return;
      setState(() => _ended = true);
      if (_nextEpisode != null) _startAutoNextCountdown();
    });
    _errSub = player.stream.error.listen((msg) {
      if (!mounted || msg.isEmpty || _mediaDuration > Duration.zero) return;
      setState(() {
        _error = 'Không phát được phim';
        _loading = false;
      });
    });
  }

  void _notePlayback() {
    if (!mounted || _askResume) return;
    final d = _mediaDuration.inSeconds;
    if (d <= 0) return;
    final t = _position.inSeconds;
    final near = (d > 60 && (d - t) <= 142) || (t / d >= 0.92);
    if (near == _nearEnd) return;
    setState(() => _nearEnd = near);
  }

  void _cancelResumeTimer() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _resumeLeft = 0;
  }

  void _startResumeCountdown() {
    _cancelResumeTimer();
    _resumeLeft = 8;
    _resumeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resumeLeft <= 1) {
        t.cancel();
        _resumeTimer = null;
        unawaited(_confirmResume(continueWatching: true));
        return;
      }
      setState(() => _resumeLeft -= 1);
    });
  }

  Future<void> _seekWhenReady(int sec) async {
    if (sec <= 0) return;
    final player = _player;
    if (player == null) return;
    for (var i = 0; i < 20; i++) {
      if (_mediaDuration > Duration.zero) break;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    await player.seek(Duration(seconds: sec));
  }

  Future<void> _confirmResume({required bool continueWatching}) async {
    _cancelResumeTimer();
    final sec = continueWatching ? _currentStartSec : 0;
    if (mounted) setState(() => _askResume = false);
    final player = _player;
    if (player == null) return;
    if (sec > 0) await _seekWhenReady(sec);
    await player.play();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openNative(String url, {required int resumeSec}) async {
    final player = _player;
    if (player == null) return;
    final ask = resumeSec >= resumeAskSec;
    _position = Duration.zero;
    _mediaDuration = Duration.zero;
    _cancelResumeTimer();
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _ended = false;
        _nearEnd = false;
        _askResume = ask;
        _resumeLeft = ask ? 8 : 0;
      });
    }
    await player.open(
      Media(url, httpHeaders: hlsHeaders),
      play: !ask,
    );
    _loadingTimeout?.cancel();
    if (!ask) {
      _loadingTimeout = Timer(const Duration(seconds: 14), () {
        if (mounted && _loading) setState(() => _loading = false);
      });
    }
    if (ask) {
      await player.pause();
      if (mounted) _startResumeCountdown();
      return;
    }
    if (resumeSec > 0) await _seekWhenReady(resumeSec);
  }

  Future<void> _initNative() async {
    final url = _hlsUrl;
    if (url == null) return;
    _player ??= Player();
    _video ??= VideoController(_player!);
    if (_posSub == null) _bindNative(_player!);
    try {
      await _openNative(url, resumeSec: _currentStartSec);
      _startProgressLoop();
      unawaited(_saveProgress(force: true));
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không mở được trình phát';
          _loading = false;
        });
      }
    }
  }

  void _resolveNext() {
    EpisodeItem? next;
    String? nextServer;
    for (final server in _servers) {
      for (var i = 0; i < server.items.length; i++) {
        if (server.items[i].slug == _episodeSlug && i + 1 < server.items.length) {
          next = server.items[i + 1];
          nextServer = server.serverName;
          break;
        }
      }
    }
    _nextEpisode = next;
    _nextServerName = nextServer;
  }

  Future<void> _loadEpisodeCatalog() async {
    final api = _api;
    if (api == null) return;
    try {
      final detail = await api.filmDetail(widget.slug);
      if (!mounted) return;
      setState(() {
        _servers = detail.episodes;
        _resolveNext();
      });
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _loggedIn = context.read<AuthState>().isLoggedIn;
  }

  @override
  void initState() {
    super.initState();
    _playUrl = widget.playUrl;
    _embedUrl = widget.embedUrl;
    _episodeSlug = widget.episodeSlug;
    _episodeName = widget.episodeName;
    _serverName = widget.serverName;
    _currentStartSec = widget.startPositionSec ?? 0;
    WidgetsBinding.instance.addObserver(this);
    unawaited(PhoneOrientation.unlockForPlayer());
    // context / WebView are not ready inside initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initPlayer());
      unawaited(_loadEpisodeCatalog());
    });
  }

  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize;
    final isLandscape = size.width > size.height;
    if (isLandscape && !_cinema) {
      setState(() => _cinema = true);
      unawaited(PhoneOrientation.enterImmersive());
    } else if (!isLandscape && _cinema) {
      setState(() => _cinema = false);
      unawaited(PhoneOrientation.exitImmersive());
    }
  }

  Future<void> _exitCinema() async {
    if (!_cinema) return;
    setState(() => _cinema = false);
    await PhoneOrientation.exitImmersive();
    await PhoneOrientation.snapToPortraitThenUnlock();
  }

  PlatformWebViewControllerCreationParams _platformParams() {
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      return WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }
    return const PlatformWebViewControllerCreationParams();
  }

  Future<void> _configurePlatform(WebViewController controller) async {
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<void> _initPlayer() async {
    _api ??= context.read<ApiClient>();
    _loggedIn = context.read<AuthState>().isLoggedIn;

    _hlsUrl = directHls(_playUrl, _embedUrl);
    if (_useNative) {
      await _initNative();
      return;
    }

    final uri = embedUri(playUrl: _playUrl, embedUrl: _embedUrl);
    if (uri == null) {
      setState(() {
        _error = 'Không có link phát';
        _loading = false;
      });
      return;
    }

    // Determine the raw video URL for localStorage seeding
    WakelockPlus.enable();
    final rawVideoUrl = _playUrl.trim();

    final controller = WebViewController.fromPlatformCreationParams(
      _platformParams(),
    );
    await _configurePlatform(controller);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
            // Pre-seed localStorage BEFORE PhimAPI's JS reads it
            if (_currentStartSec > 0 && rawVideoUrl.isNotEmpty) {
              unawaited((() async {
                try {
                  await controller.runJavaScript(
                    seedLocalStorageJs(rawVideoUrl, _currentStartSec),
                  );
                } catch (_) {}
              })());
            }
          },
          onPageFinished: (_) {
            _loadingTimeout?.cancel();
            if (!mounted) return;
            final bottom = MediaQuery.viewPaddingOf(context).bottom +
                (_nextEpisode != null ? 56.0 : 0);
            final js = '${bootJs(_currentStartSec)}${safeAreaJs(bottom)}';
            unawaited((() async {
              try {
                if (!mounted) return;
                await controller.runJavaScript(js);
              } catch (_) {}
            })());
            setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            if (err.isForMainFrame != true) return;
            setState(() {
              _error = 'Không tải được trình phát';
              _loading = false;
            });
          },
        ),
      );

    try {
      setState(() {
        _web = controller;
        _error = null;
        _ended = false;
      });
      _loadingTimeout = Timer(const Duration(seconds: 14), () {
        if (mounted && _loading) setState(() => _loading = false);
      });
      await controller.loadRequest(uri);
      _startProgressLoop();
      unawaited(_saveProgress(force: true));
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không mở được trình phát';
          _loading = false;
        });
      }
    }
  }

  Future<void> _playNext() async {
    final next = _nextEpisode;
    if (next == null) return;
    _cancelAutoNext();
    await _saveProgress(force: true);
    setState(() {
      _playUrl = next.playUrl;
      _embedUrl = next.embed;
      _episodeSlug = next.slug;
      _episodeName = next.name;
      _serverName = _nextServerName ?? _serverName;
      _lastSavedSec = -1;
      _currentStartSec = 0;
      _ended = false;
      _nearEnd = false;
      _loading = true;
      _resolveNext();
    });

    _hlsUrl = directHls(_playUrl, _embedUrl);
    if (_useNative) {
      final url = _hlsUrl;
      if (url == null) return;
      try {
        await _openNative(url, resumeSec: 0);
        unawaited(_saveProgress(force: true, positionOverride: 0));
      } catch (_) {
        if (mounted) {
          setState(() {
            _error = 'Không mở được tập tiếp theo';
            _loading = false;
          });
        }
      }
      return;
    }

    final web = _web;
    final uri = embedUri(playUrl: _playUrl, embedUrl: _embedUrl);
    if (web == null || uri == null) {
      await _initPlayer();
      return;
    }
    try {
      await web.loadRequest(uri);
      unawaited(_saveProgress(force: true, positionOverride: 0));
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không mở được tập tiếp theo';
          _loading = false;
        });
      }
    }
  }

  void _cancelAutoNext() {
    _autoNextTimer?.cancel();
    _autoNextTimer = null;
    _autoNextSec = 0;
  }

  void _startAutoNextCountdown() {
    if (_nextEpisode == null || _autoNextTimer != null) return;
    setState(() => _autoNextSec = 5);
    _autoNextTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_autoNextSec <= 1) {
        t.cancel();
        _autoNextTimer = null;
        unawaited(_playNext());
        return;
      }
      setState(() => _autoNextSec -= 1);
    });
  }

  void _startProgressLoop() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollAndSave());
    });
  }

  Future<void> _pollAndSave() async {
    if (_useNative) {
      if (_askResume) return;
      await _saveProgress(positionOverride: _position.inSeconds);
      return;
    }
    final web = _web;
    if (web == null || !mounted) {
      await _saveProgress();
      return;
    }
    try {
      final raw = await web.runJavaScriptReturningResult(
        '(function(){'
        'var t=0,d=0,ended=0,near=0,err="";'
        'try {'
        '  if(window.jwplayer && typeof window.jwplayer==="function" && jwplayer() && typeof jwplayer().getPosition==="function") {'
        '    var p=jwplayer();'
        '    t=p.getPosition()||0;'
        '    d=p.getDuration()||0;'
        '    var state=p.getState();'
        '    ended=(state==="complete"||(d>0&&t/d>=0.985))?1:0;'
        '    near=((d>60&&(d-t)<=142)||(d>0&&t/d>=0.92))?1:0;'
        '  } else {'
        '    var v=document.querySelector("video");'
        '    if(v) {'
        '      t=v.currentTime||0;'
        '      d=isFinite(v.duration)?v.duration:0;'
        '      ended=(v.ended||(d>0&&t/d>=0.985))?1:0;'
        '      near=((d>60&&(d-t)<=142)||(d>0&&t/d>=0.92))?1:0;'
        '    } else { err="no_video_tag"; }'
        '  }'
        '} catch(e) { err=e.toString(); }'
        'return JSON.stringify({t:Math.floor(t),d:Math.floor(d),e:ended,n:near,err:err});'
        '})()',
      );
      var src = '$raw';
      if (src.startsWith('"') && src.endsWith('"')) {
        try {
          src = jsonDecode(src);
        } catch (_) {}
      }
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(src);
      } catch (_) {}

      final sec = (data['t'] as num?)?.toInt() ?? 0;
      final ended = (data['e'] as num?)?.toInt() == 1;
      final near = (data['n'] as num?)?.toInt() == 1;
      final hasNext = _nextEpisode != null;

      if (!mounted) return;
      var changed = false;
      if (near != _nearEnd) {
        _nearEnd = near;
        changed = true;
      }
      if (ended && !_ended) {
        _ended = true;
        changed = true;
        if (hasNext) _startAutoNextCountdown();
      } else if (!ended && _ended) {
        _ended = false;
        _cancelAutoNext();
        changed = true;
      }
      if (changed) setState(() {});
      await _saveProgress(positionOverride: sec);
    } catch (_) {
      await _saveProgress();
    }
  }

  Future<void> _saveProgress({
    bool force = false,
    int? positionOverride,
  }) async {
    final episodeSlug = _episodeSlug;
    final api = _api;
    if (!_loggedIn ||
        api == null ||
        episodeSlug == null ||
        episodeSlug.isEmpty) {
      return;
    }
    final sec = positionOverride ?? (_lastSavedSec > 0 ? _lastSavedSec : (widget.startPositionSec ?? 0));
    if (!force && (sec - _lastSavedSec).abs() < 5) return;
    _lastSavedSec = sec;
    try {
      await api.saveProgress(
        slug: widget.slug,
        episodeSlug: episodeSlug,
        episodeName: _episodeName,
        serverName: _serverName,
        positionSec: sec,
      );
    } catch (_) {}
  }


  bool _stopping = false;

  Future<void> _stopPlayer() async {
    if (_stopping) return;
    _stopping = true;
    _cancelResumeTimer();
    if (_useNative) {
      try {
        await _player?.pause();
      } catch (_) {}
      return;
    }
    final web = _web;
    if (web != null) {
      try {
        await web.runJavaScript(stopPlaybackJs);
      } catch (_) {}
      try {
        await web.loadRequest(Uri.parse('about:blank'));
      } catch (_) {}
    }
    _web = null;
    if (mounted) setState(() {});
  }

  Future<void> _leaveWatch() async {
    _cancelAutoNext();
    await _pollAndSave();
    await _stopPlayer();
    await PhoneOrientation.lockPortrait();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _saveTimer?.cancel();
    _loadingTimeout?.cancel();
    _cancelAutoNext();
    _cancelResumeTimer();
    _posSub?.cancel();
    _durSub?.cancel();
    _doneSub?.cancel();
    _errSub?.cancel();
    final player = _player;
    _player = null;
    _video = null;
    if (player != null) unawaited(player.dispose());
    _web = null;
    unawaited(_saveProgress(force: true));
    unawaited(PhoneOrientation.lockPortrait());
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final web = _web;
    final video = _video;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final topMask =
        _cinema ? MediaQuery.paddingOf(context).top + 52 : 56.0;
    final hasNext = _nextEpisode != null;
    // Netflix-style: only surface next near the end / after finish.
    final showNearEndChip = hasNext && _nearEnd && !_ended;
    final showEndedOverlay = hasNext && _ended;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_cinema) {
          unawaited(_exitCinema());
          return;
        }
        unawaited(_leaveWatch());
      },
      child: Scaffold(
          backgroundColor: Colors.black,
          appBar: _cinema
              ? null
              : AppBar(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => unawaited(_leaveWatch()),
                  ),
                  title: Text(
                    [
                      widget.title,
                      if (_episodeName != null) _episodeName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: CinevaColors.muted),
                    ),
                  ),
                )
              else if (_useNative && video != null)
                NativeVideoView(
                  controller: video,
                  bottomPadding: bottomInset + (showNearEndChip ? 58 : 0),
                  hideBuffering: _askResume,
                )
              else if (web != null)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomInset + (showNearEndChip ? 58 : 0),
                  ),
                  child: WebViewWidget(controller: web),
                )
              else
                const SizedBox.shrink(),
              if (!_useNative && web != null && _error == null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topMask,
                  child: const IgnorePointer(
                    child: ColoredBox(color: Colors.black),
                  ),
                ),
              if (_loading && _error == null && !_askResume)
                const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: CinevaColors.accent),
                  ),
                ),
              if (_askResume && _error == null) ...[
                const Positioned.fill(child: ColoredBox(color: Colors.black)),
                Positioned.fill(
                  child: ResumeBackdrop(posterUrl: widget.posterUrl),
                ),
                Positioned.fill(
                  child: ResumeOverlay(
                    title: widget.title,
                    episodeName: _episodeName,
                    positionSec: _currentStartSec,
                    secondsLeft: _resumeLeft,
                    onContinue: () =>
                        unawaited(_confirmResume(continueWatching: true)),
                    onRestart: () =>
                        unawaited(_confirmResume(continueWatching: false)),
                  ),
                ),
              ],
              if (showNearEndChip)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: bottomInset + 10,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: NextEpisodeBar(
                      label: episodeLabel(_nextEpisode!),
                      prominent: false,
                      onTap: () {
                        _cancelAutoNext();
                        unawaited(_playNext());
                      },
                    ),
                  ),
                ),
              if (showEndedOverlay)
                Positioned.fill(
                  child: EndedEpisodeOverlay(
                    countdownSec: _autoNextSec,
                    label: episodeLabel(_nextEpisode!),
                    onPlayNext: () {
                      _cancelAutoNext();
                      unawaited(_playNext());
                    },
                    onCancel: () {
                      _cancelAutoNext();
                      setState(() {
                        _ended = false;
                        _nearEnd = false;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
    );
  }
}
