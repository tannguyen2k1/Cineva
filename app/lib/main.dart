import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app_router.dart';
import 'src/services/api_client.dart';
import 'src/state/auth_state.dart';
import 'src/theme/cineva_theme.dart';

import 'src/services/topxx_client.dart';
import 'src/state/app_mode_state.dart';
import 'src/widgets/cineva_brand_mark.dart';

/// Material tablet breakpoint (shortest side).
const _tabletShortestSide = 600.0;

/// Phone-only: iPad (Stage Manager / multitasking) rejects programmatic
/// orientation changes with UISceneErrorDomain Code=101.
Future<void> _lockPhonePortrait() async {
  try {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  } catch (_) {
    // Ignore — unsupported in current iPad windowing mode.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize desktop window manager if supported
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Color(0xFF09090B),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Cineva',
    );
    // Keep window hidden until Flutter renders the first frame → no white flash.
    await windowManager.waitUntilReadyToShow(windowOptions);
  }

  final api = ApiClient();
  final auth = AuthState(api);
  final appMode = AppModeState();
  final topxx = TopxxClient();
  await auth.bootstrap();
  runApp(CinevaApp(api: api, auth: auth, appMode: appMode, topxx: topxx));
}

class CinevaApp extends StatefulWidget {
  const CinevaApp({
    super.key,
    required this.api,
    required this.auth,
    required this.appMode,
    required this.topxx,
  });

  final ApiClient api;
  final AuthState auth;
  final AppModeState appMode;
  final TopxxClient topxx;

  @override
  State<CinevaApp> createState() => _CinevaAppState();
}

class _CinevaAppState extends State<CinevaApp> {
  late final GoRouter _router = createRouter(widget.auth, widget.api);

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.api),
        ChangeNotifierProvider.value(value: widget.auth),
        ChangeNotifierProvider.value(value: widget.appMode),
        Provider.value(value: widget.topxx),
      ],
      child: MaterialApp.router(
        title: 'Cineva',
        debugShowCheckedModeBanner: false,
        theme: buildCinevaTheme(),
        routerConfig: _router,
        builder: (context, child) {
          return _OrientationBinder(
            child: _PrivacyShield(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

/// Banking-style privacy blur overlay when app is inactive or in multitasking switcher.
class _PrivacyShield extends StatefulWidget {
  const _PrivacyShield({required this.child});
  final Widget child;

  @override
  State<_PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<_PrivacyShield>
    with WidgetsBindingObserver {
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isInactive = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (isInactive != _isBackgrounded) {
      setState(() => _isBackgrounded = isInactive);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeState?>();
    final is18Plus = appMode?.is18Plus == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Chỉ kích hoạt màn che bảo mật khi đang ở chế độ 18+
        if (_isBackgrounded && is18Plus)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  color: const Color(0xFF09090B).withValues(alpha: 0.85),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CinevaColors.accent.withValues(alpha: 0.22),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const CinevaBrandMark(
                          size: 56,
                          is18Plus: false,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'C I N E V A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4.5,
                          decoration: TextDecoration.none,
                          fontFamily: 'BeVietnamPro',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Locks portrait on phones only. Tablets keep Info.plist orientations.
class _OrientationBinder extends StatefulWidget {
  const _OrientationBinder({required this.child});

  final Widget child;

  @override
  State<_OrientationBinder> createState() => _OrientationBinderState();
}

class _OrientationBinderState extends State<_OrientationBinder> {
  bool? _isTablet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final isTablet = shortest >= _tabletShortestSide;
    if (_isTablet == isTablet) return;
    _isTablet = isTablet;
    // Do not call setPreferredOrientations on iPad — UIScene rejects it.
    if (!isTablet) {
      _lockPhonePortrait();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
