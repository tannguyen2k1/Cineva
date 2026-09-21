import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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
import '../widgets/left_edge_swipe_back.dart';

/// Watch via JW / phimapi embed in a WebView.
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
  });

  final String slug;
  final String title;
  final String playUrl;
  final String? embedUrl;
  final String? episodeSlug;
  final String? episodeName;
  final String? serverName;
  final int? startPositionSec;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver {
  WebViewController? _web;
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

  /// JS to pre-seed PhimAPI localStorage so the native resume modal appears.
  /// Key format: `rz_${btoa(unescape(encodeURIComponent(url)))}_progress`
  String _seedLocalStorageJs(String videoUrl, int startSec) {
    if (startSec <= 0) return '';
    return '''
(function(){
  try {
    var key = 'rz_' + btoa(unescape(encodeURIComponent('$videoUrl'))) + '_progress';
    localStorage.setItem(key, '$startSec');
  } catch(e){}
})();
''';
  }

  String _bootJs(int startSec) {
    return '''
(function(){
  try {
    var ld=document.getElementById('loading');
    if(ld) ld.classList.add('hide');
    var v=document.querySelector('video');
    if(v){ v.setAttribute('playsinline',''); }

    var start = $startSec;

    if (start > 0) {
      // After user clicks play / resume, verify seek position is correct
      var hasSeeked = false;
      var checkIntv = setInterval(function(){
        if (hasSeeked) { clearInterval(checkIntv); return; }
        try {
          if (window.jwplayer && typeof jwplayer === 'function') {
            var p = jwplayer();
            if (p && p.getPosition && p.getDuration && p.getDuration() > 0) {
              if (Math.abs(p.getPosition() - start) < 3) {
                hasSeeked = true;
              } else if (p.getPosition() > 1) {
                p.seek(start);
                hasSeeked = true;
              }
            }
          } else {
            var vid = document.querySelector('video');
            if (vid && vid.duration > 0 && vid.currentTime > 0.5) {
              if (Math.abs(vid.currentTime - start) > 3) {
                vid.currentTime = start;
              }
              hasSeeked = true;
            }
          }
        } catch(e){}
      }, 500);
      setTimeout(function(){ clearInterval(checkIntv); }, 15000);
    }
  } catch(e){}
})();
''';
  }

  String _safeAreaJs(double bottomPx) {
    final pad = bottomPx.ceil().clamp(0, 72);
    return '''
(function(){
  try {
    var c=document.querySelector('.jw-wrapper,.jwplayer,video');
    if(c) c.style.paddingBottom='${pad}px';
  } catch(e){}
})();
''';
  }

  Uri? _uriFor({required String playUrl, String? embedUrl}) {
    final embed = embedUrl?.trim() ?? '';
    if (embed.isNotEmpty) return Uri.tryParse(embed);
    final play = playUrl.trim();
    if (play.isEmpty) return null;
    if (play.contains('.m3u8')) {
      return Uri.parse(
        'https://player.phimapi.com/player/?url=${Uri.encodeComponent(play)}',
      );
    }
    return Uri.tryParse(play);
  }

  String _epLabel(EpisodeItem ep) {
    final raw = ep.name.trim();
    if (raw.isEmpty) return 'tập tiếp';
    if (RegExp(r'^\d+$').hasMatch(raw)) return 'Tập $raw';
    return raw;
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
    WakelockPlus.enable();
    _playUrl = widget.playUrl;
    _embedUrl = widget.embedUrl;
    _episodeSlug = widget.episodeSlug;
    _episodeName = widget.episodeName;
    _serverName = widget.serverName;
    _currentStartSec = widget.startPositionSec ?? 0;
    WidgetsBinding.instance.addObserver(this);
    unawaited(PhoneOrientation.unlockForPlayer());
    _initPlayer();
    unawaited(_loadEpisodeCatalog());
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
    _api = context.read<ApiClient>();
    _loggedIn = context.read<AuthState>().isLoggedIn;

    final uri = _uriFor(playUrl: _playUrl, embedUrl: _embedUrl);
    if (uri == null) {
      setState(() {
        _error = 'Không có link phát';
        _loading = false;
      });
      return;
    }

    // Determine the raw video URL for localStorage seeding
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
                    _seedLocalStorageJs(rawVideoUrl, _currentStartSec),
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
            final js = '${_bootJs(_currentStartSec)}${_safeAreaJs(bottom)}';
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

    final web = _web;
    final uri = _uriFor(playUrl: _playUrl, embedUrl: _embedUrl);
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

  static const _stopPlaybackJs = r'''
(function(){
  try {
    document.querySelectorAll('video,audio').forEach(function(m){
      try {
        m.pause();
        m.muted = true;
        m.removeAttribute('src');
        while (m.firstChild) m.removeChild(m.firstChild);
        m.load();
      } catch (e) {}
    });
    try {
      if (window.jwplayer) {
        var p = jwplayer();
        if (p) {
          if (p.pause) p.pause(true);
          if (p.stop) p.stop();
          if (p.remove) p.remove();
        }
      }
    } catch (e) {}
  } catch (e) {}
})();
''';

  bool _stopping = false;

  Future<void> _stopPlayer() async {
    if (_stopping) return;
    _stopping = true;
    final web = _web;
    if (web != null) {
      try {
        await web.runJavaScript(_stopPlaybackJs);
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
    _web = null;
    unawaited(_saveProgress(force: true));
    unawaited(PhoneOrientation.lockPortrait());
    super.dispose();
  }

  Widget _nextBar({required bool prominent}) {
    final next = _nextEpisode;
    if (next == null) return const SizedBox.shrink();
    final label = _epLabel(next);
    final countdown =
        prominent && _autoNextSec > 0 ? ' (${_autoNextSec}s)' : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _cancelAutoNext();
          unawaited(_playNext());
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: prominent
                ? CinevaColors.accent
                : Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(12),
            border: prominent
                ? null
                : Border.all(
                    color: CinevaColors.accent.withValues(alpha: 0.55),
                  ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: prominent ? 18 : 14,
            vertical: prominent ? 14 : 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.skip_next_rounded,
                color: prominent ? CinevaColors.onAccent : CinevaColors.accent,
                size: prominent ? 26 : 22,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  prominent
                      ? 'Tập tiếp theo · $label$countdown'
                      : 'Tập tiếp · $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        prominent ? CinevaColors.onAccent : CinevaColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: prominent ? 15 : 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final web = _web;
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
      child: LeftEdgeSwipeBack(
        onBack: () {
          if (_cinema) {
            unawaited(_exitCinema());
          } else {
            unawaited(_leaveWatch());
          }
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
              else if (web != null)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomInset + (showNearEndChip ? 58 : 0),
                  ),
                  child: WebViewWidget(controller: web),
                )
              else
                const SizedBox.shrink(),
              if (web != null && _error == null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topMask,
                  child: const IgnorePointer(
                    child: ColoredBox(color: Colors.black),
                  ),
                ),
              if (_loading && _error == null)
                const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: CinevaColors.accent),
                  ),
                ),

              if (showNearEndChip)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: bottomInset + 10,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _nextBar(prominent: false),
                  ),
                ),
              if (showEndedOverlay)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.78),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Hết tập',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _autoNextSec > 0
                                  ? 'Tự phát tập tiếp sau $_autoNextSec giây'
                                  : 'Sẵn sàng xem tập tiếp theo',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: CinevaColors.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _nextBar(prominent: true),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                _cancelAutoNext();
                                setState(() {
                                  _ended = false;
                                  _nearEnd = false;
                                });
                              },
                              child: const Text(
                                'Hủy',
                                style: TextStyle(color: CinevaColors.muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
