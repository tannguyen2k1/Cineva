import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'screens/admin_banners_screen.dart';
import 'screens/admin_comments_screen.dart';
import 'screens/admin_featured_screen.dart';
import 'screens/admin_films_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/admin_logs_screen.dart';
import 'screens/admin_modules_screen.dart';
import 'screens/admin_roles_screen.dart';
import 'screens/admin_sync_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/film_detail_screen.dart';
import 'screens/home_screen.dart';
import 'models/topxx_models.dart';
import 'screens/adult_film_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/watch_screen.dart';
import 'state/auth_state.dart';
import 'services/api_client.dart';
import 'utils/cineva_page.dart';

const _publicExact = {'/', '/login', '/register'};
const _publicPrefixes = ['/phim', '/phim-18', '/xem'];

bool _isPublicPath(String path) {
  if (_publicExact.contains(path)) return true;
  return _publicPrefixes.any((p) => path == p || path.startsWith('$p/'));
}

bool _isAdminPath(String path) =>
    path == '/admin' || path.startsWith('/admin/');

class TrafficObserver extends NavigatorObserver {
  TrafficObserver(this.api);
  final ApiClient api;

  void _record(Route<dynamic>? route) {
    if (route != null && route.settings.name != null) {
      api.recordTrafficHit(route.settings.name!);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _record(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _record(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _record(previousRoute);
  }
}

GoRouter createRouter(AuthState auth, ApiClient api) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    observers: [TrafficObserver(api)],
    redirect: (context, state) {
      if (auth.booting) return null;
      final path = state.matchedLocation;
      final onAuthGate = path == '/login' || path == '/register';
      if (!auth.isLoggedIn && !_isPublicPath(path)) return '/login';
      if (auth.isLoggedIn && onAuthGate) return '/';
      if (_isAdminPath(path) && !auth.isAdmin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const RegisterScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const HomeScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminHomeScreen()),
      ),
      GoRoute(
        path: '/admin/modules',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminModulesScreen()),
      ),
      GoRoute(
        path: '/admin/films',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminFilmsScreen()),
      ),
      GoRoute(
        path: '/admin/sync',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminSyncScreen()),
      ),
      GoRoute(
        path: '/admin/banners',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminBannersScreen()),
      ),
      GoRoute(
        path: '/admin/featured',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminFeaturedScreen()),
      ),
      GoRoute(
        path: '/admin/comments',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminCommentsScreen()),
      ),
      GoRoute(
        path: '/admin/users',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminUsersScreen()),
      ),
      GoRoute(
        path: '/admin/roles',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminRolesScreen()),
      ),
      GoRoute(
        path: '/admin/logs',
        pageBuilder: (context, state) =>
            cinevaPage(state: state, child: const AdminLogsScreen()),
      ),
      GoRoute(
        path: '/phim-18/:code',
        pageBuilder: (context, state) => cinevaPage(
          state: state,
          child: AdultFilmDetailScreen(
            code: state.pathParameters['code']!,
            initialMovie:
                state.extra is TopxxMovie ? state.extra as TopxxMovie : null,
          ),
        ),
      ),
      GoRoute(
        path: '/phim/:slug',
        pageBuilder: (context, state) => cinevaPage(
          state: state,
          child: FilmDetailScreen(slug: state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: '/xem/:slug',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final map = extra is Map
              ? Map<String, dynamic>.from(extra)
              : <String, dynamic>{};
          return cinevaPage(
            state: state,
            child: WatchScreen(
              slug: state.pathParameters['slug']!,
              title: map['title']?.toString() ?? state.pathParameters['slug']!,
              playUrl: map['playUrl']?.toString() ?? '',
              embedUrl: map['embedUrl']?.toString(),
              episodeSlug: map['episodeSlug']?.toString(),
              episodeName: map['episodeName']?.toString(),
              serverName: map['serverName']?.toString(),
              startPositionSec: (map['positionSec'] is num)
                  ? (map['positionSec'] as num).toInt()
                  : int.tryParse('${map['positionSec'] ?? ''}'),
            ),
          );
        },
      ),
    ],
  );
}
