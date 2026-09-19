import 'package:go_router/go_router.dart';

import 'screens/admin_banners_screen.dart';
import 'screens/admin_comments_screen.dart';
import 'screens/admin_featured_screen.dart';
import 'screens/admin_films_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/admin_logs_screen.dart';
import 'screens/admin_roles_screen.dart';
import 'screens/admin_sync_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/film_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/watch_screen.dart';
import 'state/auth_state.dart';

const _publicExact = {'/', '/login', '/register'};
const _publicPrefixes = ['/phim', '/xem'];

bool _isPublicPath(String path) {
  if (_publicExact.contains(path)) return true;
  return _publicPrefixes.any((p) => path == p || path.startsWith('$p/'));
}

bool _isAdminPath(String path) =>
    path == '/admin' || path.startsWith('/admin/');

GoRouter createRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
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
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: '/admin/films',
        builder: (context, state) => const AdminFilmsScreen(),
      ),
      GoRoute(
        path: '/admin/sync',
        builder: (context, state) => const AdminSyncScreen(),
      ),
      GoRoute(
        path: '/admin/banners',
        builder: (context, state) => const AdminBannersScreen(),
      ),
      GoRoute(
        path: '/admin/featured',
        builder: (context, state) => const AdminFeaturedScreen(),
      ),
      GoRoute(
        path: '/admin/comments',
        builder: (context, state) => const AdminCommentsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/roles',
        builder: (context, state) => const AdminRolesScreen(),
      ),
      GoRoute(
        path: '/admin/logs',
        builder: (context, state) => const AdminLogsScreen(),
      ),
      GoRoute(
        path: '/phim/:slug',
        builder: (context, state) =>
            FilmDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/xem/:slug',
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map
              ? Map<String, dynamic>.from(extra)
              : <String, dynamic>{};
          return WatchScreen(
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
          );
        },
      ),
    ],
  );
}
