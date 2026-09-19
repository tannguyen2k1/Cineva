import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'screens/film_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/watch_screen.dart';
import 'state/auth_state.dart';

const _publicExact = {'/', '/login', '/register'};
const _publicPrefixes = ['/phim', '/xem'];

bool _isPublicPath(String path) {
  if (_publicExact.contains(path)) return true;
  return _publicPrefixes.any((p) => path == p || path.startsWith('$p/'));
}

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

AuthState authOf(BuildContext context) => context.read<AuthState>();
