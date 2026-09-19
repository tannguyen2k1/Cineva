import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../utils/phone_orientation.dart';

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

  Timer? _saveTimer;
  Timer? _loadingTimeout;
  ApiClient? _api;
  bool _loggedIn = false;
  int _lastSavedSec = -1;

  static const _bootJs = r'''
(function(){
  try {
    var ld=document.getElementById('loading');
    if(ld) ld.classList.add('hide');
    var v=document.querySelector('video');
    if(v){ v.setAttribute('playsinline',''); v.play().catch(function(){}); }
    var btns=document.querySelectorAll('button,.jw-icon-playback');
    for(var i=0;i<btns.length;i++){
      if(/phát|play/i.test(btns[i].textContent||btns[i].ariaLabel||'')){
        btns[i].click(); break;
      }
    }
  } catch(e) {}
})();
''';

  String _safeAreaJs(double bottomPx) {
    final pad = bottomPx.ceil().clamp(0, 48);
    return '''
(function(){
  var pad=$pad;
  var css=document.getElementById('cineva-safe');
  if(!css){
    css=document.createElement('style');
    css.id='cineva-safe';
    (document.head||document.documentElement).appendChild(css);
  }
  css.textContent=[
    '.jw-controlbar,.jw-controls,.jw-controls-bottom,',
    '.jw-display-controls,.vjs-control-bar,video::-webkit-media-controls-panel{',
    'padding-bottom:'+pad+'px!important;',
    'box-sizing:border-box!important;}'
  ].join('');
})();
''';
  }

  Uri? get _embedUri {
    final embed = widget.embedUrl?.trim() ?? '';
    if (embed.isNotEmpty) return Uri.tryParse(embed);
    final play = widget.playUrl.trim();
    if (play.isEmpty) return null;
    if (play.contains('.m3u8')) {
      return Uri.parse(
        'https://player.phimapi.com/player/?url=${Uri.encodeComponent(play)}',
      );
    }
    return Uri.tryParse(play);
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
    WidgetsBinding.instance.addObserver(this);
    unawaited(PhoneOrientation.unlockForPlayer());
    _init();
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
      // Stay unlocked so the user can rotate back into landscape.
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

  Future<void> _init() async {
    _api = context.read<ApiClient>();
    _loggedIn = context.read<AuthState>().isLoggedIn;

    final uri = _embedUri;
    if (uri == null) {
      setState(() {
        _error = 'Không có link phát';
        _loading = false;
      });
      return;
    }

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
          },
          onPageFinished: (_) {
            _loadingTimeout?.cancel();
            if (!mounted) return;
            final bottom = MediaQuery.viewPaddingOf(context).bottom;
            final js = '$_bootJs${_safeAreaJs(bottom)}';
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
      setState(() => _web = controller);
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

  void _startProgressLoop() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
        '(function(){var v=document.querySelector("video");'
        'return v&&!isNaN(v.currentTime)?Math.floor(v.currentTime):0;})()',
      );
      var sec = 0;
      if (raw is num) {
        sec = raw.toInt();
      } else {
        sec = int.tryParse('$raw'.replaceAll('"', '')) ?? 0;
      }
      await _saveProgress(positionOverride: sec);
    } catch (_) {
      await _saveProgress();
    }
  }

  Future<void> _saveProgress({
    bool force = false,
    int? positionOverride,
  }) async {
    final episodeSlug = widget.episodeSlug;
    final api = _api;
    if (!_loggedIn ||
        api == null ||
        episodeSlug == null ||
        episodeSlug.isEmpty) {
      return;
    }
    final sec = positionOverride ?? widget.startPositionSec ?? 0;
    if (!force && (sec - _lastSavedSec).abs() < 5) return;
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
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _loadingTimeout?.cancel();
    _web = null;
    unawaited(_saveProgress(force: true));
    unawaited(PhoneOrientation.lockPortrait());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final web = _web;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final topMask =
        _cinema ? MediaQuery.paddingOf(context).top + 52 : 56.0;

    return PopScope(
      canPop: !_cinema,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _cinema) {
          unawaited(_exitCinema());
          return;
        }
        if (didPop) unawaited(_pollAndSave());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _cinema
            ? null
            : AppBar(
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
                padding: EdgeInsets.only(bottom: bottomInset),
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

          ],
        ),
      ),
    );
  }
}
