import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'screens/film_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/watch_screen.dart';
import 'state/auth_state.dart';

GoRouter createRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      if (auth.booting) return null;
      final loggingIn = state.matchedLocation == '/login';
      if (!auth.isLoggedIn && !loggingIn) return '/login';
      if (auth.isLoggedIn && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
            episodeName: map['episodeName']?.toString(),
            serverName: map['serverName']?.toString(),
          );
        },
      ),
    ],
  );
}

AuthState authOf(BuildContext context) => context.read<AuthState>();
