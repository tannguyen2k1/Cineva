import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'src/app_router.dart';
import 'src/services/api_client.dart';
import 'src/state/auth_state.dart';
import 'src/theme/cineva_theme.dart';

import 'src/services/topxx_client.dart';
import 'src/state/app_mode_state.dart';

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
  late final GoRouter _router = createRouter(widget.auth);

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
          return _OrientationBinder(child: child ?? const SizedBox.shrink());
        },
      ),
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
